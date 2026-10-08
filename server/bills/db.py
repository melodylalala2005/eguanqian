import os
import sqlite3
import hashlib
import uuid
import secrets
from typing import Optional, List, Dict
from datetime import datetime, timedelta

# SQLite配置
DB_FILE = os.getenv("DB_FILE", "bills/bills.db")


def get_db_connection():
    """获取SQLite数据库连接"""
    # 确保数据库文件目录存在
    db_dir = os.path.dirname(DB_FILE)
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)
    
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row  # 使返回的行可以像字典一样访问
    return conn

def init_db():
    """初始化 SQLite 数据库（包括账单表和用户表）"""
    conn = get_db_connection()
    try:
        c = conn.cursor()
        # 创建账单表
        c.execute('''
            CREATE TABLE IF NOT EXISTS bills (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                bill_id TEXT UNIQUE,
                user_id TEXT,
                category TEXT,
                amount REAL,
                date TEXT,
                description TEXT,
                nw_type TEXT
            )
        ''')
        # 创建用户表
        c.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                token TEXT,
                token_expires_at TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        # 如果表已存在但没有token字段，则添加字段
        try:
            c.execute('ALTER TABLE users ADD COLUMN token TEXT')
        except sqlite3.OperationalError:
            pass  # 字段已存在
        try:
            c.execute('ALTER TABLE users ADD COLUMN token_expires_at TEXT')
        except sqlite3.OperationalError:
            pass  # 字段已存在
        try:
            c.execute('ALTER TABLE bills ADD COLUMN nw_type TEXT')
        except sqlite3.OperationalError:
            pass
        # 创建索引
        c.execute('CREATE INDEX IF NOT EXISTS idx_email ON users(email)')
        c.execute('CREATE INDEX IF NOT EXISTS idx_user_id ON users(user_id)')
        conn.commit()
    finally:
        conn.close()


