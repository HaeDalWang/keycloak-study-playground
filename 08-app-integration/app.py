"""
JTBC HR 시스템 - Keycloak OIDC 연동 데모
Authorization Code Flow 구현

흐름:
1. 사용자가 / 접속
2. /login 클릭 → Keycloak 로그인 페이지로 리다이렉트
3. 로그인 성공 → Keycloak이 /callback?code=xxx 로 리다이렉트
4. 서버가 code → access_token 교환
5. access_token의 roles 확인 → 권한별 기능 노출
"""

import base64
import json
import os
import secrets

import requests
from flask import Flask, redirect, request, session, url_for

app = Flask(__name__)
app.secret_key = secrets.token_hex(32)

# ── Keycloak 설정 (개발자가 받는 정보) ────────────────────────
KEYCLOAK_URL    = "http://localhost:8080"
REALM           = "jtbc"
CLIENT_ID       = "hr-system"
CLIENT_SECRET   = "AMEWe6TUAxU7QxS170dCEP6UvzqEWgc4"
REDIRECT_URI    = "http://localhost:5001/callback"

# OIDC 엔드포인트 (디스커버리에서 자동으로 가져올 수도 있음)
AUTH_URL        = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/auth"
TOKEN_URL       = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token"
LOGOUT_URL      = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/logout"


def decode_jwt_payload(token: str) -> dict:
    """JWT Payload를 Base64 디코딩 (서명 검증 없이 내용만 확인)"""
    payload = token.split(".")[1]
    padding = 4 - len(payload) % 4
    if padding != 4:
        payload += "=" * padding
    return json.loads(base64.urlsafe_b64decode(payload))


def get_user_roles(token: str) -> list:
    """Access Token에서 Realm Role 목록 추출"""
    payload = decode_jwt_payload(token)
    return payload.get("realm_access", {}).get("roles", [])


def require_role(role: str):
    """특정 Role이 없으면 403 반환하는 데코레이터"""
    def decorator(f):
        def wrapper(*args, **kwargs):
            token = session.get("access_token")
            if not token:
                return redirect(url_for("login"))
            if role not in get_user_roles(token):
                return f"""
                <h2>403 Forbidden</h2>
                <p><b>{role}</b> 권한이 없습니다.</p>
                <p>현재 보유 권한: {get_user_roles(token)}</p>
                <a href="/">홈으로</a>
                """, 403
            return f(*args, **kwargs)
        wrapper.__name__ = f.__name__
        return wrapper
    return decorator


# ── 라우트 ────────────────────────────────────────────────────

@app.route("/")
def index():
    token = session.get("access_token")
    if not token:
        return """
        <html><body style="font-family:Arial; max-width:600px; margin:50px auto; padding:20px">
        <h1>JTBC HR 시스템</h1>
        <p>이 시스템은 Keycloak으로 보호됩니다.</p>
        <a href="/login" style="background:#e8002d;color:white;padding:10px 20px;
           text-decoration:none;border-radius:4px">JTBC 계정으로 로그인</a>
        </body></html>
        """

    payload = decode_jwt_payload(token)
    roles = get_user_roles(token)
    username = payload.get("preferred_username", "")

    # 보유 Role에 따라 메뉴 동적 생성
    menu_items = []
    if "ROLE_HR_ACCESS" in roles:
        menu_items.append('<li><a href="/hr-data">📋 HR 데이터 조회</a> (ROLE_HR_ACCESS)</li>')
    if "ROLE_APPROVAL_ACCESS" in roles:
        menu_items.append('<li><a href="/approval">✅ 결재 시스템</a> (ROLE_APPROVAL_ACCESS)</li>')
    if not menu_items:
        menu_items.append('<li>접근 가능한 메뉴가 없습니다.</li>')

    return f"""
    <html><body style="font-family:Arial; max-width:600px; margin:50px auto; padding:20px">
    <h1>JTBC HR 시스템</h1>
    <p>안녕하세요, <b>{username}</b>님</p>
    <p>보유 권한: <code>{roles}</code></p>
    <hr>
    <h3>접근 가능한 메뉴</h3>
    <ul>{''.join(menu_items)}</ul>
    <hr>
    <a href="/logout">로그아웃</a>
    </body></html>
    """


