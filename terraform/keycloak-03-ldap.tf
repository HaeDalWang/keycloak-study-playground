# =============================================================================
# 시나리오 3: LDAP / Active Directory 연동
# =============================================================================
#
# [고객사 요청 표현]
#   "사내 Active Directory 계정으로 Keycloak에 로그인하게 해주세요."
#   "직원이 퇴사하면 AD에서 비활성화하면 Keycloak도 자동으로 막혀야 합니다."
#   "Keycloak에 계정을 또 만들어야 합니까?"
#
# [작업 전 고객사에게 받아야 할 정보]
#   1. LDAP/AD 서버 주소 및 포트 (ldap://10.0.0.1:389 또는 ldaps://10.0.0.1:636)
#   2. Base DN (도메인 구조): dc=ezl,dc=co,dc=kr
#   3. Users DN (사용자 검색 기준): ou=Users,dc=ezl,dc=co,dc=kr
#   4. Groups DN (그룹 검색 기준): ou=Groups,dc=ezl,dc=co,dc=kr
#   5. 서비스 계정 (Bind DN): cn=svc-keycloak,ou=ServiceAccounts,dc=ezl,dc=co,dc=kr
#   6. 서비스 계정 비밀번호
#   7. AD인지 OpenLDAP인지 (설정 방식이 다름)
#   8. 사용자 username으로 쓸 속성: AD=sAMAccountName, OpenLDAP=uid
#
# [고객사에게 줘야 할 정보]
#   - 서비스 계정에 필요한 최소 권한:
#     AD: "Read" 권한만 있는 서비스 계정 (Domain Users 그룹)
#     OpenLDAP: bind + search 권한
#
# [기억해야 할 것]
#   ┌─────────────────────────────────────────────────────────┐
#   │ OpenLDAP vs Active Directory 핵심 차이                   │
#   ├──────────────────────┬──────────────┬───────────────────┤
#   │ 항목                 │ OpenLDAP     │ Active Directory  │
#   ├──────────────────────┼──────────────┼───────────────────┤
#   │ vendor 설정          │ other        │ ad                │
#   │ username 속성        │ uid          │ sAMAccountName    │
#   │ RDN 속성             │ uid          │ cn                │
#   │ UUID 속성            │ entryUUID    │ objectGUID        │
#   │ 그룹 objectClass     │ groupOfNames │ group             │
#   │ 그룹 멤버 속성       │ member       │ member            │
#   │ 계정 비활성화 처리   │ 없음         │ MSAD Mapper 필요  │
#   └──────────────────────┴──────────────┴───────────────────┘
#
#   - editMode=READ_ONLY: AD가 Single Source of Truth. Keycloak에서 수정 불가.
#     운영 환경 기본값. AD에서 퇴사 처리 → Keycloak 로그인 즉시 차단.
#
#   - editMode=WRITABLE: Keycloak에서 수정한 내용이 AD에도 반영.
#     AD 관리자와 협의 필요. 보통 사용 안 함.
#
#   - syncRegistrations=false: Keycloak에서 신규 사용자 생성 시 AD에 동기화 안 함.
#     AD가 계정 관리 주체이므로 false 권장.
#
#   - 연결 보안: 운영에서는 반드시 ldaps:// (포트 636) 또는 STARTTLS 사용.
#     ldap:// (포트 389)는 비밀번호가 평문 전송됨.
#
#   - 그룹 동기화 후 Keycloak 그룹에 Role 할당 필요 (keycloak-02-org.tf 참조)
#     AD 그룹 "개발팀" → Keycloak 그룹 "개발팀" 동기화 → ROLE_DEV_ACCESS 할당
#
# [설정 방법 - 작업 순서]
#   1. AD 서비스 계정 생성 요청 (고객사 AD 관리자에게)
#   2. 연결 테스트 (ldapsearch 또는 Keycloak Admin Console Test Connection)
#   3. User Federation 생성 (이 파일)
#   4. 동기화 실행 및 사용자 확인
#   5. 그룹 동기화 확인 후 Role 매핑 (keycloak-02-org.tf)
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# LDAP 연결 정보 변수 (고객사마다 다름 → terraform.tfvars에서 주입)
# ─────────────────────────────────────────────────────────────────────────────
variable "ldap_connection_url" {
  description = "LDAP 서버 주소 (운영: ldaps://, 개발: ldap://)"
  type        = string
  default     = "ldap://localhost:389"
  # 실제 작업 시 terraform.tfvars에서 오버라이드:
  # ldap_connection_url = "ldaps://ad.ezl.co.kr:636"
}

