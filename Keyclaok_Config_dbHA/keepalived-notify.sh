#!/bin/bash
# =============================================================================
# keepalived-notify.sh  (각 노드 호스트에서 실행 — 컨테이너 아님)
# -----------------------------------------------------------------------------
# Keepalived가 상태 전이 시 호출:  notify.sh <TYPE> <NAME> <STATE>
#   STATE = MASTER | BACKUP | FAULT
#
# AWS는 ARP 기반 VRRP로 IP가 안 넘어간다. 따라서 MASTER가 되는 순간
# AWS API를 직접 호출해서 VIP(보조 사설IP)와 EIP를 이 인스턴스로 끌어온다.
#
# [전제]
#  - EC2 인스턴스 역할(IAM Role)에 다음 권한 필요:
#      ec2:AssignPrivateIpAddresses, ec2:UnassignPrivateIpAddresses,
#      ec2:AssociateAddress, ec2:DescribeNetworkInterfaces
#  - awscli, docker, docker compose 설치되어 있을 것
#  - Source/Dest check 비활성화 권장(보조IP 트래픽), 같은 서브넷 2노드
# =============================================================================
set -euo pipefail

# ── 고정값 (terraform 결과물 기준, apply해도 안 변함) ──────────
REGION="ap-northeast-2"
DB_VIP="10.10.0.100"                          # keycloak.conf 가 바라보는 DB 주소 (보조 사설IP)
EIP_ALLOC_ID="eipalloc-083dcf12c717be4b5"     # 프론트 EIP allocation-id (public 3.39.215.207)
COMPOSE_DIR="/home/ubuntu/Keyclaok_Config_dbHA"
COMPOSE_FILE="docker-compose2.yml"            # Node2면 compose2, Node1이면 docker-compose.yml
IS_PRIMARY_NODE="false"                        # Node1(원래 Primary)이면 true
# ────────────────────────────────────────────────────────────

# ── 런타임 자동 조회 (재배치로 ID가 바뀌어도 안 깨지게) ────────
#  instance-id / ENI-id / 인터페이스명은 하드코딩하지 않고 IMDSv2로 조회한다.
imds() {
  # IMDSv2: 토큰 먼저 받고 헤더로 조회
  local path="$1"
  local token
  token=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60") || return 1
  curl -sf -H "X-aws-ec2-metadata-token: $token" \
    "http://169.254.169.254/latest/meta-data/${path}"
}

MAC=$(imds "mac")
ENI_ID=$(imds "network/interfaces/macs/${MAC}/interface-id")
# VIP를 올릴 OS 인터페이스: 기본 라우트가 나가는 NIC (ubuntu24는 보통 ens5)
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
  # 다른 노드에 붙어있던 보조IP는 새 ENI에 assign하면 자동으로 떨어진다(--allow-reassignment)
  aws ec2 assign-private-ip-addresses --region "$REGION" \
    --network-interface-id "$ENI_ID" \
    --private-ip-addresses "$DB_VIP" \
    --allow-reassignment
  # AWS 보조IP 할당만으론 OS가 응답 안 한다. OS 인터페이스에도 직접 추가.
  ip addr add "${DB_VIP}/24" dev "$VIP_IFACE" 2>/dev/null || true
}

remove_os_vip() {
  # 강등(BACKUP/FAULT) 시 OS에 남은 stale VIP 제거.
  #  - AWS는 보조IP를 상대 ENI로 옮기지만 OS엔 주소가 남아 중복 IP 문제 유발.
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

promote_db() {
  # standby였던 노드에서만 의미 있음. 이미 primary면 no-op.
  if docker exec keycloak-db sh -c 'test -f "$PGDATA/standby.signal"' 2>/dev/null; then
    log "PostgreSQL standby 승격(pg_promote)"
    docker exec -u postgres keycloak-db psql -U keycloak -d keycloak -c "SELECT pg_promote(wait => true);"
  else
    log "이미 primary 상태 → 승격 생략"
  fi
}

start_keycloak() {
  log "Keycloak 기동"
  cd "$COMPOSE_DIR"
  if [ "$IS_PRIMARY_NODE" = "true" ]; then
    docker compose -f "$COMPOSE_FILE" up -d keycloak
  else
    # standby 노드는 on-failover 프로파일로 묶여 있음
    docker compose -f "$COMPOSE_FILE" --profile on-failover up -d keycloak
  fi
}

case "$STATE" in
  MASTER)
    log "===== MASTER 전환 시작 ====="
    aws_assign_vip
    aws_assign_eip
    promote_db
    start_keycloak
    log "===== MASTER 전환 완료 ====="
    ;;
  BACKUP|FAULT)
    log "BACKUP/FAULT 전환 — 외부 트래픽 차단(keycloak 정지)"
    cd "$COMPOSE_DIR"
    docker compose -f "$COMPOSE_FILE" stop keycloak 2>/dev/null || true
    remove_os_vip      # OS에 남은 stale VIP 제거 (AWS는 보조IP를 상대 ENI로 이미 옮김)
    # 주의: 한번 promote된 DB는 자동으로 standby로 안 돌아간다.
    #       장애 노드 복구 시에는 README-HA.md 의 '리커버리' 절차를 따른다.
    ;;
  *)
    log "알 수 없는 상태: $STATE"
    ;;
esac
