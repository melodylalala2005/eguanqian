import json
from pathlib import Path

from services.baidu_qwen import CATEGORIES
from tools.date_util import current_date_str


API_REGISTRY_PATH = Path(__file__).resolve().parents[1] / "apis.json"
try:
    with open(API_REGISTRY_PATH, "r", encoding="utf-8") as _f:
        API_REGISTRY = json.load(_f)
except Exception:
    API_REGISTRY = {}


def get_client():
    """Return OpenAI-compatible client using LLM config from apis.json."""
    cfg = API_REGISTRY.get("LLM") or {}
    api_key = cfg.get("key_env")
    base_url = cfg.get("base_url") or "https://dashscope.aliyuncs.com/compatible-mode/v1"
    if not api_key:
        raise RuntimeError("apis.json 未配置 LLM 的 key_env")
    try:
        from openai import OpenAI
    except Exception:
        raise RuntimeError("openai 包未安装，请安装 requirements.txt 中列出的依赖")
    return OpenAI(api_key=api_key, base_url=base_url)


def parse_bill_text(text: str):
    """接受自然语言账单描述，返回统一账单结构。"""
    if not text or not text.strip():
        raise ValueError("待解析的账单描述不能为空")

    client = get_client()
    messages = [
        {
            "role": "system",
            "content": (
                "仅返回 JSON 对象，包含 category、amount、date、description、nw_type。"
                f"category 必须从 {CATEGORIES} 选择；"
                "amount 为字符串（单位元），保留两位小数且为正；"
                f"date 使用 20xx-xx-xx 格式，如果原文未出现日期则使用今天（{current_date_str()}）；"
                "description 保持简洁自然语言；"
                "nw_type 为两类：'基础支出' 与 '娱乐支出'，请根据语义自行判断归类（例如：住房、交通、医疗、账单水电等通常为基础支出；餐饮、购物、旅行、娱乐、爱好等通常为娱乐支出），不要使用固定映射。"
            ),
        },
        {
            "role": "user",
            "content": f"解析这条账单描述：{text}",
        },
    ]
    completion = client.chat.completions.create(
        model="qwen3-vl-32b-instruct",
        response_format={"type": "json_object"},
        messages=messages,
    )
    content = completion.choices[0].message.content
    try:
        data = json.loads(content)
    except Exception:
        data = {"raw": content}
    return data


