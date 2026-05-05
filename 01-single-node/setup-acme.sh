#!/bin/bash
KC=/opt/keycloak/bin/kcadm.sh

# 로그인
$KC config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin_password

# 1. Realm 생성
$KC create realms \
  -s realm=acme-corp \
  -s enabled=true \
  -s displayName="ACME Corporation"
echo "[1/5] Realm 생성 완료"

# 2. Role 생성
$KC create roles -r acme-corp -s name=ROLE_HR_ACCESS -s "description=HR 시스템 접근 권한"
$KC create roles -r acme-corp -s name=ROLE_APPROVAL_ACCESS -s "description=결재 시스템 접근 권한"
echo "[2/5] Role 2개 생성 완료"

# 3. Group 생성 + Role 할당
GROUP_ID=$($KC create groups -r acme-corp -s name=개발팀 -i)
$KC add-roles -r acme-corp --gname 개발팀 --rolename ROLE_HR_ACCESS
echo "[3/5] Group 생성 및 Role 할당 완료 (ID: $GROUP_ID)"

# 4. User 생성
USER_ID=$($KC create users \
  -r acme-corp \
  -s username=hong.gildong \
  -s email=hong.gildong@acme.com \
  -s firstName=길동 \
  -s lastName=홍 \
  -s enabled=true \
  -s emailVerified=true \
  -i)
$KC set-password -r acme-corp --username hong.gildong --new-password Test1234!
echo "[4/5] User 생성 완료 (ID: $USER_ID)"

# 5. User → Group 추가
$KC update users/$USER_ID/groups/$GROUP_ID \
  -r acme-corp -s realm=acme-corp -s userId=$USER_ID -s groupId=$GROUP_ID -n
echo "[5/5] User → Group 추가 완료"

# 검증
echo ""
echo "=== 검증: User 정보 ==="
$KC get users -r acme-corp -q username=hong.gildong --fields username,email,enabled

echo "=== 검증: User의 Role ==="
$KC get-roles -r acme-corp --uusername hong.gildong --effective
