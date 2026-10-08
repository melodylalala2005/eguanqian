from typing import Optional
from .db import get_bills


def print_bills(user_id: Optional[str] = None):
    bills = get_bills(user_id)
    if not bills:
        print("没有找到账单数据。")
        return
    for row in bills:
        print(f"ID: {row['bill_id']}, 用户: {row['user_id']}, 类别: {row['category']}, 金额: {row['amount']}, 日期: {row['date']}, 描述: {row['description']}")


if __name__ == "__main__":
    # 查看全部账单
    print("=== 全部账单 ===")
    print_bills()

    # 如果想按用户筛选，可改为：
    # print_bills("alice")
