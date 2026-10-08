from datetime import datetime

def current_date_str() -> str:
    return datetime.now().strftime("%Y-%m-%d")