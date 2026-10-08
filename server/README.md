# SmartLedgerTest

轻量级账单解析与存储服务，基于 FastAPI 构建，支持多种 OCR 和大模型解析方案，实现图片账单的智能识别、结构化提取和数据持久化存储。

## 主要功能

- **多引擎解析**：支持 Qwen-VL 多模态模型直接解析图片，以及百度 OCR + Qwen 文本模型的组合方案
- **自动结构化**：提取账单的类别、金额、日期和描述信息
- **数据持久化**：使用 SQLite3 数据库存储解析结果
- **用户管理**：独立的用户信息存储系统，支持用户注册、登录验证、密码加密等功能
- **Token 鉴权**：登录后生成有效期30天的token，用于API接口身份验证
- **RESTful API**：提供简洁易用的 HTTP 接口
- **灵活配置**：通过 `apis.json` 集中管理第三方服务配置，通过环境变量管理数据库配置

## 项目结构

```
├── interface/
│   └── app.py            # FastAPI 路由定义
├── services/
│   ├── qwen.py           # Qwen-VL 模型封装（从 apis.json 读取 VLLM 配置）
│   ├── baidu_qwen.py     # 百度 OCR + Qwen 文本模型封装（需要 baidu_access_token 环境变量）
│   └── llm.py            # 通用 LLM（Qwen3-VL 兼容 OpenAI SDK）封装（从 apis.json 读取 LLM 配置）
├── bills/
│   ├── db.py             # 数据库操作模块（SQLite3，包含账单和用户管理）
│   └── view_db.py        # 账单数据查看工具
├── tools/
│   └── baidu_token.py    # 百度 API token 管理
├── uploads/
│   └── test_bill.jpg     # 示例图片
├── config.py             # 配置管理模块
├── apis.json             # API 服务注册表（包含各模型的 base_url 和密钥）
├── requirements.txt      # Python 依赖
├── setup_env.sh          # 环境配置脚本
├── start_server.sh       # 服务启动脚本
└── kill_server.sh        # 终止服务器示例脚本
```

## 快速开始

### 1. 环境准备

创建并激活虚拟环境，安装依赖：

```bash
bash setup_env.sh
source venv/bin/activate
```

或者手动安装：

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn openai python-dotenv requests
```

### 2. 配置数据库

创建 `.env` 文件（或使用 `setup_env.sh` 自动生成），配置 SQLite 数据库路径（可选）：

```bash
# SQLite数据库配置（可选，默认为 bills/bills.db）
DB_FILE="bills/bills.db"

# 密码加密盐值（可选）
PASSWORD_SALT="your_custom_salt"

