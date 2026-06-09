#!/bin/bash
# =============================================================================
# init-primary.sh  (Node1 / Primary 전용)
# -----------------------------------------------------------------------------
# 공식 postgres 이미지는 데이터 디렉토리가 비어있을 때(최초 1회)
# /docker-entrypoint-initdb.d/*.sh 를 자동 실행한다.
# 여기서 (1) 복제 전용 계정 생성, (2) standby가 복제 접속할 수 있도록 pg_hba 허용.
#   - 이 시점엔 임시 로컬 서버가 떠 있고 psql 소켓 접속이 가능하다.
#   - pg_hba.conf 에 추가한 내용은 본 서버 기동 시 반영된다.
# =============================================================================
set -e

: "${REPL_USER:=replicator}"
: "${REPL_PASSWORD:=replicator_pw}"
: "${REPL_ALLOWED_CIDR:=10.10.0.0/24}"   # standby가 속한 서브넷 (public, AZ 2a)

echo ">> [init-primary] 복제 계정 '${REPL_USER}' 생성"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE ROLE ${REPL_USER} WITH REPLICATION LOGIN PASSWORD '${REPL_PASSWORD}';
EOSQL

echo ">> [init-primary] ${REPL_ALLOWED_CIDR} 에서 오는 replication 접속 허용 (pg_hba.conf)"
cat >> "$PGDATA/pg_hba.conf" <<-EOF

	# --- streaming replication (added by init-primary.sh) ---
	host    replication    ${REPL_USER}    ${REPL_ALLOWED_CIDR}    scram-sha-256
EOF

echo ">> [init-primary] 완료"
