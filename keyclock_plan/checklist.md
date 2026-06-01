EZL 고객사 요구사항 수집 체크리스트
전제 확인 완료: HA 구성, 폐쇄망, AD 연동

A. 서버/인프라 환경

□ Keycloak 서버 몇 대 사용하실 생각인지? (HA니까 최소 2대)
  → keycloak.conf: 노드 수, JDBC_PING 설정

□ 각 서버 상세 스펙은? (CPU, RAM, 디스크)
  → JVM 힙 메모리 설정값 결정 (-Xms/-Xmx)

□ OS는 무엇인가요? (RHEL/Rocky/Ubuntu)
  → systemd 서비스 등록 방식

□ DB는 무엇을 쓰시나요? (PostgreSQL 권장)
  → keycloak.conf: db=postgres, db-url, db-username, db-password

□ DB 서버는 별도인가요, Keycloak 서버와 같은 서버인가요?
  → db-url 호스트 결정

□ 서버들 간 내부 통신 IP 대역은?
  → JDBC_PING jgroups 설정의 bind_addr
B. 도메인/접속 환경

□ Keycloak 접속 도메인이 있나요? (예: auth.company.co.kr)
  → keycloak.conf: hostname=auth.company.co.kr

□ 앞단에 L4/L7 로드밸런서나 Nginx가 있나요?
  → keycloak.conf: proxy-headers=xforwarded

□ SSL 인증서는 어떻게 발급하나요?
  - 내부 CA 발급 (폐쇄망 일반적)
  - 공인 인증서
  → keycloak.conf: https-certificate-file, https-certificate-key-file

□ 내부 사용자들이 접속하는 포트는? (기본 443 또는 8443)
  → keycloak.conf: https-port
C. AD/LDAP 연동

□ AD 서버 IP 또는 호스트명은?
  → ldap_connection_url = "ldaps://AD서버IP:636"

□ LDAPS(636포트, 암호화) 사용 가능한가요, 아니면 LDAP(389)만 가능한가요?
  → 보안 수준 결정

□ Keycloak이 AD에 접속할 전용 서비스 계정을 만들어줄 수 있나요?
  (읽기 전용 계정, 예: svc-keycloak)
  → ldap_bind_dn, ldap_bind_credential

□ 사용자 계정이 있는 OU 경로는?
  (예: OU=Users,DC=company,DC=co,DC=kr)
  → ldap_users_dn

□ 부서/그룹 정보가 있는 OU 경로는?
  → ldap_groups_dn

□ 직원들이 로그인할 때 쓰는 ID 형식은?
  - 사번/영문ID (예: hong.gildong) → sAMAccountName
  - 이메일 형식 (예: hong@company.co.kr) → userPrincipalName
  → ldap_username_attribute

□ AD 사용자 수는 총 몇 명인가요?
  → Sync 주기 및 성능 설정

□ 퇴사자 처리는 어떻게 하나요? (AD 계정 비활성화? 삭제?)
  → editMode=READ_ONLY 확인, 동기화 정책
D. 연동할 애플리케이션 (SSO 범위)

□ Keycloak SSO를 붙여야 할 시스템/앱 목록을 알 수 있나요?
  (예: 그룹웨어, ERP, 사내 포털, 개발 도구 등)
  → keycloak-01-client.tf: Client 수 결정

□ 각 앱의 접속 URL은?
  (예: https://portal.company.co.kr)
  → Client의 redirectUris, webOrigins

□ 각 앱이 어떤 방식으로 로그인을 처리하나요?
  - 웹 브라우저 기반 → OIDC Authorization Code Flow
  - 다른 서버가 API 호출 → Client Credentials (서비스 계정)
  - 레거시 시스템 → SAML 2.0
  → Client 타입 결정

□ 앱 개발사/담당자가 있나요? (연동 시 Client Secret 전달 필요)
  → 개발자 전달용 정보 준비
E. 조직/권한 구조

□ 회사 부서 구조를 알 수 있나요?
  (조직도 또는 AD OU 구조)
  → keycloak-02-org.tf: Group 구조

□ 시스템별로 접근 권한이 다른가요?
  (예: 인사팀만 HR 시스템 접근, 개발팀만 Jira 접근)
  → Role 설계

□ Keycloak 관리자(Admin)는 누가 될 예정인가요?
  → admin 계정 및 권한 설정

□ 부서장/일반직원 등 직급별 권한 차이가 필요한가요?
  → Role 계층 설계
F. 비밀번호 정책

□ 비밀번호 최소 길이는? (일반적으로 8~12자)
  → keycloak-04-password-policy.tf: length

□ 비밀번호 복잡도 요구사항이 있나요?
  (대문자, 소문자, 숫자, 특수문자 포함 여부)
  → upperCase, lowerCase, digits, specialChars

□ 비밀번호 유효기간이 있나요? (예: 90일마다 변경)
  → passwordAge

□ 이전 비밀번호 재사용 금지 횟수는?
  → passwordHistory

□ 최초 로그인 시 비밀번호 변경을 강제할까요?
  → requiredAction: UPDATE_PASSWORD
G. 세션/로그인 정책

□ 로그인 후 아무것도 안 하면 몇 분 후 자동 로그아웃 되어야 하나요?
  → keycloak-05-session-policy.tf: ssoSessionIdleTimeout

□ 계속 사용해도 최대 로그인 유지 시간은?
  (예: 8시간 후 재로그인 필요)
  → ssoSessionMaxLifespan

□ 로그인 실패 몇 번 후 계정을 잠글까요?
  (예: 5회 실패 → 30분 잠금)
  → brute force protection 설정
H. MFA (2차 인증)

□ 2차 인증(OTP)이 필요한가요?
  → keycloak-06-mfa.tf 활성화 여부

□ 모든 직원에게 강제인가요, 특정 그룹만인가요?
  (예: 관리자, 재무팀만 OTP 필수)
  → Authentication Flow 조건 설정

□ OTP 앱은 어떤 걸 쓸 예정인가요?
  (Google Authenticator, Microsoft Authenticator 등)
  → TOTP 설정 (대부분 호환)
I. 토큰/앱 연동 커스터마이징

□ 앱에서 로그인한 사용자의 추가 정보가 필요한가요?
  (예: 사번, 부서명, 직급을 토큰에 포함)
  → keycloak-07-custom-claims.tf: Attribute Mapper

□ AD의 어떤 속성을 토큰에 담을까요?
  (예: employeeID, department, title)
  → LDAP Attribute → Token Claim 매핑
J. 운영/알림

□ 로그는 어디에 저장할 예정인가요?
  (로컬 파일 / 중앙 로그 서버 / SIEM)
  → keycloak.conf: log, log-file

□ 장애 발생 시 알림을 받을 방법이 있나요?
  (이메일, SMS, 모니터링 시스템)
  → 운영 체계 확인

□ 정기 백업 정책이 있나요?
  → DB 백업 + Realm Export 주기
이걸 미팅 전에 구글 폼이나 엑셀로 만들어서 고객한테 미리 보내면 미팅 시간이 반으로 줄어든다. 모르는 항목은 "확인 후 전달"로 받아도 되고, 답변 받은 것들이 그대로 terraform.tfvars 값이 된다.