# 服务配置
UVICORN_HOST="0.0.0.0"
UVICORN_PORT="8000"
```

### 3. 配置 API 密钥

编辑 `apis.json` 文件，按照实际使用的服务名称配置密钥（服务端直接从该文件读取，不依赖环境变量）：

```json
{
  "VLLM": {
    "type": "qwen-vl",
    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
    "key_env": "你的 Qwen-VL API 密钥"
  },
  "QWEN_TURBO": {
    "type": "qwen-text",
    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
    "key_env": "你的 Qwen 文本模型密钥"
  },
  "LLM": {
    "type": "qwen-vl",
    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
    "key_env": "你的通用 LLM（Qwen3-VL）密钥"
  },
  "BAIDU": {
    "type": "baidu-ocr",
    "auth": {
      "api_key": "你的百度 API Key",
      "secret_key": "你的百度 Secret Key"
    },
    "token": {
      "access_token": "你的百度 access_token",
      "expires_at": 0,
      "fetched_at": 0
    }
  }
}
```

说明：
- `services/qwen.py` 使用 `VLLM` 配置（interface/app.py:334-381 调用）。
- `services/llm.py` 使用 `LLM` 配置（interface/app.py:433-476 调用）。
- `services/baidu_qwen.py` 的解析依赖环境变量 `baidu_access_token`（由 `start_server.sh` 从 `apis.json.BAIDU.token.access_token` 加载）。

### 4. 初始化数据库

```bash
python3 -c "from bills import db; db.init_db(); print('数据库初始化完成')"
```

### 5. 启动服务

**推荐方式**（使用启动脚本）：

```bash
bash start_server.sh
```

该脚本会自动：
- 激活虚拟环境
- 从 `apis.json` 读取配置并设置环境变量
- 获取百度 API access_token（如果过期会自动刷新）
- 启动 FastAPI 服务

**手动启动方式**：

```bash
source venv/bin/activate
# 从 apis.json 设置环境变量（需要 jq 工具）
# 或手动设置：export DASHSCOPE_API_KEY="your_key"
uvicorn interface.app:app --host 0.0.0.0 --port 8000 --reload
```

服务启动后会：
- 自动初始化数据库（如果尚未创建）
- 从 `apis.json` 读取配置并设置环境变量（`DASHSCOPE_API_KEY`、`qwen_turbo_key`、`baidu_access_token`）；其中服务端解析模型直接读取 `apis.json` 的密钥字段，百度 OCR 需要 `baidu_access_token` 环境变量
- 为百度 API 获取访问令牌（有效期 30 天，自动写入 `apis.json`）

### 6. 接口统一说明

系统中的解析服务分为：

- **图片类解析**（Qwen-VL、百度 OCR+Qwen）：提供 `parse_bill_base64(base64_image)` 与 `parse_bill_file(path)` 两种入口。
- **文本类解析**（通用 LLM Qwen3-VL）：提供 `parse_bill_text(text)` 入口。

所有服务统一返回 JSON 结构：`category`（明细类别）、`amount`（金额，字符串，两位小数）、`date`（日期）、`description`（描述）、`nw_type`（基础支出/娱乐支出）。`nw_type` 由模型自行判断，服务端不做映射推断。

**新分类标准**：
- 明细类别 categories：餐饮、购物、交通、住房、休闲娱乐、医疗健康、学习办公、宠物、母婴、资金往来、保险理财、其他支出
- 预算类别 nw_type：基础支出/娱乐支出（平行标准）。由模型根据账单语义自行判断（如住房、交通、医疗、账单水电等通常归为基础支出；餐饮、购物、旅行、娱乐、爱好等通常归为娱乐支出）。

## API 接口

### 健康检查
- **GET /ping** - 验证服务是否正常运行
  - 返回：`{"status": "ok", "message": "Cloud Bill Agent running"}`

### 用户管理

#### 用户注册
- **POST /register** - 用户注册
  - 请求体（JSON）：
    ```json
    {
      "email": "user@example.com",
      "password": "password123",
      "user_id": "optional_custom_id"  // 可选，不提供则自动生成UUID
    }
    ```
  - 返回：
    ```json
    {
      "status": "ok",
      "message": "用户注册成功",
      "user": {
        "user_id": "uuid-or-custom-id",
        "email": "user@example.com",
        "created_at": "2024-01-15 10:30:00"
      }
    }
    ```
  - 错误响应：
    - `400`: 邮箱已存在等业务错误
    - `500`: 服务器内部错误
  - **注意**：格式验证（如密码长度、邮箱格式等）由前端处理，后端不做格式检查

#### 用户登录
- **POST /login** - 用户登录
  - 请求体（JSON）：
    ```json
    {
      "email": "user@example.com",
      "password": "password123"
    }
    ```
  - 返回：
    ```json
    {
      "status": "ok",
      "message": "登录成功",
      "user": {
        "user_id": "uuid-or-custom-id",
        "email": "user@example.com",
        "created_at": "2024-01-15 10:30:00",
        "updated_at": "2024-01-15 10:30:00",
        "token": "生成的token字符串"
      }
    }
    ```
  - **Token说明**：
    - 登录成功后会生成一个token，有效期30天
    - Token会自动保存到数据库，如果用户已有token则会被覆盖
    - Token用于后续API接口的身份验证
  - 错误响应：
    - `401`: 邮箱或密码错误
    - `500`: 服务器内部错误

#### Token验证
- **GET /verify_token** - 验证token是否有效
  - 查询参数：
    - `token` (必填): 要验证的token字符串
  - 返回：
    ```json
    {
      "status": "ok",
      "valid": true,
      "message": "Token有效",
      "expires_at": "2024-02-15 10:30:00"
    }
    ```
    或（token无效时）：
    ```json
    {
      "status": "ok",
      "valid": false,
      "message": "Token无效或已过期"
    }
    ```
  - 错误响应：
    - `500`: 服务器内部错误

### 账单管理

#### 手动上传账单
- **POST /manual_bill** - 手动上传记账数据
  - 请求体（JSON）：
    ```json
    {
      "user_id": "user_id_here",
      "bill": {
        "bill_id": "user_id-20240115-103045123456",
        "category": "购物",
        "amount": "123.45",
        "date": "2024-01-15",
        "description": "购买商品描述",
        "nw_type": "娱乐支出"
      }
    }
    ```
  - 参数说明：
    - `user_id`: 用户ID（必填）
    - `bill`: 账单数据对象
      - `category`: 明细类别（必填，从新的类别列表中选择）
      - `amount`: 金额（必填），可为字符串或数字；内部存库为浮点数并保留两位小数，推荐传入字符串格式（如 "123.45"）
      - `bill_id`: 账单唯一编号（必填，由调用方生成并保证唯一性）
      - `date`: 日期（可选，格式：YYYY-MM-DD，不提供则使用当前日期）
      - `description`: 描述（可选，默认为空字符串）
      - `nw_type`: 预算类别（可选，基础支出/娱乐支出；服务端不推断，留空或由客户端/模型判断）
  - 返回：
    ```json
    {
      "status": "ok",
      "message": "账单保存成功",
      "bill_id": "user_id-20240115-103045123456"
    }
    ```
  - 错误响应：
    - `400`: 参数验证失败（类别为空、金额无效、日期格式错误等）
    - `500`: 服务器内部错误

- **POST /delete_bill** - 删除已保存的账单
  - 请求体（JSON）：
  ```json
  {
    "token": "用户登录获取的token",
    "bill_id": "user_id-20240115-103045123456"
  }
  ```
  - 行为说明：
    - 验证 token 是否有效
    - 仅允许删除该 token 所属用户的账单
  - 返回：
  ```json
  {
    "status": "ok",
    "message": "账单删除成功"
  }
  ```
  - 错误响应：
    - `401`: Token无效或已过期
    - `403`: 无权限删除该账单
    - `404`: 账单不存在
    - `500`: 服务器内部错误

### 账单解析

**注意**：以下两个上传接口都需要提供有效的token进行身份验证。

- **POST /upload_qwen_vl** - 使用 Qwen-VL 多模态模型解析账单图片
  - 参数（multipart/form-data）：
    - `file` (必填): 账单图片文件
    - `token` (必填): 用户登录时获取的token
    - `bill_id` (必填): 账单唯一编号，由调用方生成并保证唯一性
  - 返回：
    ```json
    {
      "status": "ok",
      "result": {
        "category": "购物",
        "amount": "123.45",
        "date": "2024-01-15",
        "description": "购买商品描述",
        "nw_type": "娱乐支出"
      }
    }
    ```
  - 错误响应：
    - `401`: Token无效或已过期
    - `500`: 服务器内部错误

- **POST /upload_baidu_qwen** - 使用百度 OCR + Qwen 文本模型解析账单图片
  - 参数（multipart/form-data）：
    - `file` (必填): 账单图片文件
    - `token` (必填): 用户登录时获取的token
    - `bill_id` (必填): 账单唯一编号，由调用方生成并保证唯一性
  - 返回：同上
  - 错误响应：
    - `401`: Token无效或已过期
    - `500`: 服务器内部错误

- **POST /upload_llm** - 使用通用 LLM（Qwen3-VL 兼容 OpenAI SDK）解析账单文本描述
  - 参数（multipart/form-data）：
    - `text` (必填): 账单自然语言描述（例如“今天午饭吃了10元的黄焖鸡米饭”）
    - `token` (必填): 用户登录时获取的token
    - `bill_id` (必填): 账单唯一编号，由调用方生成并保证唯一性
  - 返回：同上
  - 错误响应：
    - `401`: Token无效或已过期
    - `500`: 服务器内部错误

### API 文档
启动服务后，访问 `http://localhost:8000/docs` 查看交互式 API 文档。

