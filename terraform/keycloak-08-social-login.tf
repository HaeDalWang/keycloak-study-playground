# =============================================================================
# 시나리오 8: 소셜 로그인 (Google, Kakao, Naver)
# =============================================================================
#
# [고객사 요청 표현]
#   "구글 계정으로 로그인할 수 있게 해주세요."
#   "카카오 로그인 버튼을 추가해주세요."
#   "소셜 로그인 사용자도 사내 권한 체계(Role/Group)를 적용받아야 합니다."
#
# [작업 전 고객사에게 받아야 할 정보]
#   Google:
#     1. Google Cloud Console에서 OAuth 2.0 클라이언트 생성
#        - 승인된 리다이렉션 URI: https://keycloak.seungdobae.com/realms/ezl/broker/google/endpoint
#     2. Client ID, Client Secret
#
#   Kakao:
#     1. Kakao Developers에서 앱 생성
#        - Redirect URI: https://keycloak.seungdobae.com/realms/ezl/broker/kakao/endpoint
#        - 동의항목: 닉네임, 이메일 (필수 동의)
#     2. REST API 키 (Client ID), Client Secret
#
#   Naver:
#     1. Naver Developers에서 앱 생성
#        - Callback URL: https://keycloak.seungdobae.com/realms/ezl/broker/naver/endpoint
#     2. Client ID, Client Secret
#
# [기억해야 할 것]
#   - Redirect URI 형식: {keycloak_url}/realms/{realm}/broker/{alias}/endpoint
#     alias = 이 파일에서 설정하는 alias 값
#
#   - 소셜 로그인 첫 사용 시 흐름:
#     1. 소셜 계정으로 로그인
#     2. Keycloak이 신규 사용자 자동 생성 (first_broker_login_flow)
#     3. 이메일 중복 시: 기존 계정과 연결 또는 오류
#
#   - 소셜 사용자에게 Role/Group 자동 할당:
#     Identity Provider Mapper 사용
#     예) 구글 로그인 사용자 → 자동으로 "영업팀" 그룹 추가
#
#   - 폐쇄망 주의: 소셜 로그인은 인터넷 연결 필수
#     Keycloak 서버가 소셜 제공자 서버에 접근 가능해야 함
#     NAT Gateway 또는 프록시 설정 필요
#
#   - Google vs Kakao/Naver 차이:
#     Google: Keycloak 내장 provider (provider_id = "google")
#     Kakao/Naver: 일반 OIDC provider (provider_id = "oidc")
#     → Kakao/Naver는 Authorization URL 등을 직접 입력해야 함
#
# [설정 방법 - 작업 순서]
#   1. 소셜 제공자 개발자 콘솔에서 앱 생성 + Redirect URI 등록
#   2. Client ID, Secret 발급
#   3. 이 파일의 변수에 값 입력 (terraform.tfvars)
#   4. terraform apply
#   5. 로그인 화면에서 소셜 버튼 확인
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# 변수 (고객사에서 발급받은 값을 terraform.tfvars에 입력)
# 기본값 "" → 해당 소셜 로그인 비활성화
# ─────────────────────────────────────────────────────────────────────────────
variable "google_client_id" {
  description = "Google OAuth2 Client ID (비워두면 Google 로그인 비활성화)"
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth2 Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "kakao_client_id" {
  description = "Kakao REST API 키 (비워두면 Kakao 로그인 비활성화)"
  type        = string
  default     = ""
}

variable "kakao_client_secret" {
  description = "Kakao Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Google 소셜 로그인
# provider_id = "google": Keycloak 내장 Google 제공자
# google_client_id가 설정된 경우에만 생성
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_oidc_identity_provider" "google" {
  count = var.google_client_id != "" ? 1 : 0

  realm         = keycloak_realm.ezl.id
  alias         = "google"
  display_name  = "Google로 로그인"
  provider_id   = "google"
  enabled       = true

  client_id     = var.google_client_id
  client_secret = var.google_client_secret

  # Google OIDC 엔드포인트 (provider_id="google"이어도 명시 필요)
  authorization_url = "https://accounts.google.com/o/oauth2/auth"
  token_url         = "https://accounts.google.com/o/oauth2/token"

  # 요청할 scope (Google 기본값)
  default_scopes = "openid email profile"

  # 소셜 로그인 첫 사용 시 처리 플로우
  # first_broker_login_flow_alias: 신규 소셜 사용자 처리
  # "first broker login": Keycloak 기본 플로우 (이메일 확인 등)
  first_broker_login_flow_alias = "first broker login"

  # 이미 로그인된 상태에서 소셜 계정 연결 시 플로우
  post_broker_login_flow_alias = ""

  # 이메일 중복 시 기존 계정과 자동 연결 여부
  # true: 같은 이메일의 기존 계정과 자동 연결 (편의성 ↑, 보안 주의)
  # false: 별도 계정 생성 또는 수동 연결
  trust_email = true

  # 로그인 화면에서 이 제공자로 자동 리다이렉트 여부
  # true: 로그인 화면 없이 바로 Google로 이동 (단일 소셜 로그인 시)
  hide_on_login_page = false
}

# ─────────────────────────────────────────────────────────────────────────────
# Kakao 소셜 로그인
# provider_id = "oidc": 일반 OIDC 제공자 (URL 직접 입력 필요)
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_oidc_identity_provider" "kakao" {
  count = var.kakao_client_id != "" ? 1 : 0

  realm        = keycloak_realm.ezl.id
  alias        = "kakao"
  display_name = "카카오로 로그인"
  provider_id  = "oidc"
  enabled      = true

  client_id     = var.kakao_client_id
  client_secret = var.kakao_client_secret

  # Kakao OIDC 엔드포인트
  authorization_url = "https://kauth.kakao.com/oauth/authorize"
  token_url         = "https://kauth.kakao.com/oauth/token"
  user_info_url     = "https://kapi.kakao.com/v2/user/me"

  # Kakao 공개키 URL (토큰 서명 검증용)
  jwks_url = "https://kauth.kakao.com/.well-known/jwks.json"

  # Kakao 동의항목에서 요청할 scope
  # Kakao Developers에서 동의항목 설정 필요
  default_scopes = "profile_nickname profile_image account_email"

  trust_email        = false  # Kakao 이메일은 선택 동의라 신뢰하지 않음
  hide_on_login_page = false

  first_broker_login_flow_alias = "first broker login"
}

# ─────────────────────────────────────────────────────────────────────────────
# Identity Provider Mapper: 소셜 사용자에게 자동으로 Group 할당
# 예) Google 로그인 사용자 → 자동으로 "영업팀" 그룹 추가
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_attribute_importer_identity_provider_mapper" "google_email" {
  count = var.google_client_id != "" ? 1 : 0

  realm                   = keycloak_realm.ezl.id
  name                    = "google-email-mapper"
  identity_provider_alias = keycloak_oidc_identity_provider.google[0].alias

  # 소셜 제공자의 속성명
  attribute_name = "email"

  # Keycloak 사용자 속성명
  user_attribute = "email"
}
