# 统计 & 财务健康数据流梳理

> 目标：明确 iPhone 端统计页（`StatisticsAnalyticsView`）与财务健康页（`FinancialHealthView`）所需的数据来源、聚合方案以及后续对接后端的接口预留。

## 1. 数据来源总览

| 数据域 | SwiftData 实体/服务 | 关键字段 | 现有产出 | 说明 |
| --- | --- | --- | --- | --- |
| 历史交易 | `Transaction`, `TransactionCategory` | `type`, `amount`, `occurredAt`, `category`, `status` | Dashboard 列表、预算条 | 统计页收入/支出、类别占比的基础数据。需过滤 `status == .ok`，排除草稿。|
| 识别历史 | `RecognizedReceiptHistory` | `recognizedAt`, `result` (JSON)、`appliedTransactionID` | 最近识别记录 | 当交易尚未写入账本时，可作为统计补充或提醒使用。|
| 预算计划 | `BudgetPlan`, `BudgetSegment` | `totalLimit`, `segments[].limit/spent` | Dashboard 预算卡 | 财务健康页需读取月度预算 & 分类预算进度。|
| 财务目标 | (当前模拟) `GoalSyncPayload` via `GoalSyncService` | `targetAmount`, `currentAmount`, `deadline` | Achievements / 目标页 | 财务健康页“攒钱目标”卡片、进度。后续需落地到 SwiftData。|
| 用户画像 | `UserProfileEntity` → `UserProfileSnapshot` | `ageRange`, `occupation`, `incomeBracket`, `goals`, `targetTimeline`, `targetAmount`, `savedAmount` | 登录问卷 | 统计洞察、理财建议文案需要根据画像字段做差异化提示。|

## 2. 统计页（StatisticsAnalyticsView）聚合方案

| 模块 | 展示字段 | 数据来源 | 聚合逻辑 | 备注 |
| --- | --- | --- | --- | --- |
| Header 总览 | 本月总支出、本月收入、本月结余、mom 对比 | `Transaction` (当月) + 上月对照 | 1）基于 `Calendar.current` 按月切片；2）`Decimal` 汇总后转字符串；3）环比 = (本月-上月)/上月 | 待接入真实 `StatisticsViewModel` 输出。|
| 周期切换 | `periods`（本月/近三月/...） | ViewModel 配置 | 切换后调用聚合层重算时间窗口 | 需保留 `StatisticsViewModel` 内部 state。|
| 关键概览 | 固定支出/生活方式等 | `Transaction` 分类聚合 | 基于 `TransactionCategory.kind == .expense`，设置默认分组（可配置） | 需求确认后可扩展自定义分组。|
| 收支趋势 | 趋势 chart | `StatisticSnapshot` | 调用现有 `StatisticsService.monthlySnapshots/yearlySnapshots`（待确认实现） | 当前 UI 用占位；接 Chart 前需保证 DTO 提供 `label`, `income`, `expense`。|
| 支出类别 | 类别列表 & 进度条 | `StatisticsCategoryEntry` or 自定义聚合 | 1）按类别聚合当期支出；2）总支出为分母求百分比；3）支持 Top N + “其他” 合并 | 颜色可取自 `TransactionCategory.colorHex`。|
| 理财建议 | 文案列表 | 用户画像 + 聚合结果 | 组合规则：例如支出超预算、固定支出高等；默认提供静态占位，后续接 AI | 需建立规则引擎占位。|

### 聚合接口草案（本地）

```swift
protocol StatisticsAggregator {
    func makeSummary(for period: Period) throws -> StatisticsSummary
    func makeTrend(for period: Period) throws -> [StatisticSnapshot]
    func makeCategoryBreakdown(for period: Period, kind: CategoryKind) throws -> [CategoryBreakdown]
    func makeHighlights(for period: Period) throws -> [HighlightItem]
    func makeInsights(summary: StatisticsSummary, profile: UserProfileSnapshot?) -> [Insight]
}
```

> 实现细节：封装在 `StatisticsViewModel` 新增 `StatisticsAggregator` 依赖，内部使用 `ModelContext` 读取 `Transaction` 并缓存结果。

