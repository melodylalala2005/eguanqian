import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
import os
import base64
from datetime import datetime
from typing import Optional, Union
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Response, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, EmailStr

from config import load_env, init_app, get_settings

# 在导入模块时加载环境
load_env()
settings = get_settings()
# 初始化数据库（如果需要）
init_app()

from bills.db import (
    save_bill,
    create_user,
    verify_user,
    generate_token,
    save_user_token,
    verify_token,
    delete_bill,
    get_bill_by_id,
)
from services.qwen import parse_bill_file as parse_qwen_file
from services.baidu_qwen import parse_bill_file as parse_baidu_file
from services.llm import parse_bill_text
from services.baidu_qwen import CATEGORIES
import logging
from logging.handlers import RotatingFileHandler

os.makedirs("logs", exist_ok=True)
logger = logging.getLogger("smartledger")
logger.setLevel(logging.INFO)
if not logger.handlers:
    fh = RotatingFileHandler("logs/app.log", maxBytes=5*1024*1024, backupCount=3)
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

app = FastAPI(title="Cloud Bill Agent VL")


# ==================== Pydantic 模型 ====================

class RegisterRequest(BaseModel):
    """用户注册请求模型"""
    email: EmailStr
    password: str
    user_id: Optional[str] = None  # 可选的自定义用户ID


class RegisterResponse(BaseModel):
    """用户注册响应模型"""
    status: str
    message: str
    user: Optional[dict] = None


class LoginRequest(BaseModel):
    """用户登录请求模型"""
    email: EmailStr
    password: str


class LoginResponse(BaseModel):
    """用户登录响应模型"""
    status: str
    message: str
    user: Optional[dict] = None


class BillData(BaseModel):
    """账单数据模型"""
    bill_id: str
    category: str
    amount: Union[str, float]
    date: Optional[str] = None  # 可选，格式：YYYY-MM-DD，不提供则使用当前日期
    description: Optional[str] = ""  # 可选，默认为空字符串
    nw_type: Optional[str] = None


class ManualBillRequest(BaseModel):
    """手动上传账单请求模型"""
    user_id: str
    bill: BillData


class ManualBillResponse(BaseModel):
    """手动上传账单响应模型"""
    status: str
    message: str
    bill_id: Optional[str] = None


class DeleteBillRequest(BaseModel):
    """删除账单请求模型"""
    token: str
    bill_id: str


class DeleteBillResponse(BaseModel):
    """删除账单响应模型"""
    status: str
    message: str


class TokenVerifyRequest(BaseModel):
    """Token验证请求模型"""
    token: str


class TokenVerifyResponse(BaseModel):
    """Token验证响应模型"""
    status: str
    valid: bool
    message: Optional[str] = None
    expires_at: Optional[str] = None


@app.get("/ping")
async def ping():
    return {"status": "ok", "message": "Cloud Bill Agent running"}


# ==================== 用户管理接口 ====================

@app.post("/register", response_model=RegisterResponse)
async def register(request: RegisterRequest):
    """
    用户注册接口
    
    - **email**: 用户邮箱（必须唯一）
    - **password**: 用户密码（明文，会自动加密存储）
    - **user_id**: 可选的自定义用户ID，如果不提供则自动生成UUID
    
    注意：格式验证由前端处理，后端不做格式检查
    """
    try:
        # 创建用户（格式检查交由前端处理）
        user = create_user(
            email=request.email,
            password=request.password,
            user_id=request.user_id
        )
        
        return RegisterResponse(
            status="ok",
            message="用户注册成功",
            user=user
        )
    
    except ValueError as e:
        # 邮箱已存在等业务错误
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"注册失败: {str(e)}"
        )


@app.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """
    用户登录接口
    
    - **email**: 用户邮箱
    - **password**: 用户密码（明文）
    
    返回用户信息和token（token有效期30天）
    """
    try:
        # 验证用户
        user = verify_user(request.email, request.password)
        
        if user:
            # 生成token（持续一个月）
            token = generate_token()
            # 保存token到数据库（如果已存在则覆盖）
            save_user_token(user["user_id"], token, expires_in_days=30)
            
            # 返回用户信息和token
            user_with_token = user.copy()
            user_with_token["token"] = token
            
            return LoginResponse(
                status="ok",
                message="登录成功",
                user=user_with_token
            )
        else:
            raise HTTPException(
                status_code=401,
                detail="邮箱或密码错误"
            )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"登录失败: {str(e)}"
        )


# ==================== 账单管理接口 ====================

