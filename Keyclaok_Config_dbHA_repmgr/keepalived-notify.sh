#!/bin/bash
# =============================================================================
# keepalived-notify.sh  (repmgr 레퍼런스 버전 — 각 노드 호스트에서 실행)
# -----------------------------------------------------------------------------
# 수동 스트리밍 복제 버전(../Keyclaok_Config_dbHA/keepalived-notify.sh)과의 차이:
#   ★ promote_db() 가 없다.
#     - 수동 버전: keepalived 가 pg_promote() 를 직접 호출해 DB를 승격.
#     - repmgr 버전: repmgrd 데몬이 Primary 장애를 감지해 자동 승격한다.
#       keepalived 는 "트래픽 경로(VIP/EIP)만" 옮기면 된다.
#
# 즉 역할 분담:
#   repmgrd      → 어느 DB가 Primary냐 (자동 failover, 승격, 재가입)
#   keepalived   → 클라이언트가 어디로 접속하냐 (VIP/EIP 이동)
#
# [전제] 수동 버전과 동일:
#   - IAM Role: ec2:AssignPrivateIpAddresses, ec2:AssociateAddress 등
#   - awscli, docker, docker compose 설치
#   - 같은 서브넷 2노드, Source/Dest check 비활성화 권장
# =============================================================================
set -euo pipefail

# ── 고정값 (terraform 결과물 기준, apply해도 안 변함) ──────────
REGION="ap-northeast-2"
DB_VIP="10.10.0.100"                          # keycloak.conf 가 바라보는 DB 주소 (보조 사설IP)
EIP_ALLOC_ID="eipalloc-083dcf12c717be4b5"     # 프론트 EIP allocation-id (public 3.39.215.207)
COMPOSE_DIR="/home/ubuntu/Keyclaok_Config_dbHA_repmgr"
COMPOSE_FILE="docker-compose.yml"            # Node2면 compose2, Node1이면 docker-compose.yml
IS_PRIMARY_NODE="false"                        # Node1(최초 Primary)이면 true
# ────────────────────────────────────────────────────────────

# ── 런타임 자동 조회 (재배치로 ID가 바뀌어도 안 깨지게) ────────
#  instance-id / ENI-id / 인터페이스명은 하드코딩하지 않고 IMDSv2로 조회한다.
imds() {
  local path="$1"
  local token
  token=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60") || return 1
  curl -sf -H "X-aws-ec2-metadata-token: $token" \
    "http://169.254.169.254/latest/meta-data/${path}"
}

MAC=$(imds "mac")
ENI_ID=$(imds "network/interfaces/macs/${MAC}/interface-id")
VIP_IFACE=$(ip route show default | awk '{print $5; exit}')

STATE="$3"
LOG="/var/log/keepalived-notify.log"
log() { echo "$(date '+%F %T') [$STATE] $*" | tee -a "$LOG"; }

if [ -z "${ENI_ID:-}" ] || [ -z "${VIP_IFACE:-}" ]; then
  log "치명적: ENI_ID/VIP_IFACE 조회 실패 (ENI=${ENI_ID:-} IFACE=${VIP_IFACE:-})"
  exit 1
fi
log "런타임 조회: ENI=${ENI_ID} IFACE=${VIP_IFACE}"

aws_assign_vip() {
  log "VIP ${DB_VIP} 를 이 ENI(${ENI_ID})로 이동"
  aws ec2 assign-private-ip-addresses --region "$REGION" \
    --network-interface-id "$ENI_ID" \
    --private-ip-addresses "$DB_VIP" \
    --allow-reassignment
  ip addr add "${DB_VIP}/24" dev "$VIP_IFACE" 2>/dev/null || true
}

remove_os_vip() {
  log "OS 인터페이스(${VIP_IFACE})에서 stale VIP ${DB_VIP} 제거"
  ip addr del "${DB_VIP}/24" dev "$VIP_IFACE" 2>/dev/null || true
}

aws_assign_eip() {
  log "EIP(${EIP_ALLOC_ID}) 를 이 인스턴스로 연결"
  aws ec2 associate-address --region "$REGION" \
    --allocation-id "$EIP_ALLOC_ID" \
    --network-interface-id "$ENI_ID" \
    --allow-reassociation
}

start_keycloak() {
  log "Keycloak 기동"
  cd "$COMPOSE_DIR"
  if [ "$IS_PRIMARY_NODE" = "true" ]; then
    docker compose -f "$COMPOSE_FILE" up -d keycloak
  else
    docker compose -f "$COMPOSE_FILE" --profile on-failover up -d keycloak
  fi
}

case "$STATE" in
  MASTER)
    log "===== MASTER 전환 시작 (DB 승격은 repmgrd가 이미 처리) ====="
    aws_assign_vip
    aws_assign_eip
    # ★ 여기서 pg_promote 호출하지 않는다. repmgrd가 자동 승격함.
    #   keepalived 의 chk_repmgr 스크립트는 "이 노드가 현재 primary 인가"를
    #   확인하므로, MASTER가 됐다는 건 이미 repmgr 상 primary 라는 의.
    start_keycloak
    log "===== MASTER 전환 완료 ====="
    ;;
  BACKUP|FAULT)
    log "BACKUP/FAULT 전환 — 외부 트래픽 차단(keycloak 정지)"
    cd "$COMPOSE_DIR"
    docker compose -f "$COMPOSE_FILE" stop keycloak 2>/dev/null || true
    remove_os_vip
    # repmgr 버전 장점: 죽었던 노드가 살아나면 repmgrd가 자동으로 새 Primary의
    #   standby로 재가입(rejoin)한다. 수동 버전처럼 pg_basebackup 수동 재실행 불필요.
    ;;
  *)
    log "알 수 없는 상태: $STATE"
    ;;
esac