### 后端 DTO 预留

| 接口 | 方向 | 目的 | 建议 payload |
| --- | --- | --- | --- |
| `POST /analytics/report` | 上传 | 同步本地统计结果 | `{ user_id, period, generated_at, totals: { income, expense, net }, categories: [...], insights: [...] }` |
| `GET /analytics/report` | 下载 | 服务端生成报告 | `{ report_id, summary, suggestions, risk_flags }` |

> ViewModel 需保留 `lastSyncedAt`, `pendingSyncPayload` 等 state，待后端确定后实现。

## 3. 财务健康页（FinancialHealthView）聚合方案

| 模块 | 展示字段 | 数据来源 | 聚合逻辑 | 备注 |
| --- | --- | --- | --- | --- |
| 预算卡 | 当前月度预算、提示 | `BudgetPlan`（period = .monthly） | 选取最近的月度计划；若无则 fallback 到默认预算 | 需提供编辑入口（TODO）。|
| 资产列表 | 储蓄、投资等 | 现阶段可用虚拟数据；未来需接 `LedgerEntry` 或独立资产表 | 将资产模型标准化 `{name, amount, rate}` | 若暂无资产数据，显示占位提示。|
| 负债列表 | 信用卡、房贷 | 同上 | 计算负债总额 & 平均利率 | 需确认数据来源（可能来自问卷或后端）。|
| 攒钱目标 | 目标进度、剩余金额 | `GoalSyncService` / SwiftData 化后的目标实体 | `progress = current/target`，`remainingDays` 由 deadline 计算 | 要与统计页共享数据口径。|
| 汇总卡片 | 活跃目标、目标完成度 | 来自目标聚合 | `goalCompletion = totalCurrent/totalTarget` | 与后端同步时一并提交。|

### 聚合接口草案（本地）

```swift
protocol FinancialHealthAggregator {
    func fetchMonthlyBudget() throws -> BudgetInfo
    func fetchAssets() throws -> [AssetItem]
    func fetchLiabilities() throws -> [LiabilityItem]
    func fetchGoalOverview() async throws -> GoalOverview
    func composeInsight(profile: UserProfileSnapshot?, goals: GoalOverview) -> [HealthInsight]
}
```

> 资产/负债暂缺本地实体：先用 `FinancialHealthPreviewViewModel` 占位，后续决定是否落地专门模型或引用 `LedgerEntry` 扩展字段。

### 用户画像的衔接

| 画像字段 | 使用场景 | 规则示例 |
| --- | --- | --- |
| `ageRange` | 理财建议语气、风险偏好 | 22-30 岁提示“建立应急金”；40+ 强调退休储蓄。|
| `occupation` | 预算建议 | 自由职业提示预留流动资金。|
| `incomeBracket` | 汇总卡对比值 | 显示收入 vs 同档位平均支出（后端提供）。|
| `goals` | 理财建议筛选 | 若选择“购房”，则财务健康页添加购房资本提示。|
| `targetAmount`, `savedAmount` | 目标进度 | 与 `GoalOverview` 结合，计算整体达成率。|

## 4. 下一步实现建议

1. **实现聚合服务**：在 `StatisticsViewModel`、`FinancialHealthView` 新建独立的 `Aggregator` 层，使用 `ModelContext`/`GoalSyncService` 读取数据，输出新的 `DisplayModel`。
2. **统一 DTO**：为统计/财务两页定义 `DisplayModel`（已在预览 ViewModel 中初步编写），待真实数据接入时复用。
3. **缓存策略**：常用时间窗口（本月、近三月）可缓存计算结果，避免重复遍历数据库；与 `FinanceEventBus` 事件联动时刷新缓存。
4. **后端同步预留**：在聚合过程中组装 `AnalyticsReportPayload`，暂存于本地，待用户触发“同步”或自动定时上传。
5. **测试用例**：准备三组 SwiftData fixture（无数据、单月大额、跨年分布）验证聚合正确性。

---

如需进一步细化计算（例如支出类别 Top N 合并、资产负债比等），可在聚合层增加扩展方法并写入单元测试。
