# Keycloak HA — PostgreSQL repmgr 레퍼런스 구성

> ⚠️ **이 디렉토리는 "그대로 실행되는" 구성이 아니라 레퍼런스(비교 학습용)다.**
> `bitnami/postgresql-repmgr` 무료 이미지가 살아있던 시절이라면 PostgreSQL HA를
> 얼마나 단순하게 구성할 수 있었는지를 보여주기 위한 자료다.
> 실제로 돌릴 수 있는 구성은 옆 디렉토리 [`../Keyclaok_Config_dbHA`](../Keyclaok_Config_dbHA)
> (공식 postgres 이미지 + 수동 스트리밍 복제)를 쓴다.

---

## 이미지 현황 (2026-06 기준, 검증됨)

| 이미지 | 상태 | 비고 |
|--------|------|------|
| `bitnami/postgresql-repmgr` | ❌ **무료 제공 종료** | 2025-08-28 Broadcom 정책. 유료 Bitnami Secure Images 구독 필요 |
| `bitnamilegacy/postgresql-repmgr` | ⚠️ 아카이브 | 업데이트 중단, PG 17까지, 보안 패치 없음 → 신규 사용 비권장 |

즉 이 디렉토리의 `image: bitnami/postgresql-repmgr:17` 은 **지금은 pull되지 않는다.**
정 테스트하려면 `bitnamilegacy/postgresql-repmgr:17.6.0` 으로 바꿔야 하지만, 미패치
이미지라 학습 외 용도로는 쓰지 말 것.

---

## 왜 이게 "편했는지" — 수동 버전과 비교

같은 2노드 HA를 두 방식으로 짰을 때 무엇이 사라지는지가 핵심이다.

| 항목 | 수동 스트리밍 복제 | repmgr (이 디렉토리) |
|------|------------------|---------------------|
| 복제 계정 / pg_hba 설정 | `init-primary.sh` 직접 작성 | ✅ 이미지가 자동 |
| Standby 초기화(basebackup) | `standby-entrypoint.sh` 직접 작성 | ✅ 이미지가 자동 |
| DB 승격(promote) | keepalived가 `pg_promote()` 호출 | ✅ `repmgrd`가 자동 |
| 죽은 노드 재가입 | **수동** `pg_basebackup` 재실행 | ✅ `repmgrd`가 자동 rejoin |
| stale 복귀 방지 | keepalived `nopreempt` 필요 | ✅ "primary 체크"로 자동 해결 |
| keepalived 역할 | VIP/EIP 이동 **+ DB 승격** | VIP/EIP 이동 **만** |

요약: repmgr 버전은 **DB의 상태 관리(승격/재가입)를 repmgrd가 전담**하고,
keepalived는 트래픽 경로(VIP/EIP)만 옮긴다. 역할이 깔끔하게 분리된다.

```
repmgrd     → 어느 DB가 Primary냐 (자동 failover · 승격 · rejoin)
keepalived  → 클라이언트가 어디로 접속하냐 (VIP/EIP 이동)
```

---

## 구성 파일

| 파일 | 역할 |
|------|------|
| `docker-compose.yml` | Node1 (최초 Primary) — postgres-repmgr + keycloak |
| `docker-compose2.yml` | Node2 (최초 Standby) — `REPMGR_NODE_NAME`만 다름 |
| `keycloak.conf` | DB 접속은 VIP(`10.10.0.100`) 기준 |
| `check-primary.sh` | keepalived용 "내가 primary인가" 판정 |
| `keepalived-node1.conf` / `node2.conf` | unicast VRRP, primary 따라 VIP 이동 |
| `keepalived-notify.sh` | VIP/EIP 이동 (※ `pg_promote` 없음) |

### IP 설계 (수동 버전과 동일)

| 항목 | 값(예시) | 용도 |
|------|---------|------|
| Node1 사설IP | `10.10.0.21` | 최초 Primary |
| Node2 사설IP | `10.10.0.22` | 최초 Standby |
| **DB VIP** | `10.10.0.100` | Keycloak이 접속하는 DB 주소 |
| Frontend EIP | (public) | 외부 접속, MASTER로 이동 |

---

## repmgr 버전 keepalived의 우아한 점

수동 버전은 `chk_db`(postgres 살아있나)로 체크하고, 죽었다 살아난 옛 Primary가
**낡은 데이터로 VIP를 도로 뺏는 걸** `nopreempt`로 막아야 했다.

repmgr 버전은 `check-primary.sh`로 **"내가 지금 primary인가"** 를 본다.

- repmgrd가 Node2를 새 Primary로 승격 → Node2의 `check-primary.sh`만 성공 → VIP가 Node2로
- 죽었던 Node1이 살아나면 repmgrd가 **standby로 재가입** → `check-primary.sh` 실패 → VIP 안 뺏음

VIP가 "노드 정체성"이 아니라 "primary 상태"를 따라가므로 stale 복귀가 **원천 차단**된다.
그래서 두 노드 priority가 같아도 되고 `nopreempt`도 필요 없다.

---

## 2노드 repmgr의 한계 (꼭 알 것)

repmgr 자동 failover(`repmgrd`)를 **witness 없이 2노드만** 쓰면 split-brain 위험이 있다.

```
Node1 ←── 네트워크 단절(노드는 살아있음) ──→ Node2
  │                                          │
  여전히 Primary로 동작              "Primary 죽었다" 오판 → 자신을 승격
                                     → 양쪽 다 Primary (데이터 분기)
```

제대로 막으려면 **witness 노드(3번째)** 가 필요하다. 이게 살아있는 모든 현대 HA
솔루션(Patroni+etcd, pg_auto_failover 등)이 3번째 노드를 요구하는 이유다.
repmgr이 인기였던 건 이 위험을 감수하고 2노드를 허용했기 때문이다.

---

## 정리

- 이 구성은 **돌리는 게 목적이 아니라 "비교해서 배우는 것"** 이 목적이다.
- 실제 실습은 옆의 수동 버전으로, 자동화가 필요하면 **pg_auto_failover**(MS 유지,
  repmgr의 정신적 후계자)나 **Patroni+etcd 3노드**로 간다.
- 폐쇄망이면 RDS를 못 쓰니 결국 Patroni류를 손으로 올려야 한다 → 수동 버전 실습이
  그대로 자산이 된다.
