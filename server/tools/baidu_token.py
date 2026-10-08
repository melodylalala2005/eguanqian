from pathlib import Path
import time
import json
import os

ROOT = Path(__file__).resolve().parents[1]
API_REG_PATH = ROOT / "apis.json"


def _read_api_registry():
    try:
        with open(API_REG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _get_baidu_credentials_from_registry():
    """从 apis.json 的 BAIDU.auth 中直接读取 api_key 与 secret_key（不依赖环境变量）。"""
    reg = _read_api_registry()
    cfg = reg.get("BAIDU", {})
    auth = cfg.get("auth", {}) or {}
    api_key = auth.get("api_key") or auth.get("apiKey")
    secret = auth.get("secret_key") or auth.get("secretKey")
    return api_key, secret


def fetch_and_write_to_apis():
    """获取百度 access_token 并写入项目的 apis.json 文件下 BAIDU.auth.access_token。

    返回写入后的 token 字符串。
    """
    api_reg = _read_api_registry()
    api_key, secret = _get_baidu_credentials_from_registry()
    if not api_key or not secret:
        raise ValueError("apis.json 中 BAIDU.auth 未配置 api_key 或 secret_key，无法获取 access_token")

    url = (
        "https://aip.baidubce.com/oauth/2.0/token"
        "?grant_type=client_credentials"
        f"&client_id={api_key}"
        f"&client_secret={secret}"
    )

    import requests
    r = requests.get(url, verify=False, timeout=10)
    r.raise_for_status()
    data = r.json()
    token = data.get("access_token")
    expires_in = int(data.get("expires_in", 0))
    if not token:
        raise RuntimeError("无法从百度返回 access_token: %s" % (data,))

    margin = 60
    expires_at = int(time.time()) + max(0, expires_in - margin)
    token_obj = {
        "access_token": token,
        "expires_at": expires_at,
        "fetched_at": int(time.time()),
    }

    bd = api_reg.get("BAIDU", {})
    auth = bd.get("auth", {}) or {}
    # 将 access_token 写入到 BAIDU.auth.access_token，并记录过期/获取时间
    auth["access_token"] = token_obj["access_token"]
    auth["expires_at"] = token_obj["expires_at"]
    auth["fetched_at"] = token_obj["fetched_at"]
    bd["auth"] = auth
    api_reg["BAIDU"] = bd

    with open(API_REG_PATH, "w", encoding="utf-8") as f:
        json.dump(api_reg, f, ensure_ascii=False, indent=2)

    return token


if __name__ == "__main__":
    print(fetch_and_write_to_apis())