def save_bill(bill_data: Dict):
    """
    保存账单信息到 SQLite。
    bill_data 需要包含: user_id, category, amount, bill_id；
    date、description 可选。调用方必须提供 bill_id 并保证唯一。
    """
    conn = get_db_connection()
    try:
        user_id = bill_data.get("user_id", "anonymous")
        date_str = bill_data.get("date", datetime.now().strftime("%Y-%m-%d"))
        
        bill_id = bill_data.get("bill_id")
        if not bill_id:
            raise ValueError("bill_id 必须提供")
        
        c = conn.cursor()
        c.execute('''
            INSERT INTO bills (bill_id, user_id, category, amount, date, description, nw_type)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            bill_id,
            user_id,
            bill_data.get("category"),
            bill_data.get("amount"),
            date_str,
            bill_data.get("description", ""),
            bill_data.get("nw_type")
        ))
        conn.commit()
    finally:
        conn.close()


def get_bills(user_id: Optional[str] = None) -> List[Dict]:
    """按用户读取账单信息，如果 user_id 为 None，则返回全部账单"""
    conn = get_db_connection()
    try:
        c = conn.cursor()
        if user_id:
            c.execute("SELECT bill_id, user_id, category, amount, date, description, nw_type FROM bills WHERE user_id = ?", (user_id,))
        else:
            c.execute("SELECT bill_id, user_id, category, amount, date, description, nw_type FROM bills")
        # 将 Row 对象转换为字典
        rows = c.fetchall()
        bills = [dict(row) for row in rows]
        # 确保日期字段格式一致（转换为字符串）
        for bill in bills:
            if 'date' in bill and bill['date'] is not None:
                bill['date'] = str(bill['date'])
        return bills
    finally:
        conn.close()


def get_bill_by_id(bill_id: str) -> Optional[Dict]:
    """根据 bill_id 查询账单"""
    conn = get_db_connection()
    try:
        c = conn.cursor()
        c.execute(
            "SELECT bill_id, user_id, category, amount, date, description, nw_type FROM bills WHERE bill_id = ?",
            (bill_id,),
        )
        row = c.fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def delete_bill(bill_id: str) -> bool:
    """删除指定账单"""
    conn = get_db_connection()
    try:
        c = conn.cursor()
        c.execute("DELETE FROM bills WHERE bill_id = ?", (bill_id,))
        conn.commit()
        return c.rowcount > 0
    finally:
        conn.close()


# ==================== 用户管理函数 ====================

def _hash_password(password: str) -> str:
    """使用 SHA-256 加密密码（加盐）"""
    salt = os.getenv("PASSWORD_SALT", "smartledger_default_salt")
    return hashlib.sha256((password + salt).encode('utf-8')).hexdigest()


def generate_user_id() -> str:
    """生成唯一用户ID（UUID格式）"""
    return str(uuid.uuid4())


def generate_token() -> str:
    """生成安全的随机token（32字节，64个十六进制字符）"""
    return secrets.token_urlsafe(32)


def save_user_token(user_id: str, token: str, expires_in_days: int = 30) -> bool:
    """
    保存用户token到数据库
    
    Args:
        user_id: 用户唯一ID
        token: 生成的token
        expires_in_days: token有效期（天数），默认30天
    
    Returns:
        如果保存成功返回 True，如果用户不存在返回 False
    """
    conn = get_db_connection()
    try:
        expires_at = (datetime.now() + timedelta(days=expires_in_days)).strftime("%Y-%m-%d %H:%M:%S")
        updated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        c = conn.cursor()
        c.execute('''
            UPDATE users SET token = ?, token_expires_at = ?, updated_at = ? WHERE user_id = ?
        ''', (token, expires_at, updated_at, user_id))
        conn.commit()
        return c.rowcount > 0
    finally:
        conn.close()


def verify_token(token: str) -> Optional[Dict]:
    """
    验证token是否有效
    
    Args:
        token: 要验证的token
    
    Returns:
        如果token有效，返回用户信息字典（不包含密码和token）
        如果token无效或过期，返回 None
    """
    # 开发用万能 token，仅用于本地联调，必须通过环境变量显式开启。
    # 留空则禁用；生产环境切勿配置。默认关闭。
    DEV_BYPASS_TOKEN = os.getenv("DEV_BYPASS_TOKEN", "").strip()
    if DEV_BYPASS_TOKEN and token == DEV_BYPASS_TOKEN:
        return {
            "user_id": "token",
            "email": "token@test.com",
            "created_at": None,
            "updated_at": None,
            "token_valid": True,
            "token_expires_at": None
        }
    
    conn = get_db_connection()
    try:
        c = conn.cursor()
        c.execute('''
            SELECT user_id, email, token, token_expires_at, created_at, updated_at
            FROM users WHERE token = ?
        ''', (token,))
        row = c.fetchone()
        if row:
            result = dict(row)
            # 检查token是否过期
            token_expires_at = result.get('token_expires_at')
            if token_expires_at:
                try:
                    expires_at = datetime.strptime(token_expires_at, "%Y-%m-%d %H:%M:%S")
                    if datetime.now() > expires_at:
                        return None  # token已过期
                except ValueError:
                    return None  # 日期格式错误
            
            # 返回用户信息（不包含token和密码）
            return {
                "user_id": result.get("user_id"),
                "email": result.get("email"),
                "created_at": str(result.get("created_at")) if result.get("created_at") else None,
                "updated_at": str(result.get("updated_at")) if result.get("updated_at") else None,
                "token_valid": True,
                "token_expires_at": token_expires_at
            }
        return None
    finally:
        conn.close()


def create_user(email: str, password: str, user_id: Optional[str] = None) -> Dict:
    """
    创建新用户
    
    Args:
        email: 用户邮箱（必须唯一）
        password: 用户密码（明文，会自动加密存储）
        user_id: 可选的自定义用户ID，如果不提供则自动生成UUID
    
    Returns:
        包含用户信息的字典（不包含密码）
    
    Raises:
        ValueError: 如果邮箱已存在
    """
    conn = get_db_connection()
    try:
        c = conn.cursor()
        # 检查邮箱是否已存在
        c.execute("SELECT user_id FROM users WHERE email = ?", (email,))
        if c.fetchone():
            raise ValueError(f"邮箱 {email} 已被注册")
        
        # 生成用户ID 
        if not user_id:
            user_id = generate_user_id()
        else:
            # 检查用户ID是否已存在
            c.execute("SELECT user_id FROM users WHERE user_id = ?", (user_id,))
            if c.fetchone():
                raise ValueError(f"用户ID {user_id} 已存在")
        
        # 加密密码
        password_hash = _hash_password(password)
        created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # 插入新用户
        c.execute('''
            INSERT INTO users (user_id, email, password_hash, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (user_id, email, password_hash, created_at, created_at))
        conn.commit()
        
        return {
            "user_id": user_id,
            "email": email,
            "created_at": created_at
        }
    finally:
        conn.close()


def get_user_by_id(user_id: str) -> Optional[Dict]:
    """
    根据用户ID查询用户信息
    
    Args:
        user_id: 用户唯一ID
    
    Returns:
        用户信息字典（不包含密码），如果不存在则返回 None
    """
    conn = get_db_connection()
    try:
        c = conn.cursor()
        c.execute('''
            SELECT user_id, email, token, token_expires_at, created_at, updated_at
            FROM users WHERE user_id = ?
        ''', (user_id,))
        row = c.fetchone()
        if row:
            result = dict(row)
            # 确保日期字段格式一致
            if 'created_at' in result and result['created_at']:
                result['created_at'] = str(result['created_at'])
            if 'updated_at' in result and result['updated_at']:
                result['updated_at'] = str(result['updated_at'])
            return result
        return None
    finally:
        conn.close()


def get_user_by_email(email: str) -> Optional[Dict]:
    """
    根据邮箱查询用户信息
    
    Args:
        email: 用户邮箱
    
    Returns:
        用户信息字典（不包含密码），如果不存在则返回 None
    """
    conn = get_db_connection()
    try:
        c = conn.cursor()
        c.execute('''
            SELECT user_id, email, token, token_expires_at, created_at, updated_at
            FROM users WHERE email = ?
        ''', (email,))
        row = c.fetchone()
        if row:
            result = dict(row)
            # 确保日期字段格式一致
            if 'created_at' in result and result['created_at']:
                result['created_at'] = str(result['created_at'])
            if 'updated_at' in result and result['updated_at']:
                result['updated_at'] = str(result['updated_at'])
            return result
        return None
    finally:
        conn.close()


def verify_user(email: str, password: str) -> Optional[Dict]:
    """
    验证用户邮箱和密码
    
    Args:
        email: 用户邮箱
        password: 用户密码（明文）
    
    Returns:
        如果验证成功，返回用户信息字典（不包含密码）
        如果验证失败，返回 None
    """
    conn = get_db_connection()
    try:
        password_hash = _hash_password(password)
        c = conn.cursor()
        c.execute('''
            SELECT user_id, email, token, token_expires_at, created_at, updated_at
            FROM users WHERE email = ? AND password_hash = ?
        ''', (email, password_hash))
        row = c.fetchone()
        if row:
            result = dict(row)
            # 确保日期字段格式一致
            if 'created_at' in result and result['created_at']:
                result['created_at'] = str(result['created_at'])
            if 'updated_at' in result and result['updated_at']:
                result['updated_at'] = str(result['updated_at'])
            return result
        return None
    finally:
        conn.close()


def update_user_password(user_id: str, new_password: str) -> bool:
    """
    更新用户密码
    
    Args:
        user_id: 用户唯一ID
        new_password: 新密码（明文）
    
    Returns:
        如果更新成功返回 True，如果用户不存在返回 False
    """
    conn = get_db_connection()
    try:
        password_hash = _hash_password(new_password)
        updated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        c = conn.cursor()
        c.execute('''
            UPDATE users SET password_hash = ?, updated_at = ? WHERE user_id = ?
        ''', (password_hash, updated_at, user_id))
        conn.commit()
        return c.rowcount > 0
    finally:
        conn.close()


def update_user_email(user_id: str, new_email: str) -> bool:
    """
    更新用户邮箱
    
    Args:
        user_id: 用户唯一ID
        new_email: 新邮箱
    
    Returns:
        如果更新成功返回 True，如果用户不存在或新邮箱已被使用返回 False
    
    Raises:
        ValueError: 如果新邮箱已被其他用户使用
    """
    conn = get_db_connection()
    try:
        c = conn.cursor()
        # 检查新邮箱是否已被其他用户使用
        c.execute("SELECT user_id FROM users WHERE email = ? AND user_id != ?", (new_email, user_id))
        if c.fetchone():
            raise ValueError(f"邮箱 {new_email} 已被其他用户使用")
        
        updated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        c.execute('''
            UPDATE users SET email = ?, updated_at = ? WHERE user_id = ?
        ''', (new_email, updated_at, user_id))
        conn.commit()
        return c.rowcount > 0
    finally:
        conn.close()


def delete_user(user_id: str) -> bool:
    """
    删除用户（注意：不会删除该用户的账单记录）
    
    Args:
        user_id: 用户唯一ID
    
    Returns:
        如果删除成功返回 True，如果用户不存在返回 False
    """
    conn = get_db_connection()
    try:
        c = conn.cursor()
        c.execute("DELETE FROM users WHERE user_id = ?", (user_id,))
        conn.commit()
        return c.rowcount > 0
    finally:
        conn.close()


def list_all_users() -> List[Dict]:
    """
    获取所有用户列表（不包含密码）
    
    Returns:
        用户信息字典列表
    """
    conn = get_db_connection()
    try:
        c = conn.cursor()
        c.execute('''
            SELECT user_id, email, token, token_expires_at, created_at, updated_at
            FROM users ORDER BY created_at DESC
        ''')
        rows = c.fetchall()
        # 将 Row 对象转换为字典
        users = [dict(row) for row in rows]
        # 确保日期字段格式一致
        for user in users:
            if 'created_at' in user and user['created_at']:
                user['created_at'] = str(user['created_at'])
            if 'updated_at' in user and user['updated_at']:
                user['updated_at'] = str(user['updated_at'])
        return users
    finally:
        conn.close()
