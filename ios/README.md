# 鹅管钱 · iOS 客户端

SwiftUI 编写的记账与财务健康管理 App，支持 AI 识图记账、预算管理、统计分析和 AI 理财助手对话。

## 技术栈

| 项目 | 选型 |
| --- | --- |
| 语言 | Swift 5.9 |
| UI | SwiftUI |
| 本地存储 | SwiftData |
| 架构 | MVVM + 依赖注入 |
| 最低部署 | iOS 17.0 |
| 构建 | Xcode 15+ |

## 目录结构

```
IOSApp/
├── AppRootView.swift              # 根视图与主导航
├── MyConnectivityAppApp.swift     # App 入口
├── AppDelegate.swift              # 推送与生命周期
├── ContentView.swift              # 主内容容器
├── FinanceShellView.swift         # Tab 外壳
│
├── FinanceModels.swift            # SwiftData 数据模型
├── CategoryDefinitions.swift      # 收支分类定义
├── FinanceServices.swift          # 服务协议 + Mock/网络实现
├── FinanceEnvironment.swift       # 依赖注入容器
├── FinanceAPIClient.swift         # 泛型网络客户端
├── Networking.swift               # APIConfiguration / 同步服务
├── Formatting.swift               # 金额、日期格式化
├── Color+Finance.swift            # 品牌色
├── DesignTokens.swift             # 设计令牌
│
├── DashboardViews.swift           # 首页
├── StatisticsViews.swift          # 统计
├── StatisticsAnalyticsView.swift  # 统计分析
├── StatisticsAnalyticsAggregator.swift
├── FinancialHealthView.swift      # 财务健康
├── FinancialHealthViewModel.swift
├── GoalsViews.swift               # 财务目标
├── AchievementsViews.swift        # 成就徽章
├── AIChatView.swift               # AI 理财助手
├── LoginFlowView.swift            # 登录/问卷
│
├── ReceiptCameraCaptureView.swift # 账单拍摄
├── ReceiptImagePreprocessor.swift # 图片预处理
├── ReceiptRecognitionCoordinator.swift  # 识别协调
├── ReceiptRecognitionQueueStore.swift   # 识别队列
├── ReceiptRecognitionHistoryStore.swift # 识别历史
├── ReceiptRecognitionPreferences.swift  # 识别偏好
├── ProcessReceiptIntent.swift     # App Intents 快捷指令
│
├── ConnectivityService.swift      # 网络连通性
├── NetworkStatusService.swift     # 网络状态
├── UserProfileEntity.swift        # 用户画像
├── UserProfileModels.swift
├── SharedModelContainerProvider.swift
├── SharedAppNotifications.swift
├── AppDeepLinkRouter.swift        # 深链路由
├── DeepLinkDiagnostics.swift
├── FinanceSeeder.swift            # 演示数据填充
└── ViewModels.swift               # 各页面 ViewModel
```

## 配置后端地址

App 默认连接 `http://localhost:8000`。要连接自己的后端，三种方式任选其一：

**方式一：环境变量**（适合命令行构建）

```bash
API_BASE_URL="http://你的服务器:8000" \
API_USER_ID="你的用户ID" \
OCR_RECOGNITION_TOKEN="你的token" \
xcodebuild ...
```

**方式二：Info.plist**（适合 Xcode 内运行）

在 `Info.plist` 中添加：

```xml
<key>APIBaseURL</key>
<string>http://你的服务器:8000</string>
<key>APIUserID</key>
<string>你的用户ID</string>
<key>APIRecognitionToken</key>
<string>你的token</string>
```

> ⚠️ 后端走 HTTP 时需配置 ATS 例外，见 `Info.plist` 中的 `NSAppTransportSecurity`。生产环境请使用 HTTPS。

## 本地运行

```bash
open ../IOSApp.xcodeproj
```

在 Xcode 中选择模拟器或真机，⌘R 运行即可。所有服务都有 Mock 实现，**无需启动后端**即可预览完整 UI。首次运行会通过 `FinanceSeeder` 填充演示数据。

## 与后端联调

1. 按 [`server/README.md`](../server/README.md) 启动后端
2. 用 `/register` 注册用户，`/login` 获取 token
3. 按上文配置 `APIBaseURL` / `APIUserID` / `APIRecognitionToken`
4. 在 App 中拍摄账单，验证识图记账链路