### 测试 Token
开发环境可选开启一个万能 token，用于快速验证接口。**默认关闭**，需要通过环境变量显式开启：

```bash
export DEV_BYPASS_TOKEN="你自己指定的随机字符串"
```

开启后，携带该 token 调用接口即可跳过用户校验（见 `bills/db.py` 的 `verify_token`）。**生产环境切勿配置此项。**

## 数据库操作

### 数据库配置

项目使用 **SQLite3** 数据库存储账单和用户数据。通过环境变量配置数据库文件路径：

- `DB_FILE`: SQLite 数据库文件路径（默认：`bills/bills.db`）
- `PASSWORD_SALT`: 密码加密盐值（可选，默认：smartledger_default_salt）

**注意**：SQLite3 是 Python 标准库的一部分，无需额外安装。数据库文件会自动创建在指定路径。

### 表结构

#### 账单表 (bills)

```sql
CREATE TABLE bills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bill_id TEXT UNIQUE,
    user_id TEXT,
    category TEXT,
    amount REAL,
    date TEXT,
    description TEXT,
    nw_type TEXT
)
```

- `id`: 主键（自增）
- `bill_id`: 唯一账单编号（由调用方生成，需保证唯一性，推荐格式：userID-日期-时间戳）
- `user_id`: 用户标识符
- `category`: 账单类别
- `amount`: 金额（REAL 类型，保留两位小数）
- `date`: 日期（TEXT 类型）
- `description`: 描述信息
- `nw_type`: 预算类别（基础支出/娱乐支出）

