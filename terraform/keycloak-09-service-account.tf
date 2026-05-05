# =============================================================================
# 시나리오 9: 서비스 계정 (Client Credentials Flow)
# =============================================================================
#
# [고객사 요청 표현]
#   "백엔드 서비스끼리 API를 호출할 때도 인증이 필요합니다."
#   "사용자 로그인 없이 서버가 직접 토큰을 발급받을 수 있나요?"
#   "배치 작업이 Keycloak으로 보호된 API를 호출해야 합니다."
#
# [작업 전 고객사에게 받아야 할 정보]
#   1. 서비스 이름 (Client ID로 사용)
#   2. 이 서비스가 호출할 API 목록
#   3. 필요한 권한(Role) 목록
#
# [고객사에게 줘야 할 정보]
#   1. Client ID
#   2. Client Secret
#   3. Token URL: https://keycloak.seungdobae.com/realms/ezl/protocol/openid-connect/token
#   4. Grant Type: client_credentials
#
#   개발자 사용 예시:
#   curl -X POST {token_url} \
#     -d "grant_type=client_credentials" \
#     -d "client_id={client_id}" \
#     -d "client_secret={client_secret}"
#
# [기억해야 할 것]
#   - Client Credentials Flow = 사용자 없음. 서비스 자체가 주체.
#     토큰의 sub = 서비스 계정 UUID (사람 UUID가 아님)
#
#   - Authorization Code Flow vs Client Credentials Flow
#     Authorization Code: 사람이 로그인 → 사람의 권한으로 API 호출
#     Client Credentials: 서비스가 직접 → 서비스의 권한으로 API 호출
#
#   - 서비스 계정 Role 할당:
#     keycloak_openid_client_service_account_role 리소스 사용
#     일반 사용자 Role 할당과 다름 (service_account_user에게 할당)
#
#   - Client Secret 보안:
#     서버 환경변수 또는 Secret Manager에 저장
#     코드에 하드코딩 절대 금지
#     주기적 교체 권장 (Keycloak Admin Console에서 Regenerate)
#
#   - 서비스 계정 토큰에는 사용자 정보(email, name 등) 없음
#     realm_access.roles에 할당된 Role만 포함
#
# [설정 방법 - 작업 순서]
#   1. 서비스 Client 생성 (service_accounts_enabled = true)
#   2. 서비스 계정에 필요한 Role 할당
#   3. Client Secret을 개발팀에 전달
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# 서비스 계정 Client 생성
# 예시: 알림 서비스가 HR API를 호출하는 경우
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_openid_client" "notification_service" {
  realm_id  = keycloak_realm.ezl.id
  client_id = "notification-service"
  name      = "알림 서비스"
  enabled   = true

  # CONFIDENTIAL: client_secret 필요 (서비스 계정은 항상 CONFIDENTIAL)
  access_type = "CONFIDENTIAL"

  # 사용자 로그인 플로우 비활성화 (서비스 계정은 사람이 로그인하지 않음)
  standard_flow_enabled = false

  # Client Credentials Flow 활성화 (서비스 계정의 핵심 설정)
  service_accounts_enabled = true

  # 서비스 계정은 redirect URI 불필요
  valid_redirect_uris = []
}

# ─────────────────────────────────────────────────────────────────────────────
# 서비스 계정에 Realm Role 할당
# 서비스 계정 사용자(service_account_user_id)를 일반 사용자처럼 취급
# keycloak_openid_client_service_account_role은 Client Role 전용
# Realm Role 할당은 keycloak_user_roles 사용
# ─────────────────────────────────────────────────────────────────────────────
resource "keycloak_user_roles" "notification_service_roles" {
  realm_id = keycloak_realm.ezl.id
  user_id  = keycloak_openid_client.notification_service.service_account_user_id

  role_ids = [
    keycloak_role.hr_access.id,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# 출력: 개발팀에 전달할 정보
# ─────────────────────────────────────────────────────────────────────────────
output "notification_service_info" {
  value = {
    client_id   = keycloak_openid_client.notification_service.client_id
    token_url   = "https://${local.service_domain_name}/realms/ezl/protocol/openid-connect/token"
    grant_type  = "client_credentials"
    curl_example = "curl -X POST https://${local.service_domain_name}/realms/ezl/protocol/openid-connect/token -d 'grant_type=client_credentials&client_id=notification-service&client_secret=<SECRET>'"
  }
  description = "알림 서비스 Client Credentials 연동 정보"
}

output "notification_service_secret" {
  value       = keycloak_openid_client.notification_service.client_secret
  sensitive   = true
  description = "알림 서비스 Client Secret - 개발팀에 안전한 채널로 전달"
}
