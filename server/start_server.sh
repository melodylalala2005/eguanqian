#!/bin/bash

# 启动服务器脚本，替代main.py

echo "=== 启动Cloud Bill Agent服务 ==="

# 从apis.json读取配置并设置环境变量
set_api_keys_from_apis_json() {
    API_REG_PATH="$(dirname "$0")/apis.json"
    
    if [ -f "$API_REG_PATH" ]; then
        echo "正在从apis.json读取配置..."
        
        # 使用jq工具解析JSON（需要安装jq）
        if command -v jq &> /dev/null; then
            # 设置DASHSCOPE_API_KEY
            DASHSCOPE_KEY=$(jq -r '.DASHSCOPE.key_env // empty' "$API_REG_PATH")
            if [ -n "$DASHSCOPE_KEY" ]; then
                export DASHSCOPE_API_KEY="$DASHSCOPE_KEY"
                echo "✓ DASHSCOPE_API_KEY 已设置"
            fi
            
            # 设置qwen_turbo_key
            QWEN_TURBO_KEY=$(jq -r '.QWEN_TURBO.key_env // empty' "$API_REG_PATH")
            if [ -n "$QWEN_TURBO_KEY" ]; then
                export qwen_turbo_key="$QWEN_TURBO_KEY"
                echo "✓ qwen_turbo_key 已设置"
            fi
            
            # 设置baidu_access_token
            BAIDU_TOKEN=$(jq -r '.BAIDU.token.access_token // empty' "$API_REG_PATH")
            if [ -n "$BAIDU_TOKEN" ]; then
                export baidu_access_token="$BAIDU_TOKEN"
                echo "✓ baidu_access_token 已设置"
            fi
            
            echo "API密钥已成功设置到环境变量"
        else
            echo "警告: 未找到jq工具，无法解析JSON。请安装jq或手动设置环境变量。"
            echo "安装命令: apt-get install jq 或 yum install jq"
        fi
    else
        echo "警告: 找不到apis.json文件"
    fi
}

# 获取百度access_token
get_baidu_token() {
    BAIDU_TOKEN_SCRIPT="$(dirname "$0")/tools/baidu_token.py"
    
    if [ -f "$BAIDU_TOKEN_SCRIPT" ]; then
        echo "正在获取百度access_token..."
        if python3 "$BAIDU_TOKEN_SCRIPT"; then
            echo "百度access_token获取成功，正在更新环境变量..."
            set_api_keys_from_apis_json
            return 0
        else
            echo "警告: 百度access_token获取失败，但不影响服务启动"
            return 1
        fi
    else
        echo "未找到baidu_token.py，跳过access_token获取"
        return 0
    fi
}

# 加载环境变量文件
load_env_file() {
    ENV_FILE="$(dirname "$0")/.env"
    if [ -f "$ENV_FILE" ]; then
        echo "正在加载.env文件..."
        export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
        echo "环境变量加载完成"
    fi
}

# 检查Python虚拟环境
check_venv() {
    VENV_DIR="$(dirname "$0")/venv"
    if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
        echo "检测到虚拟环境，正在激活..."
        source "$VENV_DIR/bin/activate"
        return 0
    else
        echo "未检测到虚拟环境，使用当前Python环境"
        return 0
    fi
}

# 主函数
main() {
    # 检查并激活虚拟环境
    check_venv
    
    # 加载环境文件
    load_env_file
    
    # 从apis.json设置API密钥
    set_api_keys_from_apis_json
    
    # 获取百度access_token（如果失败不阻塞）
    get_baidu_token
    
    # 启动服务器
    echo "正在启动FastAPI服务器..."
    echo "服务地址: http://0.0.0.0:8000"
    echo "API文档: http://0.0.0.0:8000/docs"
    echo "按 Ctrl+C 停止服务"
    echo "===================================="
    
    # 启动uvicorn服务器
    python3 -m uvicorn interface.app:app --host 0.0.0.0 --port 8000 --reload
}

# 执行主函数
main