#### 用户表 (users)

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    token TEXT,
    token_expires_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
)
```

- `id`: 主键（自增）
- `user_id`: 唯一用户ID（UUID格式，可自定义）
- `email`: 用户邮箱（唯一）
- `password_hash`: 加密后的密码（SHA-256加盐加密）
- `token`: 用户登录token（用于API身份验证）
- `token_expires_at`: token过期时间（格式：YYYY-MM-DD HH:MM:SS）
- `created_at`: 创建时间（TEXT 类型）
- `updated_at`: 更新时间（TEXT 类型，更新时手动设置）

**索引**：系统会自动创建 `idx_email` 和 `idx_user_id` 索引以优化查询性能。

### 查看数据库

#### 查看账单数据

使用 `bills/view_db.py` 查看账单数据：

```bash
python3 -m bills.view_db
# 或查看特定用户
python3 -c "from bills.view_db import print_bills; print_bills('user_id')"
```

#### 查看用户数据

使用 `bills/view_users.py` 查看用户数据：

```bash
python3 -m bills.view_users
# 或查看特定用户
python3 -c "from bills.view_users import print_user; print_user(email='user@example.com')"
python3 -c "from bills.view_users import print_user; print_user(user_id='user_id_here')"
```

### 用户管理操作

#### 创建用户

```python
from bills import db

# 创建用户（自动生成UUID）
user = db.create_user("user@example.com", "password123")
print(f"新用户ID: {user['user_id']}")

# 创建用户（自定义ID）
user = db.create_user("admin@example.com", "admin123", user_id="admin-001")
```

#### 查询用户

```python
from bills import db

# 根据邮箱查询
user = db.get_user_by_email("user@example.com")

# 根据用户ID查询
user = db.get_user_by_id("user_id_here")

# 获取所有用户
users = db.list_all_users()
```

#### 验证用户

```python
from bills import db

# 验证邮箱和密码
user = db.verify_user("user@example.com", "password123")
if user:
    print(f"登录成功，用户ID: {user['user_id']}")
```

#### 更新用户信息

```python
from bills import db

# 更新密码
db.update_user_password("user_id_here", "new_password")

# 更新邮箱
db.update_user_email("user_id_here", "new_email@example.com")
```

#### 删除用户

```python
from bills import db

