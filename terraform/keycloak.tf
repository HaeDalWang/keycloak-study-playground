# =============================================================================
# Keycloak 기반 설정 - 모든 시나리오의 공통 기반
# =============================================================================
#
# [이 파일의 역할]
#   모든 keycloak-XX-*.tf 파일이 이 파일의 리소스를 참조한다.
#   Realm이 없으면 Client, Role, Group 아무것도 만들 수 없다.
#
# [작업 순서]
#   1. 이 파일 먼저 apply (Realm 생성)
#   2. 이후 시나리오별 파일 apply
#
# [기억해야 할 것]
#   - Realm 이름은 토큰 issuer URL에 포함됨
#     예) https://keycloak.seungdobae.com/realms/jtbc
#   - Realm 이름 변경 = 기존 토큰 전부 무효화 → 운영 중 변경 절대 금지
#   - displayName은 로그인 화면에 표시되는 이름 (변경 가능)
# =============================================================================

resource "keycloak_realm" "ezl" {
  realm   = "ezl"
  enabled = true

  display_name      = "이동의즐거움"
  display_name_html = "<span style='font-size:24px;font-weight:700;'>이동의즐거움</span>"

  # ── 테마 설정 ─────────────────────────────────────────────
  # login_theme   = "ezl"
  # account_theme = "ezl"

  # ── 사용자 셀프 서비스 ────────────────────────────────────
  registration_allowed     = false
  reset_password_allowed   = true
  login_with_email_allowed = true

  # ── 국제화 ───────────────────────────────────────────────
  internationalization {
    supported_locales = ["ko", "en"]
    default_locale    = "ko"
  }

  # ── 비밀번호 정책 (keycloak-04-password-policy.tf에서 정의) ──
  password_policy = local.password_policy

  # ── 세션 정책 (keycloak-05-session-policy.tf에서 정의) ───────
  sso_session_idle_timeout = local.sso_session_idle_timeout
  sso_session_max_lifespan = local.sso_session_max_lifespan
  access_token_lifespan    = local.access_token_lifespan

  # ── 브루트포스 보호 (keycloak-05-session-policy.tf에서 정의) ─
  security_defenses {
    brute_force_detection {
      permanent_lockout                = local.permanent_lockout
      max_login_failures               = local.failure_factor
      wait_increment_seconds           = local.wait_increment_seconds
      max_failure_wait_seconds         = local.max_failure_wait_seconds
      failure_reset_time_seconds       = local.max_delta_time_seconds
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
    }
  }

  # ── SMTP 설정 ─────────────────────────────────────────────
  # smtp_server {
  #   host     = "smtp.ezl.com"
  #   port     = 587
  #   from     = "noreply@ezl.com"
  #   starttls = true
  #   auth {
  #     username = var.smtp_username
  #     password = var.smtp_password
  #   }
  # }
}
