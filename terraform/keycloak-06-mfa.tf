# =============================================================================
# 시나리오 6: MFA (다중 인증) 강제
# =============================================================================
#
# [고객사 요청 표현]
#   "관리자 계정은 OTP 인증을 필수로 해주세요."
#   "특정 앱(결재 시스템)에 접근할 때는 OTP를 추가로 요구하고 싶어요."
#   "전 직원 OTP 등록을 강제하고 싶습니다."
#
# [작업 전 고객사에게 받아야 할 정보]
#   1. MFA 적용 범위: 전체 사용자 vs 특정 그룹 vs 특정 앱
#   2. MFA 방식: TOTP(Google Authenticator 등) vs WebAuthn(지문/보안키)
#   3. MFA 강제 시점: 첫 로그인 시 등록 강제 vs 이미 등록된 경우만 요구
#   4. MFA 우회 허용 여부 (신뢰 기기 등록 등)
#
# [기억해야 할 것]
#   ┌─────────────────────────────────────────────────────────────┐
#   │ MFA 구현 방식 3가지                                          │
#   ├──────────────────────────────────────────────────────────────┤
#   │ 1. Required Action (가장 단순)                               │
#   │    - 사용자에게 OTP 등록을 강제                              │
#   │    - 등록 전까지 로그인 불가                                 │
#   │    - 전체 사용자 또는 개별 사용자에게 적용                   │
#   │                                                              │
#   │ 2. Authentication Flow (가장 유연)                           │
#   │    - 커스텀 인증 흐름 생성                                   │
#   │    - 조건부 MFA (특정 IP, 특정 역할 등)                      │
#   │    - 특정 Client에만 MFA 적용 가능                           │
#   │                                                              │
#   │ 3. Conditional OTP (중간)                                    │
#   │    - 기본 브라우저 플로우에 조건부 OTP 추가                  │
#   │    - OTP 등록한 사용자만 OTP 요구                            │
#   └──────────────────────────────────────────────────────────────┘
#
#   - TOTP: Google Authenticator, Microsoft Authenticator 등 앱 사용
#     폐쇄망에서도 동작 (인터넷 불필요)
#
#   - WebAuthn: 지문, 얼굴인식, 보안키(YubiKey 등)
#     HTTPS 필수. 브라우저 지원 필요.
#
#   - 특정 Client에만 MFA 적용:
#     Client의 Authentication Flow를 커스텀 플로우로 변경
#
# [설정 방법 - 작업 순서]
#   방법 1 (전체 강제): Required Action을 Default로 설정
#   방법 2 (특정 앱): 커스텀 Authentication Flow 생성 → Client에 할당
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# 방법 1: Required Action으로 전체 사용자 OTP 등록 강제
# 신규 사용자 첫 로그인 시 OTP 등록 화면으로 이동
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_required_action" "configure_totp" {
  realm_id = keycloak_realm.ezl.id
  alias    = "CONFIGURE_TOTP"
  name     = "Configure OTP"
  enabled  = true

  # true: 모든 신규 사용자에게 기본 적용 (첫 로그인 시 OTP 등록 강제)
  # false: 관리자가 개별 사용자에게 수동 할당
  default_action = false  # 전체 강제 시 true로 변경

  # 우선순위 (낮을수록 먼저 실행)
  priority = 10
}

# ─────────────────────────────────────────────────────────────────────────────
# 방법 2: 커스텀 Authentication Flow (특정 앱에만 MFA 적용)
# 결재 시스템(hr-portal)에 접근할 때만 OTP 추가 요구
# ─────────────────────────────────────────────────────────────────────────────

# 커스텀 브라우저 인증 플로우 생성
resource "keycloak_authentication_flow" "browser_with_otp" {
  realm_id    = keycloak_realm.ezl.id
  alias       = "browser-with-otp"
  description = "OTP 필수 브라우저 인증 플로우"
  provider_id = "basic-flow"
}

# 1단계: 쿠키 확인 (이미 로그인된 경우 통과)
resource "keycloak_authentication_execution" "cookie" {
  realm_id          = keycloak_realm.ezl.id
  parent_flow_alias = keycloak_authentication_flow.browser_with_otp.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

# 2단계: Identity Provider 리다이렉트 (소셜 로그인 연동 시)
resource "keycloak_authentication_execution" "idp_redirect" {
  realm_id          = keycloak_realm.ezl.id
  parent_flow_alias = keycloak_authentication_flow.browser_with_otp.alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

# 3단계: 아이디/비밀번호 입력 서브플로우
resource "keycloak_authentication_subflow" "forms" {
  realm_id          = keycloak_realm.ezl.id
  parent_flow_alias = keycloak_authentication_flow.browser_with_otp.alias
  alias             = "browser-with-otp-forms"
  requirement       = "ALTERNATIVE"
  priority          = 30
  provider_id       = "basic-flow"
}

# 3-1: 사용자명/비밀번호 폼
resource "keycloak_authentication_execution" "username_password" {
  realm_id          = keycloak_realm.ezl.id
  parent_flow_alias = keycloak_authentication_subflow.forms.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

# 3-2: OTP 폼 (REQUIRED: 항상 OTP 요구)
resource "keycloak_authentication_execution" "otp_form" {
  realm_id          = keycloak_realm.ezl.id
  parent_flow_alias = keycloak_authentication_subflow.forms.alias
  authenticator     = "auth-otp-form"

  # REQUIRED: 항상 OTP 요구
  # CONDITIONAL: OTP 등록한 사용자만 요구 (미등록자는 통과)
  # ALTERNATIVE: OTP 또는 다른 방법 중 선택
  requirement = "REQUIRED"
  priority    = 20
}

# ─────────────────────────────────────────────────────────────────────────────
# 커스텀 플로우를 특정 Client에 할당
# hr-portal 접근 시에만 OTP 요구
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_client" "hr_portal_mfa" {
  realm_id  = keycloak_realm.ezl.id
  client_id = "hr-portal-mfa-example"
  name      = "HR 포털 (MFA 예시)"
  enabled   = false  # 예시용. 실제 사용 시 true로 변경

  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true

  valid_redirect_uris = ["https://hr.seungdobae.com/*"]
  web_origins         = ["https://hr.seungdobae.com"]

  valid_post_logout_redirect_uris = ["https://hr.seungdobae.com"]

  # 이 Client에 접근할 때 커스텀 플로우(OTP 필수) 사용
  authentication_flow_binding_overrides {
    browser_id = keycloak_authentication_flow.browser_with_otp.id
  }
}