@app.post("/manual_bill", response_model=ManualBillResponse)
async def manual_bill(request: ManualBillRequest):
    """
    手动上传记账数据接口
    
    - **user_id**: 用户ID
    - **bill**: 账单数据JSON
      - **bill_id**: 账单唯一编号（必填，由调用方生成并保证唯一）
      - **category**: 账单类别（必填）
      - **amount**: 金额（必填）
      - **date**: 日期（可选，格式：YYYY-MM-DD，不提供则使用当前日期）
      - **description**: 描述（可选，默认为空字符串）
    
    将账单数据写入数据库
    """
    try:
        # 验证必填字段
        if not request.bill.category:
            raise HTTPException(
                status_code=400,
                detail="账单类别不能为空"
            )
        
        if request.bill.amount is None:
            raise HTTPException(
                status_code=400,
                detail="账单金额不能为空"
            )

        if not request.bill.bill_id:
            raise HTTPException(
                status_code=400,
                detail="bill_id 不能为空"
            )
        
        def normalize_amount(val) -> float:
            try:
                if isinstance(val, (int, float)):
                    num = float(val)
                else:
                    s = str(val).strip().replace(",", "").replace("￥", "").replace("RMB", "")
                    num = float(s)
                if num <= 0:
                    raise ValueError()
                return round(num, 2)
            except Exception:
                raise HTTPException(status_code=400, detail="账单金额必须为正数，且格式有效")

        # 验证日期格式（如果提供）
        if request.bill.date:
            try:
                datetime.strptime(request.bill.date, "%Y-%m-%d")
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="日期格式错误，应为 YYYY-MM-DD"
                )
        
        nw_type = request.bill.nw_type
        if nw_type and nw_type not in {"基础支出", "娱乐支出"}:
            raise HTTPException(status_code=400, detail="nw_type 必须为 基础支出 或 娱乐支出")

        if request.bill.category and CATEGORIES and request.bill.category not in CATEGORIES:
            raise HTTPException(status_code=400, detail="类别不在允许列表中")

        # 准备账单数据（包含生成的bill_id）
        bill_data = {
            "user_id": request.user_id,
            "category": request.bill.category,
            "amount": normalize_amount(request.bill.amount),
            "date": request.bill.date,  # 如果为None，save_bill会使用当前日期
            "description": request.bill.description or "",
            "bill_id": request.bill.bill_id,
            "nw_type": nw_type
        }
        
        # 保存账单
        save_bill(bill_data)
        logger.info(f"manual_bill saved bill_id={request.bill.bill_id} user_id={request.user_id} category={bill_data['category']} nw_type={bill_data['nw_type']} amount={bill_data['amount']}")
        
        return ManualBillResponse(
            status="ok",
            message="账单保存成功",
            bill_id=request.bill.bill_id
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"保存账单失败: {str(e)}"
        )


@app.post("/delete_bill", response_model=DeleteBillResponse)
async def delete_bill_endpoint(request: DeleteBillRequest):
    """
    删除账单接口
    
    - **token**: 用户登录后获取的 token
    - **bill_id**: 要删除的账单唯一编号
    
    仅允许删除当前用户名下的账单。
    """
    try:
        user_info = verify_token(request.token)
        if not user_info:
            raise HTTPException(
                status_code=401,
                detail="Token无效或已过期"
            )

        bill = get_bill_by_id(request.bill_id)
        if not bill:
            raise HTTPException(
                status_code=404,
                detail="账单不存在"
            )

        if bill.get("user_id") != user_info["user_id"]:
            raise HTTPException(
                status_code=403,
                detail="无权删除该账单"
            )

        if not delete_bill(request.bill_id):
            raise HTTPException(
                status_code=500,
                detail="账单删除失败"
            )

        logger.info(f"delete_bill bill_id={request.bill_id} by user_id={user_info['user_id']}")
        return DeleteBillResponse(
            status="ok",
            message="账单删除成功"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"删除账单失败: {str(e)}"
        )


@app.post("/upload_qwen_vl")
async def upload_qwen_vl(
    file: UploadFile = File(...),
    token: str = Form(...),
    bill_id: str = Form(...)
):
    try:
        # 验证token
        user_info = verify_token(token)
        if not user_info:
            raise HTTPException(
                status_code=401,
                detail="Token无效或已过期"
            )
        
        user_id = user_info["user_id"]
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        temp_path = f"/tmp/{file.filename}"
        with open(temp_path, "wb") as f:
            f.write(await file.read())

        parsed_json = parse_qwen_file(temp_path)

        if not bill_id:
            raise HTTPException(
                status_code=400,
                detail="bill_id 不能为空"
            )

        amt = round(float(str(parsed_json.get("amount", "0")).replace(",", "").replace("￥", "").replace("RMB", "")), 2)
        bill_data = {
            "user_id": user_id,
            "category": parsed_json.get("category", "其他支出"),
            "amount": amt,
            "date": parsed_json.get("date", timestamp[:10]),
            "description": parsed_json.get("description", ""),
            "bill_id": bill_id,
            "nw_type": parsed_json.get("nw_type")
        }
        save_bill(bill_data)

        os.remove(temp_path)

        logger.info(f"upload_qwen_vl saved bill_id={bill_id} user_id={user_id} category={bill_data['category']} nw_type={bill_data['nw_type']} amount={bill_data['amount']}")
        parsed_json["amount"] = f"{amt:.2f}"
        return JSONResponse(content={"status": "ok", "result": parsed_json})

    except HTTPException:
        raise
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)})



