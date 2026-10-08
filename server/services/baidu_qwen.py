#!/usr/bin/env python3
import os
import base64
import json

CATEGORIES = [
    "餐饮",
    "购物",
    "交通",
    "住房",
    "休闲娱乐",
    "医疗健康",
    "学习办公",
    "宠物",
    "母婴",
    "资金往来",
    "保险理财",
    "其他支出",
]

def get_baidu_access_token():
    """直接从环境变量获取百度access_token。"""
    access_token = os.environ.get("baidu_access_token")
    if not access_token:
        raise RuntimeError("环境变量 baidu_access_token 未设置，请确保服务启动时已正确设置")
    return access_token


def baidu_ocr_from_path(path: str) -> str:
    """调用百度 OCR，返回拼接后的文本结果（多行）。"""
    # 直接硬编码百度OCR的基础URL
    BAIDU_OCR_BASE_URL = "https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic"
    
    token = get_baidu_access_token()
    url = f"{BAIDU_OCR_BASE_URL}?access_token={token}"
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    import requests
    resp = requests.post(
        url,
        data={"image": b64},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        verify=False,
    )
    resp.raise_for_status()
    data = resp.json()
    words = [w.get("words", "") for w in data.get("words_result", [])]
    return "\n".join(words)


def baidu_ocr_from_base64(base64_image: str) -> str:
    """调用百度 OCR，从base64字符串返回拼接后的文本结果（多行）。"""
    # 直接硬编码百度OCR的基础URL
    BAIDU_OCR_BASE_URL = "https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic"
    
    token = get_baidu_access_token()
    url = f"{BAIDU_OCR_BASE_URL}?access_token={token}"
    import requests
    resp = requests.post(
        url,
        data={"image": base64_image},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        verify=False,
    )
    resp.raise_for_status()
    data = resp.json()
    words = [w.get("words", "") for w in data.get("words_result", [])]
    return "\n".join(words)


def qwen_struct(text: str) -> dict:
    """使用项目中的 Qwen 文本模型（通过 services.qwen.get_client）将 OCR 文本解析为结构化 JSON。"""
    try:
        from services.qwen import get_client
        from tools.date_util import current_date_str
    except Exception:
        raise RuntimeError("无法导入 services.qwen.get_client，请确保 services/qwen.py 可用")

    client = get_client(service="QWEN_TURBO")
    completion = client.chat.completions.create(
        model="qwen-turbo",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": "仅返回 JSON 对象"},
            {"role": "user", "content": (
                f"解析账单并返回JSON，字段：category、amount、date、description、nw_type。"\
                f"category 必须从 {CATEGORIES} 选择；"\
                f"amount 为字符串（单位元），保留两位小数且为正；"\
                f"date 使用 20xx-xx-xx 格式，若原文未出现日期则使用今天（{current_date_str()}）；"\
                f"description 简洁自然语言；"\
                f"nw_type 为两类：'基础支出' 与 '娱乐支出'，请根据语义自行判断归类（例如：住房、交通、医疗、账单水电以及金额较低的正餐等通常为基础支出；相对高价餐饮、零食奶茶以及购物、旅行、娱乐、爱好等通常为娱乐支出），不要使用固定映射。\n{text}"
            )},
        ],
    )
    content = completion.choices[0].message.content
    try:
        return json.loads(content)
    except Exception:
        return {"raw": content}





def parse_bill_base64(base64_image: str):
    """接受 base64 字符串（不含 data:* 前缀），调用百度OCR和Qwen解析并返回 dict 或原始文本。"""
    txt = baidu_ocr_from_base64(base64_image)
    return qwen_struct(txt)


def parse_bill_file(path: str) -> dict:
    """从文件路径读取图片并返回结构化解析结果（dict）。"""
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")
    return parse_bill_base64(b64)


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("用法: python services/baidu_qwen.py <图片路径>")
        raise SystemExit(1)
    print(json.dumps(parse_bill_file(sys.argv[1]), ensure_ascii=False, indent=2))
