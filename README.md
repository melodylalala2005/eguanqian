<div align="center">

# 🐧 鹅管钱

**拍一张账单，剩下的交给我们。**

一款面向年轻群体的 AI 记账与财务健康管理 App —— 用 OCR + LLM 实现无感记账，用 AI 理财搭子提供陪伴式财务建议，帮助「数字习惯强、财务意识弱」的年轻人从被动记账走向主动管钱。

> 2025 FinTechathon 金融科技挑战赛参赛作品 · 鹅们来管钱队

</div>

---

## ✨ 核心能力

| 能力 | 说明 |
| --- | --- |
| 📸 **AI 识图记账** | 拍一张账单截图，OCR 提取 + LLM 推理自动生成结构化记录，识别金额、类别、日期、描述 |
| 💬 **AI 理财助手** | 自然语言查询账单与预算，多轮上下文记忆，提供个性化财务建议 |
| 📊 **智能统计分析** | 收支趋势、类别占比、532 财务分配法则，收支双视图 |
| 🎯 **财务健康管理** | 分类预算设置、临近超支实时预警、自动生成资产负债表 |
| 🏆 **成就系统** | 记账与攒钱的每一步都转化为可视化成果，帮助长期坚持 |
| 🔒 **本地优先** | SwiftData 本地账本，敏感数据不出端 |

## 🖼 产品一览

<table>
<tr>
<td width="50%" align="center"><b>首页 Dashboard</b><br><img src="docs/images/01-home-dashboard.webp" alt="首页"/></td>
<td width="50%" align="center"><b>添加交易</b><br><img src="docs/images/03-add-transaction.webp" alt="添加交易"/></td>
</tr>
<tr>
<td width="50%" align="center"><b>统计分析</b><br><img src="docs/images/04-statistics-trend.webp" alt="统计分析"/></td>
<td width="50%" align="center"><b>财务健康管理</b><br><img src="docs/images/06-financial-health.webp" alt="财务健康管理"/></td>
</tr>
<tr>
<td width="50%" align="center"><b>AI 理财助手</b><br><img src="docs/images/09-ai-assistant.webp" alt="AI 理财助手"/></td>
<td width="50%" align="center"><b>成就徽章</b><br><img src="docs/images/08-achievements.webp" alt="成就徽章"/></td>
</tr>
</table>

更多界面与设计说明详见 [产品文档](./docs/市场与产品文档/README.md)。完整实机演示见 [**产品演示视频**](https://github.com/melodylalala2005/eguanqian/releases/tag/v1.0)（754 MB，在线播放）。

## 🏗 系统架构

![系统架构](docs/images/architecture.webp)

```
iOS 客户端 (SwiftUI + SwiftData)
    │  HTTP
    ▼
后端 (FastAPI + SQLite)
    ├── /upload_baidu_qwen   百度 OCR + Qwen 文本模型（默认链路）
    ├── /upload_qwen_vl      Qwen-VL 多模态直接识图
    └── /upload_llm          自然语言文本解析
```

- **iOS 前端**：42 个 Swift 文件 / ~13,500 行，SwiftUI + SwiftData + MVVM + 依赖注入，全部服务协议化、Mock 与网络实现可切换
- **Python 后端**：FastAPI + SQLite，三种解析引擎统一接口、统一返回结构，Token 鉴权

详见 [技术架构文档](./docs/技术架构.md)。

## 📁 仓库结构

```
.
├── ios/                    # iOS 客户端（SwiftUI）
│   ├── IOSApp/             # 源码
│   ├── Documentation/      # 前端数据流设计文档
│   ├── project.pbxproj     # Xcode 工程文件
│   └── README.md
├── server/                 # Python 后端（FastAPI）
│   ├── interface/          # API 路由
│   ├── services/           # 三条 LLM 解析链路
│   ├── bills/              # 数据层
│   ├── apis.example.json   # 配置模板
│   └── README.md           # 完整 API 文档
└── docs/                   # 产品与技术文档
    ├── 市场与产品文档/      # 完整产品说明（5 篇）
    ├── 原始资料/            # 比赛提交原件（PDF / PPT）
    ├── 技术架构.md
    └── images/             # 产品界面截图
```

## 🚀 快速开始

### 后端

```bash
cd server

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 配置 API 密钥
cp apis.example.json apis.json   # 填入你的 Qwen / 百度密钥
cp .env.example .env             # 按需修改

# 初始化数据库并启动
python3 -c "from bills import db; db.init_db()"
uvicorn interface.app:app --host 0.0.0.0 --port 8000 --reload
```

启动后访问 `http://localhost:8000/docs` 查看交互式 API 文档。

### iOS

```bash
open ios/IOSApp.xcodeproj
```

⌘R 运行。所有服务都有 Mock 实现，**无需启动后端即可预览完整 UI**；要联调真实识图，按 [`ios/README.md`](./ios/README.md) 配置后端地址与 token。

## 📈 关键实验结果

> 完整评估方案与数据见 [技术选型与实验评估](./docs/市场与产品文档/04-技术与评估.md)。测试集为 800 张真实账单截图（金额 ¥0.28–¥11,603，人工脱敏+交叉标注，Kappa = 0.96）。

| 指标 | 正则基线 | VLLM | PP-OCR-VL | **OCR + LLM** |
| --- | --- | --- | --- | --- |
| 金额零误差 | 38.4% | 87.1% | 82.9% | **95.0%** |
| ≤0.5% 误差 | 65.0% | 85.0% | 90.8% | **98.0%** |
| 万条成本 | ¥0 | ¥80 | ¥180 | **¥40** |
| 端到端 P99 | 0.25 s | 0.65 s | 0.48 s | **0.35 s** |

AI 财务助手实测：首响 0.82 s（P90）、意图准度 88.4%、工具调用成功率 99.1%、单用户日均成本 ¥0.0041。

## 🧠 团队

| 成员 | 角色 |
| --- | --- |
| 王诗雨 | 产品 |
| 杨镜池 | 开发 |
| 杨若非 | 产品 |
| 曹元 | 开发 |
| 邓祎柯 | 产品 |
| 孟响 | 设计 |
| 喻才恒 | 开发 |

## 📦 原始材料

比赛提交的原始文档与演示视频，已归档到本仓库：

| 材料 | 位置 | 说明 |
| --- | --- | --- |
| 📕 产品说明文档 | [`docs/原始资料/鹅管钱-产品说明文档.pdf`](./docs/原始资料/鹅管钱-产品说明文档.pdf)（6.8 MB） | 21 页完整产品文档：市场分析、痛点、方案、技术选型与实验评估 |
| 🎨 产品介绍 PPT | [`docs/原始资料/鹅管钱-产品介绍.pptx`](./docs/原始资料/鹅管钱-产品介绍.pptx)（19 MB） | 23 页比赛答辩 PPT，含全部界面设计稿 |
| 🎬 产品演示视频 | [GitHub Release v1.0](https://github.com/melodylalala2005/eguanqian/releases/tag/v1.0)（754 MB） | App 实机操作演示。因超过 GitHub 单文件 100 MB 限制，通过 Release 附件发布 |

> PPT 原始文件 812 MB（内嵌演示视频），已将视频剥离单独归档到 Release，PPT 本身保留全部 23 页内容。

## 📄 许可证

[MIT License](./LICENSE)
