#!/bin/bash
# =============================================================================
# standby-entrypoint.sh  (Node2 / Standby 전용 entrypoint)
# -----------------------------------------------------------------------------
# 공식 postgres 이미지의 기본 entrypoint는 "빈 데이터 디렉토리 → initdb"를 한다.
# Standby는 initdb가 아니라 Primary를 통째로 복사(pg_basebackup)해야 하므로
# entrypoint 자체를 이 스크립트로 교체한다.
#
# 동작:
#   1) 데이터 디렉토리가 비어있으면 → Primary가 뜰 때까지 대기 후 pg_basebackup
#      - pg_basebackup -R : standby.signal + primary_conninfo 자동 기록 (PG12+)
#   2) 이미 데이터가 있으면 → 그대로 기동 (재시작/복구 시)
#   3) postgres 본 프로세스를 postgres 유저로 exec
#
# 주의: listen_addresses='*' 를 반드시 켠다.
#   - 승격(pg_promote)은 재시작 없이 일어나는데, listen_addresses 변경은 재시작이
#     필요하다. 따라서 standby 시점부터 VIP를 받을 수 있게 '*'로 떠 있어야 한다.
# =============================================================================
set -e

PRIMARY_HOST="${PRIMARY_HOST:?PRIMARY_HOST 환경변수 필요 (Primary 실제 사설IP)}"
PRIMARY_PORT="${PRIMARY_PORT:-5432}"
REPL_USER="${REPL_USER:-replicator}"
REPL_PASSWORD="${REPL_PASSWORD:-replicator_pw}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

mkdir -p "$PGDATA"
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo ">> [standby] Primary(${PRIMARY_HOST}:${PRIMARY_PORT}) 기동 대기..."
  until gosu postgres pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$REPL_USER" -q; do
    echo "   ...아직 Primary 응답 없음, 2초 후 재시도"
    sleep 2
  done

  echo ">> [standby] pg_basebackup 시작 (Primary 전체 복사 + standby 설정 기록)"
  rm -rf "${PGDATA:?}"/*
  # -R: standby.signal + primary_conninfo 를 postgresql.auto.conf 에 기록.
  #  ★ 비밀번호는 -d 연결문자열에 넣어야 primary_conninfo 에 영속된다.
  #    (PGPASSWORD 환경변수로만 주면 접속은 되지만 conninfo 엔 안 박혀,
  #     컨테이너 재시작 시 재접속 실패로 복제가 끊긴다.)
  CONNSTR="host=${PRIMARY_HOST} port=${PRIMARY_PORT} user=${REPL_USER} password=${REPL_PASSWORD}"
  gosu postgres pg_basebackup \
    -d "$CONNSTR" \
    -D "$PGDATA" -Fp -Xs -P -R

  echo ">> [standby] basebackup 완료. standby.signal 확인:"
  ls -1 "$PGDATA/standby.signal" 2>/dev/null && echo "   standby.signal 존재 → 복제 대기 모드로 기동됨"
else
  echo ">> [standby] 기존 데이터 디렉토리 발견 → 그대로 기동"
fi

chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

echo ">> [standby] postgres 기동 (listen_addresses=*)"
exec gosu postgres postgres -c listen_addresses='*'
