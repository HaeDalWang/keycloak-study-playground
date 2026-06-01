# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 저장소의 성격

이곳은 **Keycloak 학습 + 실제 고객사 프로젝트 투입 전 실습 공간**이다. 운영 시스템이 아니다.

- 소유자는 AWS 클라우드 엔지니어로 Terraform/EC2에는 능하지만, OAuth2 / OIDC / SAML 등 IAM·보안 도메인 지식은 처음 쌓는 중이다. 설명은 "왜 이 설정이 필요한가"까지 짚어 주는 멘토 톤이 적합하다 (페르소나·학습 원칙은 `AGENTS.md` 참고).
- 모든 인프라 설정은 **폐쇄망 데이터센터 VM**(멀티캐스트 불가, 인터넷 차단)을 가정한다. 그래서 클러스터링은 멀티캐스트가 아닌 `JDBC_PING` / `TCP_PING`(JGroups) 기반으로 구성한다.
- 가상 고객사는 **이동의즐거움(EZL)** 과 **JTBC** 두 가지가 혼재한다. `terraform/`는 EZL realm, `08-kc-as-code/`는 JTBC realm 기준이다.

## 절대 규칙

- **`terraform apply`를 절대 실행하지 말 것.** 어떤 디렉토리에서도, `-target` 포함 어떤 형태로도 안 된다. 변경 확인이 필요하면 `terraform plan`까지만 수행한다. (실습 비용·실수 방지를 위한 소유자 명시 지시)
- 마찬가지로 `terraform destroy`도 실행하지 않는다.
- 자격증명이 코드에 하드코딩된 실습 파일이 있다(`terraform/providers.tf`의 admin password, `08-app-integration/app.py`의 CLIENT_SECRET 등). 이는 로컬 실습용이며, 실제 고객사 작업으로 옮길 때는 반드시 변수/시크릿으로 분리한다.

## 디렉토리 구조

크게 **Docker 로컬 실습**, **Terraform 인프라/Provider**, **앱 연동**, **학습 문서**로 나뉜다.

### Docker Compose 실습 (단계별 난이도)
| 디렉토리 | 목적 |
|---------|------|
| `01-single-node/` | 개발용 단일 노드 (`start-dev`, HTTP, 캐시 최소) |
| `02-production/` | 운영 모드(`start`) 전환 실습 |
| `03-ha-cluster/` | 2노드 HA + Infinispan(`KC_CACHE=ispn`, `tcp` 스택) + nginx LB |
| `09-ldap/` | OpenLDAP 연동 실습 (`init.ldif`) |
| `10-saml/` | SAML 연동 실습 |

### Terraform (3개 독립 stack — state·목적이 서로 다름)
| 디렉토리 | 목적 | Provider |
|---------|------|---------|
| `terraform/` | Keycloak **설정**(Realm/Client/Role 등)을 코드로 관리. AWS(VPC+ALB+EC2 2노드)도 포함 | `keycloak/keycloak` 5.7.0 + `hashicorp/aws` |
| `terraform_windowsad_keycloak/` | Windows AD(2노드) + Bastion + Keycloak(Ubuntu 2노드) **인프라**. AD/LDAP 연동 실습용 (`요구사항.md` 참고) | AWS |
| `terraform-keepalived/` | VRRP `keepalived` + EIP(VIP) 기반 L3 HA 실습 (같은 서브넷 2노드) | AWS |

### 앱 연동 / 코드형 배포
| 디렉토리 | 목적 |
|---------|------|
| `08-app-integration/` | Flask OIDC Authorization Code Flow 데모. JWT를 직접 디코딩해 Role을 읽는 학습용 |
| `08-kc-as-code/` | `deploy.py`로 realm JSON을 환경별(dev/stg/prod) Import. "Keycloak as Code" 패턴 |

### 문서
- `docs/챕터-1~10.md`, `docs/용어집.md`: IAM 개념부터 단계별 학습 자료
- `정리.md`: AuthN/AuthZ → RBAC → SSO → OAuth2 → OIDC 발전사 요약
- `keyclock_plan/`: 실제 고객사 대응 체크리스트·문의 정리

## terraform/ 의 핵심 아키텍처

`terraform/`는 **하나의 Keycloak Realm 위에 시나리오별 설정을 얹는 구조**다. 파일이 곧 "고객사 요청 시나리오" 단위로 분리되어 있다.

- `keycloak.tf` — 모든 것의 기반인 `keycloak_realm.ezl`. 비밀번호 정책·세션·브루트포스 방어 값을 `local.*`로 참조한다. **나머지 `keycloak-XX-*.tf`가 모두 이 realm을 참조하므로 가장 먼저 생성되어야 한다.**
- `keycloak-01-client.tf` ~ `keycloak-09-service-account.tf` — 신규 앱 SSO, 조직도(부서/팀/권한), LDAP/AD 연동, 비밀번호/세션 정책, MFA, 커스텀 클레임, 소셜 로그인, 서비스 계정(Client Credentials) 시나리오. 정책 값들은 각 파일의 `locals` 블록에 모여 있고 `keycloak.tf`가 끌어다 쓴다.
- 고객사 요청 → 어떤 파일을 고치는지, 자주 나는 오류, output으로 client secret 뽑는 법 등은 **`terraform/CHEATSHEET.md`** 가 현장 작업 가이드다. 작업 전 먼저 읽을 것.

> 주의: `CHEATSHEET.md`에는 `terraform apply` 배포 순서가 적혀 있지만, 위 "절대 규칙"에 따라 이 저장소에서는 `plan`까지만 한다.

## 주요 명령어

```bash
# ── Docker 로컬 실습 ──────────────────────────────
cd 01-single-node && docker compose up -d   # 단일 노드 기동
# Admin Console: http://localhost:8080  (admin / admin_password)
docker compose logs -f keycloak              # 로그 확인
docker compose down                          # 종료 (-v 붙이면 DB 볼륨까지 삭제)

cd 03-ha-cluster && docker compose up -d     # HA 클러스터 (nginx LB: :8085)

# ── Terraform (apply 금지, plan까지만) ────────────
cd terraform && terraform init
terraform plan                               # 변경 확인 — 여기까지만
terraform output hr_portal_oidc_info         # 개발자 전달용 OIDC 정보
terraform state show keycloak_realm.ezl      # 리소스 상태 확인

# ── Keycloak as Code (realm JSON 배포) ────────────
cd 08-kc-as-code
python3 deploy.py --env dev --dry-run        # 변환 결과만 확인 (배포 X)
python3 deploy.py --env dev                  # 로컬 dev로 realm import

# ── Flask OIDC 데모 ───────────────────────────────
cd 08-app-integration && python3 app.py      # http://localhost:5001
```

## 환경

- Keycloak 26.6.1 (Quarkus 기반). 26.x부터 헬스체크가 관리 포트 **9000** 으로 분리됨 (`/health/ready`)
- PostgreSQL (실습 15, README상 권장 18) — h2 인메모리는 재시작 시 데이터 소실되므로 사용 금지
- Java 21 (Keycloak 26.x 요구사항)
- Terraform >= 1.14, Keycloak Provider 5.7.0, AWS Provider ~> 6.43
