#!/bin/bash
# =============================================================================
# Keycloak 신규 고객사 온보딩 자동화 스크립트
# 사용법: ./onboard.sh <realm명> <표시이름>
# 예시:   ./onboard.sh jtbc "JTBC Media Group"
# =============================================================================

KC=/opt/keycloak/bin/kcadm.sh
REALM=$1
DISPLAY_NAME=$2

if [ -z "$REALM" ] || [ -z "$DISPLAY_NAME" ]; then
  echo "사용법: $0 <realm명> <표시이름>"
  exit 1
fi

# 로그인
$KC config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin_password

echo "=== $DISPLAY_NAME 온보딩 시작 ==="

# 1. Realm 생성
$KC create realms \
  -s realm=$REALM \
  -s enabled=true \
  -s "displayName=$DISPLAY_NAME" \
  -s "accessTokenLifespan=300" \
  -s "ssoSessionMaxLifespan=36000"
echo "[1/4] Realm '$REALM' 생성 완료"

# 2. 기본 Role 세트 생성
for ROLE in ROLE_HR_ACCESS ROLE_APPROVAL_ACCESS ROLE_PORTAL_ACCESS ROLE_ADMIN; do
  $KC create roles -r $REALM -s name=$ROLE
done
echo "[2/4] 기본 Role 4개 생성 완료"

# 3. 기본 Group 세트 생성 + Role 할당
declare -A GROUP_ROLES=(
  ["개발팀"]="ROLE_HR_ACCESS ROLE_PORTAL_ACCESS"
  ["인사팀"]="ROLE_HR_ACCESS ROLE_PORTAL_ACCESS"
  ["경영팀"]="ROLE_HR_ACCESS ROLE_APPROVAL_ACCESS ROLE_PORTAL_ACCESS"
)

for GROUP in "${!GROUP_ROLES[@]}"; do
  $KC create groups -r $REALM -s name=$GROUP
  for ROLE in ${GROUP_ROLES[$GROUP]}; do
    $KC add-roles -r $REALM --gname $GROUP --rolename $ROLE
  done
  echo "  그룹 '$GROUP' 생성 및 Role 할당 완료"
done
echo "[3/4] 기본 Group 3개 생성 완료"

# 4. 관리자 계정 생성
ADMIN_ID=$($KC create users \
  -r $REALM \
  -s username=realm-admin \
  -s enabled=true \
  -s emailVerified=true \
  -i)
$KC set-password -r $REALM --username realm-admin --new-password Admin1234!
$KC add-roles -r $REALM --uusername realm-admin --rolename ROLE_ADMIN
echo "[4/4] 관리자 계정 생성 완료"

echo ""
echo "=== 온보딩 완료: $DISPLAY_NAME ==="
echo "  Realm:    $REALM"
echo "  Admin:    realm-admin / Admin1234!"
echo "  Console:  http://localhost:8080/admin/$REALM/console"
