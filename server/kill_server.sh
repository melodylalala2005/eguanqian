#!/bin/bash
# kill-uvicorn.sh  → chmod +x kill-uvicorn.sh

# 1. 普通 SIGTERM
pkill -f uvicorn
sleep 1

# 2. 若仍存活，强制 SIGKILL
if lsof -i :8000 >/dev/null 2>&1; then
    kill -9 $(lsof -t -i :8000) 2>/dev/null
fi

# 3. 确认结果
if lsof -i :8000 >/dev/null 2>&1; then
    echo "❌ 8000 仍被占用"
else
    echo "✅ uvicorn 已停"
fi