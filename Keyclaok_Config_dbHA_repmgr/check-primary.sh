#!/bin/bash
# =============================================================================
# check-primary.sh  ── keepalived track_script 용 (repmgr 버전 전용)
# -----------------------------------------------------------------------------
# "이 노드의 PostgreSQL이 현재 Primary인가?"를 판정한다.
#   - Primary  : pg_is_in_recovery() = false  → exit 0 (성공)
#   - Standby  : pg_is_in_recovery() = true   → exit 1 (실패)
#   - DB 죽음   : 접속 실패                     → exit 1 (실패)
#
# 이게 repmgr 버전의 핵심 트릭이다:
#   repmgrd가 어느 노드를 primary로 만들든, VIP는 "primary 체크가 통과하는
#   노드"를 자동으로 따라간다. 그래서 수동 버전과 달리 nopreempt 가 필요 없다.
#   (죽었다 살아난 옛 primary는 repmgr이 standby로 재가입시키므로 이 체크가
#    실패 → VIP를 도로 뺏지 않음 → stale 복귀 문제 자동 해결)
# =============================================================================
set -uo pipefail

# bitnami repmgr 이미지는 로컬 소켓 접속에도 비밀번호를 요구한다(scram-sha-256).
# docker-compose 의 POSTGRESQL_PASSWORD 와 동일하게 맞춘다.
DB_PASSWORD="${DB_PASSWORD:-keycloak}"

RESULT=$(docker exec -e PGPASSWORD="$DB_PASSWORD" keycloak-db \
  psql -U keycloak -d keycloak -tAc "SELECT NOT pg_is_in_recovery();" 2>/dev/null | tr -d '[:space:]')

if [ "$RESULT" = "t" ]; then
  exit 0   # 나는 Primary → 이 노드가 VIP를 가져야 함
else
  exit 1   # Standby 이거나 DB 다운 → VIP 양보
fi
