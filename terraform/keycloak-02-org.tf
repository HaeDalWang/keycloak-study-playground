# =============================================================================
# 시나리오 2: 조직 구조 구성 (부서/팀 + 권한 체계)
# =============================================================================
#
# [고객사 요청 표현]
#   "조직도대로 권한을 나눠주세요."
#   "팀장은 결재 시스템 접근 가능하고, 일반 직원은 안 되게 해주세요."
#   "신입사원이 입사하면 팀에 넣기만 하면 권한이 자동으로 생기게 해주세요."
#
# [작업 전 고객사에게 받아야 할 정보]
#   1. 조직도 (부서명, 계층 구조)
#   2. 부서별 접근 가능한 시스템 목록
#   3. 직급/역할별 권한 차이 (팀장 vs 일반직원 등)
#   4. 겸직/겸무 케이스 (한 사람이 여러 팀 소속 가능한지)
#
# [고객사에게 줘야 할 정보]
#   - 없음. 이 작업은 내부 설정.
#   - 단, 개발자에게는 토큰의 어떤 필드에서 권한을 읽어야 하는지 알려줄 것:
#     Realm Role → token.realm_access.roles
#     Client Role → token.resource_access.{client-id}.roles
#
# [기억해야 할 것]
#   - Role = 권한 (ROLE_HR_ACCESS, ROLE_APPROVAL_ACCESS)
#     이름을 팀명으로 짓지 말 것 (ROLE_DEV_TEAM X → ROLE_HR_ACCESS O)
#     이유: 마케팅팀도 HR 접근이 필요해지면 같은 Role 재사용 가능
#
#   - Group = 소속 (개발팀, 영업팀)
#     Group에 Role을 할당 → 소속 직원 전원 자동 상속
#     인사이동 시 Group만 바꾸면 권한 자동 변경
#
#   - Realm Role vs Client Role
#     Realm Role: 모든 앱에서 공통으로 쓰는 권한 → realm_access.roles
#     Client Role: 특정 앱에서만 의미있는 세밀한 권한 → resource_access.{app}.roles
#     이 파일에서는 Realm Role 사용 (여러 앱에서 공통 사용)
#
#   - 중첩 그룹(Sub-group): 대팀 > 소팀 구조 가능
#     소팀은 대팀의 Role을 상속받음
#
# [설정 방법 - 작업 순서]
#   1. Realm Role 생성 (권한 단위)
#   2. Group 생성 (조직 단위)
#   3. Group에 Role 할당
#   4. 사용자를 Group에 추가 (입사 처리)
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# Realm Role 정의
# 규칙: 권한 이름은 접근 대상 시스템/기능 기준으로 작성
# ─────────────────────────────────────────────────────────────────────────────

# 전 직원 공통 권한 (모든 Group에 할당)
resource "keycloak_role" "portal_access" {
  realm_id    = keycloak_realm.ezl.id
  name        = "ROLE_PORTAL_ACCESS"
  description = "사내 포털 접근 권한 - 전 직원"
}

# HR 시스템 접근 (인사팀, 경영팀)
resource "keycloak_role" "hr_access" {
  realm_id    = keycloak_realm.ezl.id
  name        = "ROLE_HR_ACCESS"
  description = "HR 시스템 접근 권한"
}

# 결재 시스템 접근 (팀장급 이상)
resource "keycloak_role" "approval_access" {
  realm_id    = keycloak_realm.ezl.id
  name        = "ROLE_APPROVAL_ACCESS"
  description = "전자결재 시스템 접근 권한"
}

# 개발 시스템 접근 (개발팀)
resource "keycloak_role" "dev_access" {
  realm_id    = keycloak_realm.ezl.id
  name        = "ROLE_DEV_ACCESS"
  description = "개발 시스템(Jira, GitLab 등) 접근 권한"
}