variable "ldap_bind_dn" {
  description = "LDAP 서비스 계정 DN"
  type        = string
  default     = "cn=admin,dc=example,dc=com"
  # AD 예시:     "cn=svc-keycloak,ou=ServiceAccounts,dc=ezl,dc=co,dc=kr"
  # OpenLDAP 예: "cn=admin,dc=ezl,dc=co,dc=kr"
}

variable "ldap_bind_credential" {
  description = "LDAP 서비스 계정 비밀번호"
  type        = string
  sensitive   = true
  default     = "changeme"
}

variable "ldap_users_dn" {
  description = "사용자 검색 기준 DN"
  type        = string
  default     = "ou=users,dc=example,dc=com"
  # AD 예시:     "ou=Users,dc=ezl,dc=co,dc=kr"
  # OpenLDAP 예: "ou=people,dc=ezl,dc=co,dc=kr"
}

variable "ldap_groups_dn" {
  description = "그룹 검색 기준 DN"
  type        = string
  default     = "ou=groups,dc=example,dc=com"
  # AD 예시:     "ou=Groups,dc=ezl,dc=co,dc=kr"
  # OpenLDAP 예: "ou=groups,dc=ezl,dc=co,dc=kr"
}

# ─────────────────────────────────────────────────────────────────────────────
# LDAP User Federation
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_ldap_user_federation" "ezl_ad" {
  realm_id = keycloak_realm.ezl.id
  name     = "ezl-active-directory"
  enabled  = true

  # ── 연결 설정 ──────────────────────────────────────────────
  connection_url = var.ldap_connection_url

  # 서비스 계정 (읽기 전용 계정으로 충분)
  bind_dn         = var.ldap_bind_dn
  bind_credential = var.ldap_bind_credential

  # 사용자 검색 기준 DN
  users_dn = var.ldap_users_dn

  # ── 벤더 설정 ──────────────────────────────────────────────
  # AD: "AD" / OpenLDAP: "OTHER"
  # "AD"로 설정하면 Keycloak이 AD 특화 동작 자동 적용
  vendor = "AD"

  # ── 사용자 속성 매핑 ───────────────────────────────────────
  # AD에서 Keycloak username으로 쓸 속성
  # AD: sAMAccountName (로그인 ID) / OpenLDAP: uid
  username_ldap_attribute = "sAMAccountName"

  # RDN(Relative Distinguished Name): 항목을 고유하게 식별하는 속성
  # AD: cn / OpenLDAP: uid
  rdn_ldap_attribute = "cn"

  # UUID: Keycloak 내부에서 사용자를 고유 식별하는 속성
  # AD: objectGUID / OpenLDAP: entryUUID
  uuid_ldap_attribute = "objectGUID"

  # 사용자 objectClass 필터
  # AD: person, organizationalPerson, user
  user_object_classes = ["person", "organizationalPerson", "user"]

  # ── 동기화 설정 ────────────────────────────────────────────
  # READ_ONLY: AD가 Single Source of Truth (권장)
  # WRITABLE: Keycloak 수정 내용이 AD에 반영 (AD 관리자 협의 필요)
  edit_mode = "READ_ONLY"

  # false: Keycloak에서 신규 사용자 생성 시 AD에 동기화 안 함
  # AD가 계정 관리 주체이므로 false 권장
  sync_registrations = false

  # 검색 범위: ONE_LEVEL(users_dn 바로 아래만), SUBTREE(하위 전체)
  # 하위 OU가 있는 경우 SUBTREE 사용
  search_scope = "SUBTREE"

  # ── 연결 풀 ────────────────────────────────────────────────
  connection_pooling = true

  # ── 주기적 동기화 ──────────────────────────────────────────
  # 변경된 사용자만 동기화 (초 단위, 3600 = 1시간)
  changed_sync_period = 3600

  # 전체 동기화 주기 (초 단위, 86400 = 24시간)
  full_sync_period = 86400
}

