# Keycloak 바이너리 설치 가이드

## 전제 조건

- OS: RHEL/CentOS/Rocky/Amazon Linux 계열 (rpm 기반) 또는 Debian/Ubuntu (deb 기반)
- Java 25 LTS 필수 (Keycloak 26.x 공식 권장 버전)
- 인터넷 차단 환경 가정 → 파일 사전 다운로드 필요

---

## 설치 순서

### 1단계 — Java 25 설치

**RHEL 계열 (Amazon Linux 2023 포함)**
```bash
dnf install -y java-25-amazon-corretto-headless
# 또는
dnf install -y java-25-openjdk-headless
```

**Debian/Ubuntu 계열**
```bash
apt-get install -y openjdk-25-jdk-headless
```

**설치 확인**
```bash
java -version
# openjdk version "25.x.x" 나오면 OK
```

---

### 2단계 — Keycloak 바이너리 다운로드

**인터넷 되는 환경에서 미리 받아두기**
```bash
KC_VERSION="26.6.1"
wget https://github.com/keycloak/keycloak/releases/download/${KC_VERSION}/keycloak-${KC_VERSION}.tar.gz
```

**폐쇄망이면 USB/내부 저장소로 전달 후:**
```bash
tar -xzf keycloak-26.6.1.tar.gz -C /opt
mv /opt/keycloak-26.6.1 /opt/keycloak
```

---

### 3단계 — 전용 계정 생성

```bash
useradd -r -s /sbin/nologin keycloak
chown -R keycloak:keycloak /opt/keycloak
```

---

### 4단계 — keycloak.conf 작성

```bash
cat > /opt/keycloak/conf/keycloak.conf << 'EOF'
# DB 설정
db=postgres
db-url=jdbc:postgresql://10.112.0.43:5432/keycloak
db-username=keycloak
db-password=keycloak
db-pool-min-size=5
db-pool-max-size=40

# HTTP 설정 (Keepalived EIP 직접 접근, 앞단 프록시 없음)
http-enabled=true
http-port=8080

# 호스트명 — EIP로 직접 접근하므로 strict 비활성화
# proxy-headers는 앞단 프록시가 있을 때만 사용, 여기선 불필요
hostname-strict=false

# 캐시 (HA 2노드) — jdbc-ping이 기본값이므로 cache-stack 생략 가능
cache=ispn

# 로그
log=console
log-level=INFO

# 헬스체크
health-enabled=true
EOF
```

---

### 5단계 — 빌드 (최초 1회)

```bash
/opt/keycloak/bin/kc.sh build
```

> 빌드는 설정이 바뀔 때마다 다시 해야 함
> DB 드라이버, 캐시 프로바이더 등을 바이너리에 굽는 단계
> 빌드 완료 후에는 반드시 `start --optimized`로 기동해야 빌드 결과물을 사용함

---

### 6단계 — systemd 서비스 등록

```bash
cat > /etc/systemd/system/keycloak.service << 'EOF'
[Unit]
Description=Keycloak Identity Provider
After=network.target

[Service]
User=keycloak
Group=keycloak
# 26.x부터 KEYCLOAK_ADMIN → KC_BOOTSTRAP_ADMIN_USERNAME/PASSWORD로 변경
Environment=KC_BOOTSTRAP_ADMIN_USERNAME=admin
Environment=KC_BOOTSTRAP_ADMIN_PASSWORD=Admin1234!
# --optimized: kc.sh build 결과물 사용 (매번 재빌드 방지)
ExecStart=/opt/keycloak/bin/kc.sh start --optimized
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable keycloak
systemctl start keycloak
```

---

### 7단계 — 기동 확인

```bash
# 서비스 상태
systemctl status keycloak

# 로그 실시간
journalctl -u keycloak -f

# 헬스체크 (관리 포트 9000)
curl http://localhost:9000/health/ready
```

---

## Keepalived + EIP 연동 (AWS 환경)

### 개념

```
클라이언트 → EIP(52.79.120.52) → 현재 MASTER 노드
                                   ↑
                          Keepalived가 EIP를 점유
                          노드 죽으면 → BACKUP이 EIP 인수
```

### AWS에서 VRRP 대신 EIP 이동 방식 사용하는 이유

AWS VPC는 멀티캐스트/브로드캐스트를 막아서 VRRP 가상 IP 방식이 동작 안 함.
대신 Keepalived의 notify_master 스크립트로 AWS CLI를 호출해 EIP를 이동시킴.

