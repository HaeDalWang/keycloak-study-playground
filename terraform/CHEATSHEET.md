# =============================================================================
# Keycloak Terraform 치트시트 - 현장 작업 가이드
# 고객사: 이동의즐거움 (EZL)
# 작성일: 2026-05
# =============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ 파일 구조 및 역할                                                         │
# ├──────────────────────────────────────────────────────────────────────────┤
# │ keycloak.tf              │ Realm 기반 설정 (모든 파일의 공통 기반)         │
# │ keycloak-01-client.tf    │ 신규 앱 SSO 연결                               │
# │ keycloak-02-org.tf       │ 조직도 구성 (부서/팀/권한)                      │
# │ keycloak-03-ldap.tf      │ AD/LDAP 연동                                   │
# │ keycloak-04-password-policy.tf │ 비밀번호 정책                            │
# │ keycloak-05-session-policy.tf  │ 세션/브루트포스 정책                     │
# │ keycloak-06-mfa.tf       │ MFA (OTP) 강제                                 │
# │ keycloak-07-custom-claims.tf   │ 토큰 커스텀 정보 추가                    │
# │ keycloak-08-social-login.tf    │ 소셜 로그인 (Google, Kakao)              │
# │ keycloak-09-service-account.tf │ 서버-서버 인증 (Client Credentials)      │
# └──────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ 최초 배포 순서 (의존성 순서)                                               │
# ├──────────────────────────────────────────────────────────────────────────┤
# │ 1. terraform init                                                         │
# │ 2. terraform.tfvars 작성 (아래 템플릿 참고)                               │
# │ 3. terraform plan (변경사항 확인)                                          │
# │ 4. terraform apply (keycloak.tf → 01 → 02 → ... 자동 순서 처리)           │
# └──────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ terraform.tfvars 템플릿 (고객사 정보 채워넣기)                             │
# ├──────────────────────────────────────────────────────────────────────────┤
# │ # 기본 설정                                                               │
# │ vpc_cidr           = "10.0.0.0/16"                                       │
# │ instance_type      = "t3.large"   # 운영: m5.xlarge 이상 권장             │
# │                                                                           │
# │ # 테스트 사용자 초기 비밀번호                                               │
# │ test_user_password = "Change1234!"                                        │
# │                                                                           │
# │ # LDAP/AD 연동 (없으면 기본값 사용)                                        │
# │ ldap_connection_url  = "ldaps://ad.customer.co.kr:636"                   │
# │ ldap_bind_dn         = "cn=svc-keycloak,ou=SA,dc=customer,dc=co,dc=kr"  │
# │ ldap_bind_credential = "서비스계정비밀번호"                                │
# │ ldap_users_dn        = "ou=Users,dc=customer,dc=co,dc=kr"               │
# │ ldap_groups_dn       = "ou=Groups,dc=customer,dc=co,dc=kr"              │
# │                                                                           │
# │ # 소셜 로그인 (없으면 비활성화)                                             │
# │ google_client_id     = ""   # Google Cloud Console에서 발급               │
# │ google_client_secret = ""                                                 │
# │ kakao_client_id      = ""   # Kakao Developers에서 발급                   │
# │ kakao_client_secret  = ""                                                 │
# └──────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ 고객사 요청별 빠른 참조                                                    │
# ├──────────────────────────────────────────────────────────────────────────┤
# │ "새 앱 SSO 연결"          → keycloak-01-client.tf 수정 후 apply           │
# │ "부서 추가/변경"           → keycloak-02-org.tf 수정 후 apply              │
# │ "AD 계정으로 로그인"       → keycloak-03-ldap.tf + tfvars 수정             │
# │ "비밀번호 정책 변경"       → keycloak-04-password-policy.tf locals 수정    │
# │ "세션 시간 조정"           → keycloak-05-session-policy.tf locals 수정     │
# │ "OTP 강제"                → keycloak-06-mfa.tf required_action 수정       │
# │ "토큰에 정보 추가"         → keycloak-07-custom-claims.tf 수정             │
# │ "소셜 로그인 추가"         → keycloak-08-social-login.tf + tfvars 수정     │
# │ "서버-서버 인증"           → keycloak-09-service-account.tf 수정           │
# └──────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ 현장에서 자주 쓰는 명령어                                                  │
# ├──────────────────────────────────────────────────────────────────────────┤
# │ # Client Secret 확인                                                      │
# │ terraform output hr_portal_client_secret                                  │
# │                                                                           │
# │ # 개발자에게 줄 OIDC 정보 확인                                             │
# │ terraform output hr_portal_oidc_info                                      │
# │                                                                           │
# │ # 특정 리소스만 재적용                                                     │
# │ terraform apply -target=keycloak_realm.ezl                                │
# │                                                                           │
# │ # 현재 상태와 실제 Keycloak 비교                                           │
# │ terraform plan                                                             │
# │                                                                           │
# │ # 특정 리소스 상태 확인                                                    │
# │ terraform state show keycloak_openid_client.hr_portal                     │
# │                                                                           │
# │ # Realm 전체 Export (백업)                                                 │
# │ docker exec keycloak /opt/keycloak/bin/kc.sh export \                     │
# │   --dir /tmp/export --realm ezl --users skip                              │
# └──────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ 개발자에게 전달할 정보 체크리스트                                           │
# ├──────────────────────────────────────────────────────────────────────────┤
# │ □ Client ID                                                               │
# │ □ Client Secret (Confidential 타입만)                                     │
# │ □ Realm URL: https://keycloak.seungdobae.com/realms/ezl                  │
# │ □ Discovery URL: {Realm URL}/.well-known/openid-configuration             │
# │ □ 권한 체계: 어떤 Role이 있고 토큰의 어디서 읽는지                          │
# │   - Realm Role → token.realm_access.roles                                │
# │   - Client Role → token.resource_access.{client-id}.roles                │
# │   - 커스텀 속성 → token.{claim_name}                                      │
# │ □ Redirect URI 등록 완료 확인                                              │
# └──────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ 자주 발생하는 오류와 해결                                                  │
# ├──────────────────────────────────────────────────────────────────────────┤
# │ "Invalid redirect_uri"                                                    │
# │   → keycloak-01-client.tf의 valid_redirect_uris에 해당 URL 추가           │
# │                                                                           │
# │ "Client not found" (terraform apply 오류)                                 │
# │   → client_id 오타 또는 Realm 불일치 확인                                 │
# │                                                                           │
# │ "Invalid client credentials"                                              │
# │   → terraform output으로 최신 secret 확인 후 개발자에게 재전달             │
# │                                                                           │
# │ LDAP 동기화 후 사용자 없음                                                 │
# │   → ldap_users_dn 경로 확인, search_scope=SUBTREE 확인                    │
# │   → Admin Console: User Federation → Sync All Users 수동 실행             │
# │                                                                           │
# │ 토큰에 Role이 없음                                                         │
# │   → 사용자가 Group에 속해있는지 확인                                       │
# │   → Group에 Role이 할당되어 있는지 확인 (keycloak-02-org.tf)               │
# │                                                                           │
# │ "time: missing unit in duration"                                          │
# │   → 세션 시간값을 초(int) 대신 "30m", "8h" 형식으로 변경                  │
# └──────────────────────────────────────────────────────────────────────────┘