@app.post("/upload_baidu_qwen")
async def upload_baidu_qwen(
    file: UploadFile = File(...),
    token: str = Form(...),
    bill_id: str = Form(...)
):
    try:
        # 验证token
        user_info = verify_token(token)
        if not user_info:
            raise HTTPException(
                status_code=401,
                detail="Token无效或已过期"
            )
        
        user_id = user_info["user_id"]
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        temp_path = f"/tmp/{file.filename}"
        with open(temp_path, "wb") as f:
            f.write(await file.read())

        parsed_json = parse_baidu_file(temp_path)

        if not bill_id:
            raise HTTPException(
                status_code=400,
                detail="bill_id 不能为空"
            )

        amt = round(float(str(parsed_json.get("amount", "0")).replace(",", "").replace("￥", "").replace("RMB", "")), 2)
        bill_data = {
            "user_id": user_id,
            "category": parsed_json.get("category", "其他支出"),
            "amount": amt,
            "date": parsed_json.get("date", timestamp[:10]),
            "description": parsed_json.get("description", ""),
            "bill_id": bill_id,
            "nw_type": parsed_json.get("nw_type")
        }
        save_bill(bill_data)

        os.remove(temp_path)

        logger.info(f"upload_baidu_qwen saved bill_id={bill_id} user_id={user_id} category={bill_data['category']} nw_type={bill_data['nw_type']} amount={bill_data['amount']}")
        parsed_json["amount"] = f"{amt:.2f}"
        return JSONResponse(content={"status": "ok", "result": parsed_json})

    except HTTPException:
        raise
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)})


@app.post("/upload_llm")
async def upload_llm(
    text: str = Form(...),
    token: str = Form(...),
    bill_id: str = Form(...)
):
    try:
        user_info = verify_token(token)
        if not user_info:
            raise HTTPException(
                status_code=401,
                detail="Token无效或已过期"
            )
        user_id = user_info["user_id"]
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        if not text:
            raise HTTPException(
                status_code=400,
                detail="text 不能为空"
            )

        parsed_json = parse_bill_text(text)

        if not bill_id:
            raise HTTPException(
                status_code=400,
                detail="bill_id 不能为空"
            )

        amt = round(float(str(parsed_json.get("amount", "0")).replace(",", "").replace("￥", "").replace("RMB", "")), 2)
        bill_data = {
            "user_id": user_id,
            "category": parsed_json.get("category", "其他支出"),
            "amount": amt,
            "date": parsed_json.get("date", timestamp[:10]),
            "description": parsed_json.get("description", ""),
            "bill_id": bill_id,
            "nw_type": parsed_json.get("nw_type")
        }
        save_bill(bill_data)
        logger.info(f"upload_llm saved bill_id={bill_id} user_id={user_id} category={bill_data['category']} nw_type={bill_data['nw_type']} amount={bill_data['amount']}")
        parsed_json["amount"] = f"{amt:.2f}"
        return JSONResponse(content={"status": "ok", "result": parsed_json})
    except HTTPException:
        raise
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)})


@app.get("/verify_token", response_model=TokenVerifyResponse)
async def verify_token_endpoint(token: str = Query(..., description="要验证的token")):
    """
    Token验证接口
    
    - **token**: 要验证的token（查询参数）
    
    返回token是否在有效期内
    """
    try:
        user_info = verify_token(token)
        if user_info:
            return TokenVerifyResponse(
                status="ok",
                valid=True,
                message="Token有效",
                expires_at=user_info.get("token_expires_at")
            )
        else:
            return TokenVerifyResponse(
                status="ok",
                valid=False,
                message="Token无效或已过期"
            )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"验证失败: {str(e)}"
        )


@app.get("/favicon.ico", include_in_schema=False)
def _(): return Response(status_code=204)

@app.get("/{full_path:path}", include_in_schema=False)
def catch_all(): return Response(status_code=444)

@app.middleware("http")
async def log_body(request: Request, call_next):
    response = await call_next(request)
    body = b""
    async for chunk in response.body_iterator:
        body += chunk
    print(f"【RESPONSE】{response.status_code} | {body.decode()}")
    # 把内容重新封装回去，避免客户端收不到
    return Response(content=body, status_code=response.status_code,
                    headers=dict(response.headers), media_type=response.media_type)