---

### 1단계 — Keepalived + AWS CLI 설치 (양쪽 노드 모두)

```bash
# Keepalived 설치
dnf install -y keepalived

# AWS CLI 설치 (EIP 이동에 필요)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# 설치 확인
keepalived --version
aws --version
```

---

### 2단계 — EIP 이동 스크립트 작성 (양쪽 노드 모두)

```bash
cat > /etc/keepalived/move-eip.sh << 'EOF'
#!/bin/bash
ALLOCATION_ID="eipalloc-01e777b2541fa76a4"

# IMDSv2 토큰 먼저 발급 후 메타데이터 조회
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/placement/region)

aws ec2 associate-address \
  --instance-id ${INSTANCE_ID} \
  --allocation-id ${ALLOCATION_ID} \
  --allow-reassociation \
  --region ${REGION}
EOF

chmod +x /etc/keepalived/move-eip.sh
```

---

### 3단계 — keepalived.conf 작성

**노드 1 (MASTER) — 10.112.0.43**

```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
vrrp_script chk_keycloak {
    script "curl -sf http://localhost:9000/health/ready"
    interval 5
    fall 2
    rise 2
}

vrrp_instance KEYCLOAK {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    unicast_src_ip 10.112.0.43
    unicast_peer {
        10.112.0.127
    }
    track_script {
        chk_keycloak
    }
    notify_master /etc/keepalived/move-eip.sh
}
EOF
```

**노드 2 (BACKUP) — 10.112.0.127**

```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
vrrp_script chk_keycloak {
    script "curl -sf http://localhost:9000/health/ready"
    interval 5
    fall 2
    rise 2
}

vrrp_instance KEYCLOAK {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90
    unicast_src_ip 10.112.0.127
    unicast_peer {
        10.112.0.43
    }
    track_script {
        chk_keycloak
    }
    notify_master /etc/keepalived/move-eip.sh
}
EOF
```

---

### 4단계 — Keepalived 기동 (양쪽 노드 모두)

```bash
systemctl enable keepalived
systemctl start keepalived
systemctl status keepalived
```

---

### 5단계 — 동작 확인

```bash
# 현재 EIP가 어느 노드에 붙어있는지 확인
aws ec2 describe-addresses \
  --allocation-ids eipalloc-01e777b2541fa76a4 \
  --query 'Addresses[0].PrivateIpAddress' \
  --output text

# Keepalived 상태 로그
journalctl -u keepalived -f
```

---

### 6단계 — 페일오버 테스트

```bash
# 노드 1에서 Keycloak 강제 중단
systemctl stop keycloak

# 노드 2 로그에서 MASTER 전환 확인
journalctl -u keepalived -f
# "Entering MASTER STATE" 메시지 확인

# EIP가 노드 2로 이동했는지 확인
aws ec2 describe-addresses \
  --allocation-ids eipalloc-01e777b2541fa76a4 \
  --query 'Addresses[0].PrivateIpAddress' \
  --output text
# 10.112.0.127 나오면 성공

# 노드 1 Keycloak 복구
systemctl start keycloak
```

---

## PostgreSQL 설치 (노드 1에만)

```bash
# RHEL 계열
dnf install -y postgresql-server postgresql
postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# DB/유저 생성
sudo -u postgres psql << 'SQL'
CREATE USER keycloak WITH PASSWORD 'keycloak';
CREATE DATABASE keycloak OWNER keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
SQL

# 외부 접속 허용 (노드 2에서 접근 가능하도록)
echo "host keycloak keycloak 10.112.0.0/24 md5" >> /var/lib/pgsql/data/pg_hba.conf
echo "listen_addresses = '*'" >> /var/lib/pgsql/data/postgresql.conf
systemctl restart postgresql
```

---

## 노드별 설치 체크리스트

| 항목 | 노드 1 | 노드 2 |
|------|--------|--------|
| Java 25 | ✅ | ✅ |
| Keycloak 바이너리 | ✅ | ✅ |
| keycloak.conf | ✅ | ✅ (db-url은 노드 1 IP 그대로) |
| kc.sh build | ✅ | ✅ |
| systemd 서비스 | ✅ | ✅ |
| PostgreSQL | ✅ | ❌ |
| Keepalived | ✅ (MASTER) | ✅ (BACKUP) |
| move-eip.sh | ✅ | ✅ |
