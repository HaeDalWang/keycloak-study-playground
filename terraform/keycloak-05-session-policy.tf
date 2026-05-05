# =============================================================================
# 시나리오 5: 세션 정책
# =============================================================================
#
# [고객사 요청 표현]
#   "30분 동안 아무것도 안 하면 자동 로그아웃 되게 해주세요."
#   "로그인 상태가 너무 자주 끊겨요. 8시간은 유지되게 해주세요."
#   "보안상 최대 로그인 유지 시간을 하루로 제한하고 싶어요."
#
# [작업 전 고객사에게 받아야 할 정보]
#   1. 미사용 시 자동 로그아웃 시간 (idle timeout)
#   2. 최대 세션 유지 시간 (max lifespan)
#   3. Access Token 유효기간 (짧을수록 보안 강화, 길수록 편의성)
#   4. Refresh Token 유효기간
#   5. "로그인 상태 유지" 체크박스 허용 여부
#
# [기억해야 할 것]
#   ┌─────────────────────────────────────────────────────────────┐
#   │ 세션 관련 시간 값 정리 (모두 초 단위)                         │
#   ├──────────────────────────────┬──────────────────────────────┤
#   │ 설정명                       │ 의미                          │
#   ├──────────────────────────────┼──────────────────────────────┤
#   │ sso_session_idle_timeout     │ 미사용 시 세션 만료            │
#   │ sso_session_max_lifespan     │ 사용 중이어도 이 시간 후 만료  │
#   │ access_token_lifespan        │ Access Token 유효기간          │
#   │ access_token_lifespan_for_   │ 암묵적 흐름 토큰 유효기간      │
#   │   implicit_flow              │                               │
#   │ offline_session_idle_timeout │ 오프라인 세션 idle 만료        │
#   │ offline_session_max_lifespan │ 오프라인 세션 최대 유지        │
#   └──────────────────────────────┴──────────────────────────────┘
#
#   - Access Token은 짧게 (5분), Refresh Token은 길게 (세션 시간과 동일)
#     이유: Access Token 탈취 시 피해 최소화
#
#   - sso_session_idle_timeout < sso_session_max_lifespan 이어야 함
#     idle=8h, max=24h → 8시간 미사용 시 로그아웃, 사용 중이어도 24시간 후 강제 로그아웃
#
#   - "로그인 상태 유지" 체크박스 = remember_me
#     true 허용 시: remember_me_session_idle_timeout, remember_me_session_max_lifespan 별도 설정
#
# [설정 방법]
#   이 파일의 locals를 수정 → keycloak.tf의 keycloak_realm.ezl에 자동 반영
# =============================================================================

locals {
  # ── 일반 세션 설정 ────────────────────────────────────────
  # 단위: Go duration 문자열 ("30m", "8h", "24h" 등)
  # Terraform Keycloak provider는 초(int)가 아닌 duration string을 요구

  # 미사용(idle) 시 세션 만료
  sso_session_idle_timeout = "30m"

  # 최대 세션 유지 시간 (사용 중이어도 강제 만료)
  sso_session_max_lifespan = "8h"

  # Access Token 유효기간 (짧을수록 보안 강화)
  access_token_lifespan = "5m"

  # Refresh Token 최대 재사용 횟수 (0=무제한)
  refresh_token_max_reuse = 0

  # ── 브루트포스 보호 설정 (단위: 초, int) ─────────────────
  # 세션 설정과 달리 브루트포스 필드는 정수(초)로 입력
  brute_force_protected = true
  failure_factor        = 5
  wait_increment_seconds   = 60    # 1분
  max_failure_wait_seconds = 900   # 15분
  max_delta_time_seconds   = 43200 # 12시간
  permanent_lockout        = false
}
