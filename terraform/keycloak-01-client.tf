# =============================================================================
# 시나리오 1: 신규 서비스(Client) 온보딩
# =============================================================================
#
# [고객사 요청 표현]
#   "새로 만든 HR 포털을 Keycloak SSO에 연결하고 싶습니다."
#   "우리 앱에서 Keycloak 로그인 버튼을 만들려면 뭐가 필요합니까?"
#
# [작업 전 고객사에게 받아야 할 정보]
#   1. 앱 이름 (Client ID로 사용)
#   2. 콜백 URL (로그인 후 돌아올 주소) - 개발/스테이징/운영 각각
#   3. 앱 유형: 백엔드 서버 있음(Confidential) vs 없음(Public, SPA/모바일)
#   4. 필요한 권한(Role) 목록
#   5. 토큰에 추가로 필요한 사용자 정보 (이메일만? 부서도?)
#
# [고객사에게 줘야 할 정보]
#   1. Client ID
#   2. Client Secret (Confidential 타입만)
#   3. Realm URL: https://keycloak.seungdobae.com/realms/{realm}
#   4. OIDC Discovery URL: {Realm URL}/.well-known/openid-configuration
#
# [기억해야 할 것]
#   - Confidential: 백엔드 서버가 있는 앱. client_secret 필요. 보안 강함.
#   - Public: SPA/모바일. client_secret 없음. PKCE 필수.
#   - redirectUris 와일드카드(*) 운영에서 절대 금지. 정확한 URL만.
#   - Web Origins: CORS 허용 도메인. 프론트엔드 도메인과 일치해야 함.
#   - 운영 배포 전 반드시 redirectUris를 운영 URL로 교체할 것.
#
# [설정 방법 - 작업 순서]
#   1. Realm 확인 (keycloak.tf에서 생성된 Realm 참조)
#   2. Client 생성 (이 파일)
#   3. Client에 필요한 Role 생성
#   4. Role을 Group에 할당 (keycloak-02-org.tf 참조)
#   5. Client Secret을 개발자에게 전달
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# 예시 1-A: Confidential Client (백엔드 서버 있는 웹앱)
# 사용 케이스: HR 포털, 사내 그룹웨어, 결재 시스템 등
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_client" "hr_portal" {
  realm_id  = keycloak_realm.ezl.id
  client_id = "hr-portal"
  name      = "HR 포털"
  enabled   = true

  # Confidential: 백엔드 서버가 client_secret을 안전하게 보관 가능
  # Public으로 바꾸면 client_secret 없이 동작 (SPA/모바일용)
  access_type = "CONFIDENTIAL"

  # Authorization Code Flow 활성화 (사용자가 직접 로그인하는 경우)
  standard_flow_enabled = true

  # Client Credentials Flow 비활성화 (서버-서버 통신 시에만 true)
  service_accounts_enabled = false

  # 로그인 성공 후 돌아올 URL 목록
  # 운영: 정확한 URL만. 와일드카드(*) 절대 금지
  # 개발: http://localhost:3000/* 허용 가능
  valid_redirect_uris = [
    "https://hr.seungdobae.com/callback",
    "https://hr.seungdobae.com/*",
    # 개발 환경 추가 시:
    # "http://localhost:3000/*",
  ]

  # CORS 허용 도메인 (프론트엔드가 API 호출 시 필요)
  web_origins = [
    "https://hr.seungdobae.com",
  ]

  # 로그아웃 후 돌아올 URL
  valid_post_logout_redirect_uris = [
    "https://hr.seungdobae.com",
  ]

  # 로그인 화면에 표시될 앱 이름 (비워두면 client_id 표시)
  # name = "HR 포털"  # 위에서 이미 설정

  # 로그인 테마 (비워두면 Realm 기본 테마 사용)
  # login_theme = "ezl"
}

# ─────────────────────────────────────────────────────────────────────────────
# 예시 1-B: Public Client (SPA / 모바일 앱)
# 사용 케이스: React/Vue SPA, iOS/Android 앱
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_client" "hr_portal_spa" {
  realm_id  = keycloak_realm.ezl.id
  client_id = "hr-portal-spa"
  name      = "HR 포털 (SPA)"
  enabled   = true

  # Public: client_secret 없음. 브라우저/앱에서 직접 사용
  access_type = "PUBLIC"

  standard_flow_enabled = true

  valid_redirect_uris = [
    "https://hr.seungdobae.com/*",
  ]

  web_origins = [
    "https://hr.seungdobae.com",
  ]

  valid_post_logout_redirect_uris = [
    "https://hr.seungdobae.com",
  ]

  # PKCE 강제 (Public Client 보안 필수)
  # code_challenge_method: S256 권장 (plain은 보안 취약)
  pkce_code_challenge_method = "S256"
}

# ─────────────────────────────────────────────────────────────────────────────
# Client에 필요한 Role 생성
# 이 Role들을 Group에 할당하면 소속 사용자 전원에게 자동 적용
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_role" "hr_viewer" {
  realm_id    = keycloak_realm.ezl.id
  client_id   = keycloak_openid_client.hr_portal.id
  name        = "hr-viewer"
  description = "HR 데이터 조회 권한"
}

resource "keycloak_role" "hr_editor" {
  realm_id    = keycloak_realm.ezl.id
  client_id   = keycloak_openid_client.hr_portal.id
  name        = "hr-editor"
  description = "HR 데이터 수정 권한"
}

resource "keycloak_role" "hr_admin" {
  realm_id    = keycloak_realm.ezl.id
  client_id   = keycloak_openid_client.hr_portal.id
  name        = "hr-admin"
  description = "HR 시스템 관리자 권한"
}

# ─────────────────────────────────────────────────────────────────────────────
# Client Secret 출력 (개발자에게 전달할 값)
# 주의: terraform output 결과를 로그에 남기지 말 것
# ─────────────────────────────────────────────────────────────────────────────
output "hr_portal_client_secret" {
  value       = keycloak_openid_client.hr_portal.client_secret
  sensitive   = true
  description = "HR 포털 Client Secret - 개발자에게 안전한 채널로 전달"
}

output "hr_portal_oidc_info" {
  value = {
    client_id      = keycloak_openid_client.hr_portal.client_id
    realm_url      = "https://${local.service_domain_name}/realms/ezl"
    discovery_url  = "https://${local.service_domain_name}/realms/ezl/.well-known/openid-configuration"
    token_endpoint = "https://${local.service_domain_name}/realms/ezl/protocol/openid-connect/token"
  }
  description = "개발자에게 전달할 OIDC 연동 정보"
}