# ─────────────────────────────────────────────────────────────────────────────
# Active Directory 전용: 계정 활성화/비활성화 처리
# AD에서 계정을 비활성화하면 Keycloak 로그인도 즉시 차단
# OpenLDAP 사용 시 이 블록 제거
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_ldap_msad_user_account_control_mapper" "ezl_ad_uac" {
  realm_id                   = keycloak_realm.ezl.id
  ldap_user_federation_id    = keycloak_ldap_user_federation.ezl_ad.id
  name                       = "msad-user-account-control"

  # true: 비밀번호 만료 시 Keycloak 로그인 화면에서 변경 가능
  ldap_password_policy_hints_enabled = false
}

# ─────────────────────────────────────────────────────────────────────────────
# 사용자 속성 매퍼: AD 속성 → Keycloak 사용자 속성
# ─────────────────────────────────────────────────────────────────────────────

# 이메일 매핑
resource "keycloak_ldap_user_attribute_mapper" "email" {
  realm_id                = keycloak_realm.ezl.id
  ldap_user_federation_id = keycloak_ldap_user_federation.ezl_ad.id
  name                    = "email"

  user_model_attribute = "email"   # Keycloak 속성명
  ldap_attribute       = "mail"    # AD 속성명 (AD: mail, OpenLDAP: mail)
}

# 이름 매핑
resource "keycloak_ldap_user_attribute_mapper" "first_name" {
  realm_id                = keycloak_realm.ezl.id
  ldap_user_federation_id = keycloak_ldap_user_federation.ezl_ad.id
  name                    = "first-name"

  user_model_attribute = "firstName"
  ldap_attribute       = "givenName"
}

resource "keycloak_ldap_user_attribute_mapper" "last_name" {
  realm_id                = keycloak_realm.ezl.id
  ldap_user_federation_id = keycloak_ldap_user_federation.ezl_ad.id
  name                    = "last-name"

  user_model_attribute = "lastName"
  ldap_attribute       = "sn"  # surname
}

# ─────────────────────────────────────────────────────────────────────────────
# 그룹 매퍼: AD 그룹 → Keycloak 그룹 동기화
# 동기화 후 keycloak-02-org.tf의 keycloak_group_roles로 Role 할당
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_ldap_group_mapper" "ezl_groups" {
  realm_id                = keycloak_realm.ezl.id
  ldap_user_federation_id = keycloak_ldap_user_federation.ezl_ad.id
  name                    = "group-mapper"

  # 그룹 검색 기준 DN
  ldap_groups_dn = var.ldap_groups_dn

  # 그룹 이름으로 쓸 속성
  group_name_ldap_attribute = "cn"

  # 그룹 objectClass
  # AD: group / OpenLDAP: groupOfNames 또는 groupOfUniqueNames
  group_object_classes = ["group"]

  # 멤버 속성
  membership_ldap_attribute      = "member"
  membership_attribute_type      = "DN"
  membership_user_ldap_attribute = "sAMAccountName"

  # READ_ONLY: AD 그룹을 Keycloak에서 수정 불가
  mode = "READ_ONLY"

  # 사용자 그룹 조회 전략
  user_roles_retrieve_strategy = "LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"

  # Keycloak 그룹 경로 (루트에 생성)
  groups_path = "/"
}
