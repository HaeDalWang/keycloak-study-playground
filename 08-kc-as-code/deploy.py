#!/usr/bin/env python3
"""
Keycloak as Code - 환경별 Realm 배포 스크립트

사용법:
  python3 deploy.py --env dev    # 개발 환경
  python3 deploy.py --env stg    # 스테이징 환경
  python3 deploy.py --env prod   # 운영 환경
"""

import argparse
import copy
import json
import sys

import requests

# ── 환경별 설정 ────────────────────────────────────────────────
ENVIRONMENTS = {
    "dev": {
        "keycloak_url":   "http://localhost:8080",
        "admin_user":     "admin",
        "admin_password": "admin_password",
        "app_base_url":   "http://localhost:5001",
    },
    "stg": {
        "keycloak_url":   "https://auth-stg.jtbc.co.kr",
        "admin_user":     "admin",
        "admin_password": "CHANGE_ME",
        "app_base_url":   "https://app-stg.jtbc.co.kr",
    },
    "prod": {
        "keycloak_url":   "https://auth.jtbc.co.kr",
        "admin_user":     "admin",
        "admin_password": "CHANGE_ME",
        "app_base_url":   "https://app.jtbc.co.kr",
    },
}

# ── 환경별로 달라지는 Client 설정 ──────────────────────────────
CLIENT_OVERRIDES = {
    "hr-system": {
        "redirectUris": ["{app_base_url}/callback", "{app_base_url}/*"],
        "webOrigins":   ["{app_base_url}"],
    }
}


def get_admin_token(env_config: dict) -> str:
    resp = requests.post(
        f"{env_config['keycloak_url']}/realms/master/protocol/openid-connect/token",
        data={
            "grant_type": "password",
            "client_id":  "admin-cli",
            "username":   env_config["admin_user"],
            "password":   env_config["admin_password"],
        }
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def apply_env_overrides(realm_json: dict, env_config: dict) -> dict:
    """환경별 URL을 Realm JSON에 적용"""
    result = copy.deepcopy(realm_json)
    base_url = env_config["app_base_url"]

    for client in result.get("clients", []):
        client_id = client.get("clientId")
        if client_id in CLIENT_OVERRIDES:
            overrides = CLIENT_OVERRIDES[client_id]
            for key, value in overrides.items():
                if isinstance(value, list):
                    client[key] = [v.format(app_base_url=base_url) for v in value]
                else:
                    client[key] = value.format(app_base_url=base_url)
            print(f"  [{client_id}] redirectUris → {client.get('redirectUris')}")

    return result


def import_realm(realm_json: dict, env_config: dict, token: str):
    """Realm Import (없으면 생성, 있으면 업데이트)"""
    realm_name = realm_json["realm"]
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    base_url = env_config["keycloak_url"]

    # Realm 존재 여부 확인
    check = requests.get(f"{base_url}/admin/realms/{realm_name}", headers=headers)

    if check.status_code == 404:
        # 신규 생성
        resp = requests.post(f"{base_url}/admin/realms", headers=headers, json=realm_json)
        resp.raise_for_status()
        print(f"  Realm '{realm_name}' 신규 생성 완료")
    else:
        # 기존 업데이트 (PUT)
        resp = requests.put(
            f"{base_url}/admin/realms/{realm_name}",
            headers=headers,
            json=realm_json
        )
        resp.raise_for_status()
        print(f"  Realm '{realm_name}' 업데이트 완료")


def main():
    parser = argparse.ArgumentParser(description="Keycloak Realm 배포")
    parser.add_argument("--env", choices=["dev", "stg", "prod"], required=True)
    parser.add_argument("--realm-file", default="jtbc-realm.json")
    parser.add_argument("--dry-run", action="store_true", help="실제 배포 없이 변환 결과만 확인")
    args = parser.parse_args()

    env_config = ENVIRONMENTS[args.env]

    print(f"=== Keycloak as Code 배포: {args.env} 환경 ===")
    print(f"  대상: {env_config['keycloak_url']}")

    # Realm JSON 로드
    with open(args.realm_file) as f:
        realm_json = json.load(f)
    print(f"  Realm: {realm_json['realm']} ({len(realm_json.get('clients', []))}개 Client)")

    # 환경별 값 적용
    print("\n[1/3] 환경별 설정 적용 중...")
    patched = apply_env_overrides(realm_json, env_config)

    if args.dry_run:
        output_file = f"jtbc-realm-{args.env}.json"
        with open(output_file, "w") as f:
            json.dump(patched, f, indent=2, ensure_ascii=False)
        print(f"\n[dry-run] 변환 결과 저장: {output_file}")
        return

    # Admin 토큰 발급
    print("\n[2/3] Admin 토큰 발급 중...")
    try:
        token = get_admin_token(env_config)
        print("  토큰 발급 성공")
    except Exception as e:
        print(f"  토큰 발급 실패: {e}")
        sys.exit(1)

    # Realm Import
    print("\n[3/3] Realm Import 중...")
    try:
        import_realm(patched, env_config, token)
    except Exception as e:
        print(f"  Import 실패: {e}")
        sys.exit(1)

    print(f"\n배포 완료: {args.env} 환경")


if __name__ == "__main__":
    main()
