# 安全须知

本仓库已做过脱敏处理，但拉取后二次开发时请务必注意以下几点。

## 🔑 密钥管理

- **`server/apis.json` 与 `server/.env` 已在 `.gitignore` 中**，请勿提交
- 首次使用：`cp server/apis.example.json server/apis.json`，填入你自己的密钥
- 密钥来源：[阿里云 DashScope](https://dashscope.console.aliyun.com/)（Qwen 系列）与[百度智能云](https://cloud.baidu.com/product/ocr.html)（OCR）
- 仓库中的模板文件 `apis.example.json` 只含占位符，没有任何真实密钥

## 🚫 已从原始代码中移除的内容

| 原始内容 | 处理方式 |
| --- | --- |
| 硬编码的后端服务器 IP | 改为 `localhost`，支持环境变量 / Info.plist 覆盖 |
| 硬编码的开发万能 token | 改为环境变量 `DEV_BYPASS_TOKEN`，默认关闭 |
| 219 条真实测试账单与 6 个用户账号 | 移除数据库文件，改为启动时自动初始化 |
| 46 个 `.baiduyun.uploading.cfg` 残留 | 全部删除 |
| Xcode `xcuserdata` 个人状态 | 全部删除 |
| 含测试数据的日志 | 全部删除 |

## ⚠️ 开发万能 Token

`bills/db.py` 的 `verify_token` 支持一个跳过用户校验的万能 token，**默认关闭**：

```bash
export DEV_BYPASS_TOKEN="你自己指定的随机字符串"   # 开启
unset DEV_BYPASS_TOKEN                            # 关闭
```

**生产环境绝对不要配置此项。**

## 🔐 密码与鉴权

- 用户密码使用 SHA-256 加盐存储，盐值通过 `PASSWORD_SALT` 环境变量配置（默认值请务必修改）
- 登录返回 30 天有效期的 token（`secrets.token_urlsafe(32)`）
- 上传类接口需要 token 鉴权；删除账单会校验 token 归属

## 🌐 HTTP 明文传输

iOS 客户端与后端默认走 HTTP（本地开发）。`Info.plist` 中已为 `localhost` 配置 ATS 例外。部署到生产环境时：

1. 后端前置 HTTPS（Nginx / Caddy / 云负载均衡）
2. 移除 `Info.plist` 中的 `NSExceptionDomains` 条目
3. 将 `APIBaseURL` 改为 `https://...`
