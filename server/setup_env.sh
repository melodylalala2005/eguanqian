#!/bin/bash
# ===========================================
# 🚀 SmartLedger 环境初始化脚本
# 适用于 Ubuntu + Python 3.12 + venv 环境
# ===========================================

echo "📦 [1/6] 检查虚拟环境..."
if [ ! -d "venv" ]; then
    echo "🔧 创建虚拟环境..."
    python3 -m venv venv
fi
source venv/bin/activate

echo "📦 [2/6] 安装依赖..."
pip install --upgrade pip
pip install fastapi uvicorn openai python-dotenv email-validator requests

echo "🧩 [3/6] 检查项目文件..."
if [ ! -d "bills" ] || [ ! -f "bills/db.py" ]; then
    echo "❌ 未找到 bills/db.py，请确认 bills 模块存在"
    exit 1
fi

if [ ! -d "interface" ] || [ ! -f "interface/app.py" ]; then
    echo "❌ 未找到 interface/app.py，请确认 interface 模块存在"
    exit 1
fi

echo "� [4/6] 检查环境变量文件..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "⚙️ .env 不存在，正在从 .env.example 复制 -> .env (请填写其中的密钥)"
        cp .env.example .env
        echo "✅ 已创建 .env（基于 .env.example），请编辑并填写你的 DASHSCOPE_API_KEY 等敏感信息"
    else
        echo "⚠️ .env.example 不存在，创建一个带注释的 .env 占位文件"
        cat <<EOF > .env
# 请在此填写你的环境变量（不要将此文件提交到 git）
DASHSCOPE_API_KEY=""

# SQLite数据库配置
DB_FILE="bills/bills.db"

# 密码加密盐值（可选）
PASSWORD_SALT="smartledger_default_salt"

# 服务配置
UVICORN_HOST="0.0.0.0"
UVICORN_PORT="8000"
EOF
        echo "✅ 已创建占位 .env，请填写真实配置"
    fi
else
    echo "ℹ️ .env 已存在"
fi

echo "🚀 [5/6] 完成准备 — 可选择初始化数据库并启动服务"
# 在脚本中加载 .env
if [ -f .env ]; then
    # 将非注释行导出为环境变量
    export $(grep -v '^#' .env | xargs) || true
fi

read -p "是否初始化数据库？ [Y/n] " INIT_DB
if [[ -z "$INIT_DB" || "$INIT_DB" =~ ^[Yy] ]]; then
    echo "初始化数据库..."
    python3 -c "from bills import db; db.init_db(); print('数据库初始化完成')"
fi

read -p "是否现在启动服务器？ [y/N] " START_SERVER
if [[ "$START_SERVER" =~ ^[Yy] ]]; then
    echo "正在启动服务..."
    source venv/bin/activate
    # 使用 start_server.sh 启动（推荐方式）
    if [ -f "start_server.sh" ]; then
        echo "使用 start_server.sh 启动服务..."
        bash start_server.sh
    else
        # 备用方式：直接使用 uvicorn
        echo "使用 uvicorn 直接启动服务..."
        uvicorn interface.app:app --host ${UVICORN_HOST:-0.0.0.0} --port ${UVICORN_PORT:-8000} --reload
    fi
else
    echo "已完成设置。要启动服务，请运行："
    echo "  bash start_server.sh"
    echo "或："
    echo "  source venv/bin/activate"
    echo "  uvicorn interface.app:app --host \${UVICORN_HOST:-0.0.0.0} --port \${UVICORN_PORT:-8000} --reload"
fi