# 删除用户（注意：不会删除该用户的账单记录）
db.delete_user("user_id_here")
```

## 工具和脚本

### `tools/baidu_token.py`
百度 API access_token 管理工具，自动从 `apis.json` 读取配置并获取 token：

```bash
python3 tools/baidu_token.py
```

Token 会自动写入 `apis.json` 的 `BAIDU.auth.access_token` 字段，并记录过期时间。

### `start_server.sh`
服务启动脚本，自动处理环境变量设置和 token 获取。

### `setup_env.sh`
环境初始化脚本，创建虚拟环境、安装依赖、配置 `.env` 文件。

## 注意事项

1. **安全建议**：
   - 请勿将 `apis.json` 文件提交到代码仓库，确保 API 密钥安全
   - 建议将 `apis.json` 添加到 `.gitignore`
   - `.env` 文件也应避免提交到代码仓库

2. **依赖问题**：
   - 如果遇到 multipart 错误，请安装 `python-multipart`：`pip install python-multipart`
   - 如果使用 `start_server.sh`，需要安装 `jq` 工具：`apt-get install jq` 或 `yum install jq`

3. **Token 管理**：
   - 百度 API token 会在服务启动时自动获取并写入 `apis.json`
   - Token 有效期 30 天，过期后会自动刷新
   - Token 存储在 `apis.json` 的 `BAIDU.auth.access_token` 字段

4. **环境变量**：
   - 服务会自动从 `apis.json` 读取配置并设置环境变量（`DASHSCOPE_API_KEY`、`qwen_turbo_key`、`baidu_access_token`）。对于 `LLM`，服务直接读取 `apis.json` 中的密钥（无需额外环境变量）。
   - 数据库配置通过 `.env` 文件或环境变量设置

5. **URL 配置**：
   - 各服务的基础 URL 已在代码中硬编码，无需手动配置
   - Qwen 服务：`https://dashscope.aliyuncs.com/compatible-mode/v1`
   - 百度 OCR：`https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic`

6. **错误处理**：
   - API 调用失败时会返回错误信息，便于调试
   - 数据库连接失败时会在启动阶段报错

7. **接口统一**：
   - Qwen-VL、通用 LLM（Qwen3-VL）和百度 OCR+Qwen 服务已实现接口统一，可互换使用
   - 所有服务使用相同的账单类别列表，确保数据一致性

8. **数据库**：
   - 项目使用 SQLite3 数据库，无需额外安装数据库服务器
   - 数据库文件存储在 `bills/bills.db`（可通过 `DB_FILE` 环境变量自定义）
   - SQLite3 是 Python 标准库，无需在 requirements.txt 中声明

9. **用户管理**：
   - 用户信息与账单数据分开存储，使用独立的 `users` 表
   - 密码使用 SHA-256 加盐加密存储，不会以明文形式保存
   - 用户ID支持自动生成（UUID）或自定义
   - 邮箱和用户ID都具有唯一性约束
   - 删除用户时不会删除该用户的账单记录，保持数据完整性

10. **Token鉴权**：
    - 用户登录成功后会自动生成token，有效期30天
    - Token存储在数据库的 `users` 表中
    - 如果用户已有token，登录时会覆盖旧的token
    - 上传账单图片的接口需要提供有效的token进行身份验证
    - Token过期后需要重新登录获取新token
    - 使用 `GET /verify_token` 接口可以验证token是否有效

## 系统流程图

```
客户端请求（带token）
    ↓
FastAPI 接口 (/upload_qwen_vl 或 /upload_baidu_qwen)
    ↓
Token验证（验证token有效性）
    ↓
┌───────────────┐    ┌───────────────┐
│ Qwen-VL 解析  │ 或 │ 百度 OCR 解析 │
│ 直接识别图片  │    │ → Qwen 结构化 │
└───────────────┘    └───────────────┘
            ↓
       结构化 JSON
    (category, amount, date, description)
            ↓
      SQLite3 存储
            ↓
      返回结果给客户端
```

### 认证流程

```
用户注册 → 用户登录 → 获取token（30天有效期）
    ↓
使用token调用API接口
    ↓
Token验证 → 验证通过 → 执行业务逻辑
    ↓
Token无效/过期 → 返回401错误 → 需要重新登录
```

## 扩展开发

如需扩展系统功能，可考虑以下方向：

- 添加更多账单解析引擎支持（如 GPT-4 Vision、Google Vision API 等）
- 开发前端界面提升用户体验
- 添加数据统计和分析功能（按类别、时间范围统计支出）
- 实现定时任务自动刷新 API 令牌
- 添加账单图片存储功能
- 实现账单导出功能（CSV、Excel 等）
- 添加账单分类机器学习模型训练
- 实现token刷新机制（无需重新登录即可延长token有效期）
- 添加多设备登录管理（同一用户多个token）
- 实现更细粒度的权限控制（如不同用户角色的访问权限）

## 技术栈

- **Web 框架**：FastAPI
- **ASGI 服务器**：Uvicorn
- **数据库**：SQLite3（Python 标准库）
- **OCR 服务**：百度 OCR API
- **大模型**：Qwen-VL（多模态）、Qwen-Turbo（文本）
- **API 客户端**：OpenAI SDK（兼容 DashScope）

## 许可证

MIT License