# =============================================================================
# 시나리오 7: 커스텀 Claims (토큰에 추가 정보 넣기)
# =============================================================================
#
# [고객사 요청 표현]
#   "토큰에 부서 정보도 넣어주세요. 앱에서 부서별로 화면을 다르게 보여줘야 해요."
#   "사용자의 사번(employee_id)을 토큰에 포함시켜 주세요."
#   "어떤 그룹에 속해있는지 토큰에서 바로 알 수 있게 해주세요."
#
# [작업 전 고객사에게 받아야 할 정보]
#   1. 토큰에 넣을 정보 목록 (속성명, 값 예시)
#   2. JWT에서 사용할 claim 이름 (개발자와 협의)
#   3. 어떤 앱(Client)에 적용할지
#   4. 사용자 속성값은 어디서 관리? (Keycloak 직접 입력 vs LDAP 속성 매핑)
#
# [고객사에게 줘야 할 정보]
#   개발자에게 전달:
#   - claim 이름: "department", "employee_id" 등
#   - 위치: token.{claim_name} 또는 token.{namespace}/{claim_name}
#   - 타입: String, boolean, JSON 등
#
# [기억해야 할 것]
#   ┌─────────────────────────────────────────────────────────────┐
#   │ Protocol Mapper 종류                                         │
#   ├──────────────────────────────────────────────────────────────┤
#   │ user-attribute    │ 사용자 커스텀 속성 → claim               │
#   │ group-membership  │ 소속 그룹 목록 → claim                   │
#   │ realm-role        │ Realm Role 목록 → claim (기본 포함됨)    │
#   │ hardcoded-claim   │ 고정값 → claim (앱 식별 등에 활용)       │
#   │ script-mapper     │ JavaScript로 동적 claim 생성             │
#   └──────────────────────────────────────────────────────────────┘
#
#   - Client Scope: 여러 Client에서 재사용할 claim 묶음
#     한 번 정의 → 여러 앱에 할당 가능
#     예) "employee-info" scope = department + employee_id + group
#
#   - 사용자 속성 입력 방법:
#     Admin Console: Users → {user} → Attributes 탭
#     kcadm.sh: kcadm.sh update users/{id} -r ezl -s 'attributes.department=["개발팀"]'
#     LDAP 연동 시: LDAP 속성 매퍼로 자동 동기화 (keycloak-03-ldap.tf 참조)
#
#   - claim_value_type: String, long, boolean, JSON
#     배열 값: add_to_access_token=true + multivalued=true
#
# [설정 방법 - 작업 순서]
#   1. 사용자에게 커스텀 속성 추가 (Admin Console 또는 kcadm.sh)
#   2. Client Scope 생성 (이 파일)
#   3. Protocol Mapper 추가 (이 파일)
#   4. Client에 Scope 할당 (이 파일)
#   5. 토큰 발급 후 claim 확인
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# Client Scope: 직원 정보 묶음
# 여러 앱에서 재사용 가능한 claim 세트
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_client_scope" "employee_info" {
  realm_id    = keycloak_realm.ezl.id
  name        = "employee-info"
  description = "직원 정보 (부서, 사번, 직급)"

  # consent_screen_text: 사용자 동의 화면에 표시될 설명
  # 사내 앱은 보통 동의 화면 없음 (consent_required=false)
}

# ─────────────────────────────────────────────────────────────────────────────
# Protocol Mapper 1: 부서 정보
# 사용자 속성 "department" → JWT claim "department"
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_user_attribute_protocol_mapper" "department" {
  realm_id        = keycloak_realm.ezl.id
  client_scope_id = keycloak_openid_client_scope.employee_info.id
  name            = "department"

  # Keycloak 사용자 속성명 (Users → Attributes 탭에서 설정한 키)
  user_attribute = "department"

  # JWT에서 사용할 claim 이름 (개발자와 협의)
  claim_name = "department"

  # 값 타입: String, long, boolean, JSON
  claim_value_type = "String"

  # Access Token에 포함 여부
  add_to_access_token = true

  # ID Token에 포함 여부 (사용자 정보 표시용)
  add_to_id_token = true

  # UserInfo 엔드포인트 응답에 포함 여부
  add_to_userinfo = true
}

# ─────────────────────────────────────────────────────────────────────────────
# Protocol Mapper 2: 사번
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_user_attribute_protocol_mapper" "employee_id" {
  realm_id        = keycloak_realm.ezl.id
  client_scope_id = keycloak_openid_client_scope.employee_info.id
  name            = "employee-id"

  user_attribute      = "employee_id"
  claim_name          = "employee_id"
  claim_value_type    = "String"
  add_to_access_token = true
  add_to_id_token     = true
  add_to_userinfo     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# Protocol Mapper 3: 그룹 멤버십
# 사용자가 속한 그룹 목록 → JWT claim "groups"
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id        = keycloak_realm.ezl.id
  client_scope_id = keycloak_openid_client_scope.employee_info.id
  name            = "groups"

  # JWT claim 이름
  claim_name = "groups"

  # true: 전체 경로 포함 ("/개발팀/백엔드팀")
  # false: 그룹 이름만 ("백엔드팀")
  full_path = false

  add_to_access_token = true
  add_to_id_token     = true
  add_to_userinfo     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# Client에 Scope 할당
# hr-portal이 employee-info scope를 기본으로 요청
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_client_default_scopes" "hr_portal_scopes" {
  realm_id  = keycloak_realm.ezl.id
  client_id = keycloak_openid_client.hr_portal.id

  # 기본 scope 목록 (로그인 시 자동 포함)
  # Keycloak 기본 scope: profile, email, roles, web-origins, acr
  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    "acr",
    keycloak_openid_client_scope.employee_info.name,
  ]
}
