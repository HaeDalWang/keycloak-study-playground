# OAuth2 토큰 vs OIDC 토큰 비교

---

## 1. OAuth2 Access Token

OAuth2는 토큰 형식을 강제하지 않습니다. 두 가지 형태가 존재합니다.

### 형태 A: Opaque Token (불투명 토큰)
```
94b2d4f1-3c8a-4e2b-9f1d-7a6c5e8b2d3f
```
- 그냥 랜덤 문자열입니다.
- 앱이 이 토큰을 받으면 **내용을 알 수 없습니다.**
- 검증하려면 매번 Authorization Server(Keycloak)에 물어봐야 합니다.
  ```
  GET /realms/ezl/protocol/openid-connect/userinfo
  Authorization: Bearer 94b2d4f1-3c8a-4e2b-9f1d-7a6c5e8b2d3f
  ```

### 형태 B: JWT Access Token (Keycloak 기본값)
```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTAwMSIsImF6cCI6ImhyLXN5c3RlbSIsInNjb3BlIjoicmVhZCIsImV4cCI6MTc0ODAwMDMwMH0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

점(`.`) 3개로 구분된 구조: `헤더.페이로드.서명`

**Base64 디코딩하면:**
```json
// 헤더
{
  "alg": "RS256",
  "typ": "JWT"
}

// 페이로드 (Access Token)
{
  "sub": "user-001",           // 사용자 ID
  "azp": "hr-system",          // 어떤 앱이 요청했는가
  "scope": "read write",       // 허용된 권한 범위
  "exp": 1748000300,           // 만료 시간 (Unix timestamp)
  "iat": 1748000000,           // 발급 시간
  "iss": "https://keycloak.example.com/realms/ezl"
}
```

**핵심:** `scope`는 있지만 **사용자 이름, 이메일 같은 신원 정보가 없습니다.**
"이 앱이 read/write 권한을 가졌다"는 것만 알 수 있습니다.

---

## 2. OIDC ID Token

OIDC는 항상 JWT입니다. Access Token과 **함께** 발급됩니다.

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTAwMSIsIm5hbWUiOiLquYDssITsupAiLCJlbWFpbCI6ImtpbUBlemwuY29tIiwicm9sZXMiOlsi7YyM7J2YIiwiSFJfQUNDRVNTIl0sImV4cCI6MTc0ODAwMDMwMH0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

**Base64 디코딩하면:**
```json
// 페이로드 (ID Token)
{
  "sub": "user-001",                    // 사용자 고유 ID (변하지 않음)
  "name": "김철수",                      // 이름 ← OAuth2에는 없음
  "email": "kim@ezl.com",              // 이메일 ← OAuth2에는 없음
  "preferred_username": "kim.cs",      // 로그인 ID ← OAuth2에는 없음
  "roles": ["팀장", "HR_ACCESS"],       // 역할 ← Keycloak 커스텀 클레임
  "department": "개발팀",               // 부서 ← Keycloak 커스텀 클레임
  "exp": 1748000300,
  "iat": 1748000000,
  "iss": "https://keycloak.example.com/realms/ezl",
  "aud": "hr-system",                  // 이 토큰을 받을 앱
  "nonce": "abc123"                    // 재사용 공격 방지
}
```

---

## 3. 한눈에 비교

| 항목 | OAuth2 Access Token | OIDC ID Token |
|------|---------------------|---------------|
| 목적 | "이 앱이 X 권한을 가졌다" | "이 사람은 누구다" |
| 형식 | Opaque 또는 JWT | 항상 JWT |
| sub | 있음 (사용자 ID) | 있음 (사용자 ID) |
| name / email | **없음** | **있음** |
| roles | 없음 (scope만) | 있음 (Keycloak 설정 시) |
| scope | 있음 | 없음 |
| aud | 리소스 서버 | 클라이언트 앱 |
| 누가 쓰나 | API 서버 (권한 확인) | 앱 프론트엔드 (사용자 정보 표시) |

---

## 4. Keycloak에서 실제로 받는 응답

로그인 성공 시 Keycloak이 한 번에 3개를 줍니다:

```json
{
  "access_token": "eyJhbGci...",     // API 호출할 때 쓰는 토큰
  "id_token": "eyJhbGci...",         // 사용자 정보 담긴 토큰
  "refresh_token": "eyJhbGci...",    // 만료 후 재발급용 (유저 없이도 갱신 가능)
  "expires_in": 300,                 // access_token 만료: 5분
  "refresh_expires_in": 1800,        // refresh_token 만료: 30분
  "token_type": "Bearer"
}
```

---

## 5. JWT 직접 디코딩해보기

실제 Keycloak 토큰을 받으면 터미널에서 바로 확인 가능합니다:

```bash
# 토큰의 페이로드 부분(두 번째 .으로 구분된 부분)만 디코딩
TOKEN="eyJzdWIiOiJ1c2VyLTAwMSIsIm5hbWUiOiLquYDssITsupAifQ"
echo $TOKEN | base64 -d | python3 -m json.tool
```

또는 jwt.io 사이트에 붙여넣으면 바로 디코딩됩니다.

---

## 핵심 요약

- **OAuth2만** 쓰면: "이 앱이 read 권한 있음" — 사용자가 누군지 모름
- **OIDC 추가** 하면: "이 앱이 read 권한 있고, 사용자는 김철수(팀장)임"
- **Keycloak 실무**: 항상 OIDC로 연동 → access_token + id_token 둘 다 받음
