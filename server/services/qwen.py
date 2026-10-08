import os
import base64
import json
from pathlib import Path
from services.baidu_qwen import CATEGORIES
from tools.date_util import current_date_str

# Load API registry (simple data structure listing used APIs, their base_url and env var for key)
API_REGISTRY_PATH = Path(__file__).resolve().parents[1] / "apis.json"
try:
    with open(API_REGISTRY_PATH, "r", encoding="utf-8") as _f:
        API_REGISTRY = json.load(_f)
except Exception:
    API_REGISTRY = {}


def get_client(service: str = "VLLM"):
    """Return OpenAI-compatible client using LLM config from apis.json."""
    cfg = API_REGISTRY.get("VLLM") or {}
    # 直接使用key_env的值作为API key
    api_key = cfg.get("key_env")
    base_url = cfg.get("base_url") or "https://dashscope.aliyuncs.com/compatible-mode/v1 "
    if not api_key:
        raise RuntimeError(f"apis.json 未配置 {service} 的 key_env")
    try:
        from openai import OpenAI
    except Exception:
        raise RuntimeError("openai 包未安装，请安装 requirements.txt 中列出的依赖")
    return OpenAI(api_key=api_key, base_url=base_url)


def parse_bill_base64(base64_image: str):
    """接受 base64 字符串（不含 data:* 前缀），调用 Qwen-VL 解析并返回 dict 或原始文本。"""
    client = get_client("VLLM")

    prompt = [
        {
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"},
        },
        {
            "type": "text",
            "text": (
                f"解析账单并返回JSON，字段：category、amount、date、description、nw_type。"
                f"category 必须从 {CATEGORIES} 选择；"
                "amount 为字符串（单位元），保留两位小数且为正；"
                f"date 使用 20xx-xx-xx 格式，若原文未出现日期则使用今天（{current_date_str()}）；"
                "description 简洁自然语言；"
                "nw_type 为两类：'基础支出' 与 '娱乐支出'，请根据语义自行判断归类（例如：住房、交通、医疗、账单水电等通常为基础支出；餐饮、购物、旅行、娱乐、爱好等通常为娱乐支出），不要使用固定映射。"
            ),
        },
    ]

    completion = client.chat.completions.create(
        model="qwen3-vl-plus", messages=[{"role": "user", "content": prompt}]
    )

    qwen_output = completion.choices[0].message.content
    try:
        return json.loads(qwen_output)
    except Exception:
        return {"raw": qwen_output}


def parse_bill_file(path: str):
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")
    return parse_bill_base64(b64)