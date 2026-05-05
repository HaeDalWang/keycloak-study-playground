# Keycloak Study Playground

Keycloak 기반 전사 인증 시스템 구축을 위한 학습 자료 및 Terraform 치트시트.

## 구조

```
├── docs/               # 학습 챕터 (챕터 1-10 + 용어집)
├── 01-single-node/     # 개발용 단일 노드 Docker Compose
├── 02-production/      # 운영 모드 Docker Compose
├── 03-ha-cluster/      # 2노드 HA + nginx
├── 08-app-integration/ # Python Flask OIDC 연동 예시
├── 09-ldap/            # OpenLDAP 실습 환경
├── Keycloak-playground/# AWS 실제 배포용 설정
└── terraform/          # 고객사 시나리오별 Terraform 치트시트
```

## Terraform 시나리오

| 파일 | 시나리오 |
|------|---------|
| keycloak-01-client.tf | 신규 앱 SSO 연결 |
| keycloak-02-org.tf | 조직도 구성 (부서/팀/권한) |
| keycloak-03-ldap.tf | AD/LDAP 연동 |
| keycloak-04-password-policy.tf | 비밀번호 정책 |
| keycloak-05-session-policy.tf | 세션/브루트포스 정책 |
| keycloak-06-mfa.tf | MFA (OTP) 강제 |
| keycloak-07-custom-claims.tf | 토큰 커스텀 정보 추가 |
| keycloak-08-social-login.tf | 소셜 로그인 (Google, Kakao) |
| keycloak-09-service-account.tf | 서버-서버 인증 |

현장 작업 가이드 → [CHEATSHEET.md](terraform/CHEATSHEET.md)

## 빠른 시작

```bash
# 로컬 단일 노드 기동
cd 01-single-node
docker compose up -d

# Admin Console
open http://localhost:8080
# admin / admin_password
```

## 환경

- Keycloak 26.6.1
- PostgreSQL 18
- Terraform Keycloak Provider 5.7.0