# 관리자 권한 (Keycloak 관리 목적)
resource "keycloak_role" "admin" {
  realm_id    = keycloak_realm.ezl.id
  name        = "ROLE_ADMIN"
  description = "시스템 관리자 권한"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 정의 (조직도 구조)
#
# EZL 조직도:
#   개발팀    → ROLE_PORTAL_ACCESS, ROLE_DEV_ACCESS
#   영업팀    → ROLE_PORTAL_ACCESS
#   운영팀    → ROLE_PORTAL_ACCESS
#   인사팀    → ROLE_PORTAL_ACCESS, ROLE_HR_ACCESS
#   경영팀    → ROLE_PORTAL_ACCESS, ROLE_HR_ACCESS, ROLE_APPROVAL_ACCESS
# ─────────────────────────────────────────────────────────────────────────────

resource "keycloak_group" "dev" {
  realm_id = keycloak_realm.ezl.id
  name     = "개발팀"
}

resource "keycloak_group" "sales" {
  realm_id = keycloak_realm.ezl.id
  name     = "영업팀"
}

resource "keycloak_group" "ops" {
  realm_id = keycloak_realm.ezl.id
  name     = "운영팀"
}

resource "keycloak_group" "hr" {
  realm_id = keycloak_realm.ezl.id
  name     = "인사팀"
}

resource "keycloak_group" "management" {
  realm_id = keycloak_realm.ezl.id
  name     = "경영팀"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group ↔ Role 매핑
# 이 설정이 "팀에 넣기만 하면 권한이 자동으로 생긴다"를 구현
# ─────────────────────────────────────────────────────────────────────────────

# 개발팀: 포털 + 개발 시스템
resource "keycloak_group_roles" "dev_roles" {
  realm_id = keycloak_realm.ezl.id
  group_id = keycloak_group.dev.id

  role_ids = [
    keycloak_role.portal_access.id,
    keycloak_role.dev_access.id,
  ]
}

# 영업팀: 포털만
resource "keycloak_group_roles" "sales_roles" {
  realm_id = keycloak_realm.ezl.id
  group_id = keycloak_group.sales.id

  role_ids = [
    keycloak_role.portal_access.id,
  ]
}

# 운영팀: 포털만
resource "keycloak_group_roles" "ops_roles" {
  realm_id = keycloak_realm.ezl.id
  group_id = keycloak_group.ops.id

  role_ids = [
    keycloak_role.portal_access.id,
  ]
}

# 인사팀: 포털 + HR
resource "keycloak_group_roles" "hr_roles" {
  realm_id = keycloak_realm.ezl.id
  group_id = keycloak_group.hr.id

  role_ids = [
    keycloak_role.portal_access.id,
    keycloak_role.hr_access.id,
  ]
}

# 경영팀: 포털 + HR + 결재
resource "keycloak_group_roles" "management_roles" {
  realm_id = keycloak_realm.ezl.id
  group_id = keycloak_group.management.id

  role_ids = [
    keycloak_role.portal_access.id,
    keycloak_role.hr_access.id,
    keycloak_role.approval_access.id,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# 테스트용 사용자 (실제 운영에서는 LDAP 연동 또는 수동 생성)
# 주의: 비밀번호를 tfvars나 Secret Manager로 관리할 것
#       코드에 평문 비밀번호 절대 금지
# ─────────────────────────────────────────────────────────────────────────────

resource "keycloak_user" "dev_user" {
  realm_id = keycloak_realm.ezl.id
  username = "kim.dev"
  enabled  = true

  email          = "kim.dev@ezl.com"
  first_name     = "개발"
  last_name      = "김"
  email_verified = true

  initial_password {
    value     = var.test_user_password
    temporary = true  # 첫 로그인 시 비밀번호 변경 강제
  }
}

resource "keycloak_user" "hr_user" {
  realm_id = keycloak_realm.ezl.id
  username = "lee.hr"
  enabled  = true

  email          = "lee.hr@ezl.com"
  first_name     = "인사"
  last_name      = "이"
  email_verified = true

  initial_password {
    value     = var.test_user_password
    temporary = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 사용자 → Group 할당
# ─────────────────────────────────────────────────────────────────────────────

resource "keycloak_user_groups" "dev_user_groups" {
  realm_id = keycloak_realm.ezl.id
  user_id  = keycloak_user.dev_user.id

  group_ids = [
    keycloak_group.dev.id,
  ]
}

resource "keycloak_user_groups" "hr_user_groups" {
  realm_id = keycloak_realm.ezl.id
  user_id  = keycloak_user.hr_user.id

  group_ids = [
    keycloak_group.hr.id,
  ]
}