@app.route("/login")
def login():
    """
    Authorization Code Flow - 1단계
    사용자를 Keycloak 로그인 페이지로 리다이렉트
    state: CSRF 방지용 랜덤 값
    """
    state = secrets.token_urlsafe(16)
    session["oauth_state"] = state

    params = {
        "client_id":     CLIENT_ID,
        "redirect_uri":  REDIRECT_URI,
        "response_type": "code",          # Authorization Code Flow
        "scope":         "openid profile email",
        "state":         state,           # CSRF 방지
    }
    query = "&".join(f"{k}={v}" for k, v in params.items())
    return redirect(f"{AUTH_URL}?{query}")


@app.route("/callback")
def callback():
    """
    Authorization Code Flow - 2단계
    Keycloak이 code를 들고 여기로 리다이렉트
    서버에서 code → access_token 교환 (브라우저는 이 과정을 모름)
    """
    # CSRF 검증
    if request.args.get("state") != session.pop("oauth_state", None):
        return "CSRF 검증 실패", 400

    code = request.args.get("code")
    if not code:
        return f"오류: {request.args.get('error_description', '알 수 없는 오류')}", 400

    # code → token 교환 (백엔드에서 처리 - client_secret 사용)
    resp = requests.post(TOKEN_URL, data={
        "grant_type":    "authorization_code",
        "client_id":     CLIENT_ID,
        "client_secret": CLIENT_SECRET,   # 브라우저에 절대 노출 안 됨
        "redirect_uri":  REDIRECT_URI,
        "code":          code,
    })

    if resp.status_code != 200:
        return f"토큰 교환 실패: {resp.text}", 400

    tokens = resp.json()
    session["access_token"]  = tokens["access_token"]
    session["refresh_token"] = tokens["refresh_token"]

    return redirect(url_for("index"))


@app.route("/hr-data")
@require_role("ROLE_HR_ACCESS")
def hr_data():
    """ROLE_HR_ACCESS 가 있어야만 접근 가능한 엔드포인트"""
    payload = decode_jwt_payload(session["access_token"])
    return f"""
    <html><body style="font-family:Arial; max-width:600px; margin:50px auto; padding:20px">
    <h1>📋 HR 데이터</h1>
    <p>이 페이지는 <b>ROLE_HR_ACCESS</b> 보유자만 볼 수 있습니다.</p>
    <table border="1" cellpadding="8" style="border-collapse:collapse">
      <tr><th>이름</th><th>부서</th><th>연봉</th></tr>
      <tr><td>김철수</td><td>개발팀</td><td>비공개</td></tr>
      <tr><td>이영희</td><td>인사팀</td><td>비공개</td></tr>
    </table>
    <br>
    <p>토큰 발급자: <code>{payload.get('iss')}</code></p>
    <p>토큰 만료: <code>{payload.get('exp')}</code></p>
    <br><a href="/">홈으로</a>
    </body></html>
    """


@app.route("/approval")
@require_role("ROLE_APPROVAL_ACCESS")
def approval():
    """ROLE_APPROVAL_ACCESS 가 있어야만 접근 가능한 엔드포인트"""
    return """
    <html><body style="font-family:Arial; max-width:600px; margin:50px auto; padding:20px">
    <h1>✅ 결재 시스템</h1>
    <p>이 페이지는 <b>ROLE_APPROVAL_ACCESS</b> 보유자만 볼 수 있습니다.</p>
    <br><a href="/">홈으로</a>
    </body></html>
    """


@app.route("/logout")
def logout():
    """
    Keycloak Single Logout
    앱 세션 삭제 + Keycloak 세션도 종료
    """
    refresh_token = session.pop("refresh_token", None)
    session.clear()

    if refresh_token:
        # Keycloak에 로그아웃 요청 (SSO 세션 종료)
        requests.post(LOGOUT_URL, data={
            "client_id":     CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "refresh_token": refresh_token,
        })

    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(port=5001, debug=True)
