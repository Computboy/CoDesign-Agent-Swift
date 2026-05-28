# CoDesign Agent — 工程落地级架构方案（v3）

> **v2 → v3 精修要点：**
> 1. 引入 Mock / Live 双模式服务架构，第一阶段先用 Mock 跑通全链路
> 2. 明确 SwiftData @Model 初始化策略，确保编译安全
> 3. 新增 MockDataFactory / SeedDataFactory，启动即有演示数据
> 4. 新增 StageDefinition / BriefField 代码级映射机制
> 5. 新增 conversationSummary 上下文构造策略
> 6. 新增完整错误状态与降级方案
> 7. 新增 LearningTrace / ReflectionCard 设计思维训练机制
> 8. 补充"每步可编译"的开发节奏

---

## 一、文件结构

```
CoDesign-Agent/
├── CoDesign_AgentApp.swift                    # App 入口，注册 ModelContainer + 服务注入
│
├── Models/                                    # ── SwiftData 持久化模型 ──
│   ├── Project.swift                          # 项目主模型
│   ├── ChatMessage.swift                      # 聊天消息
│   ├── DesignBrief.swift                      # 结构化设计简报
│   ├── ProgressStage.swift                    # 9 步流程节点
│   ├── RiskItem.swift                         # 风险矩阵条目
│   ├── BoundaryItem.swift                     # 项目边界表条目
│   ├── SuccessMetric.swift                    # 量化验收指标
│   ├── LearningTrace.swift                    # [NEW] 设计思维学习轨迹
│   └── ModelExtensions.swift                  # Model → DTO 转换 extension
│
├── DTOs/                                      # ── 轻量传输对象（纯 struct） ──
│   ├── ChatPayloadMessage.swift               # 对话消息 DTO（给 LLM API 用）
│   ├── DesignBriefSnapshot.swift              # 设计简报快照 DTO
│   ├── ProgressStageSnapshot.swift            # 进度节点快照 DTO + StageStatus enum
│   ├── RiskItemDTO.swift                      # 风险条目 DTO
│   ├── BoundaryItemDTO.swift                  # 边界条目 DTO
│   ├── SuccessMetricDTO.swift                 # 验收指标 DTO
│   ├── ExtractedFields.swift                  # 结构化提取结果
│   └── LearningTraceDTO.swift                 # [NEW] 学习轨迹 DTO
│
├── Services/                                  # ── 服务层（仅依赖 DTOs） ──
│   ├── Protocols/                             # [NEW] 协议集中定义
│   │   ├── LLMServiceProtocol.swift           # LLM 服务协议
│   │   └── StructuredExtractorProtocol.swift  # 结构化提取协议
│   ├── Mock/                                  # [NEW] Mock 实现
│   │   ├── MockLLMService.swift               # Mock LLM（预设回复 + 模拟流式）
│   │   └── MockStructuredExtractor.swift      # Mock 提取器（返回固定数据）
│   ├── Live/                                  # [NEW] Live 实现
│   │   ├── LiveLLMService.swift               # 真实 LLM API 调用
│   │   └── LiveStructuredExtractor.swift      # 真实 LLM 提取
│   ├── PromptTemplates.swift                  # 系统 Prompt & 提取 Prompt 模板
│   ├── ProgressAnalyzer.swift                 # 缺失字段诊断 / 阶段状态计算
│   ├── ReportExporter.swift                   # Markdown 开题报告生成
│   ├── StageDefinition.swift                  # [NEW] 9 阶段 ↔ 字段映射规则
│   └── ConversationContextBuilder.swift       # [NEW] 上下文构造策略
│
├── Factories/                                 # [NEW] 工厂与种子数据
│   ├── MockDataFactory.swift                  # 生成完整 mock 项目（演示/调试用）
│   └── SeedDataFactory.swift                  # App 首次启动时的种子数据
│
├── ViewModels/                                # ── 视图模型层 (MVVM) ──
│   ├── ProjectListViewModel.swift             # 项目列表页 ViewModel
│   ├── NewProjectViewModel.swift              # 新建项目页 ViewModel
│   ├── ProjectDetailViewModel.swift           # 项目详情页 ViewModel（Tab 容器）
│   ├── ChatViewModel.swift                    # 对话区 ViewModel
│   └── InsightsViewModel.swift               # 摘要 / 可视化区 ViewModel
│
├── Views/                                     # ── 视图层 ──
│   ├── ProjectList/
│   │   └── ProjectListView.swift              # 列表页 List
│   ├── NewProject/
│   │   └── NewProjectView.swift               # 新建项目页 Add
│   ├── ProjectDetail/
│   │   ├── ProjectDetailView.swift            # 详情页 Details（Tab 容器）
│   │   ├── ChatPanel.swift                    # 对话面板
│   │   ├── ProgressPanel.swift                # 9 步流程进度可视化
│   │   ├── InsightsPanel.swift                # 项目摘要 / 洞察
│   │   └── ExportPanel.swift                  # 导出预览 & 操作
│   └── Components/                            # ── 自定义可复用组件 ──
│       ├── MessageBubble.swift                # 聊天气泡（区分用户/AI）
│       ├── StageProgressBar.swift             # 9 步流程进度条
│       ├── StageNodeView.swift                # 单个阶段节点
│       ├── RiskMatrixView.swift               # 风险矩阵网格
│       ├── BoundaryTableView.swift            # 项目边界表
│       ├── MissingFieldsCard.swift            # 缺失信息提示卡片
│       ├── TypingIndicatorView.swift          # AI 正在输入动画
│       ├── ReflectionCard.swift               # [NEW] 设计思维反思卡片
│       ├── ErrorBanner.swift                  # [NEW] 全局错误提示横幅
│       └── EmptyStateView.swift               # 空状态占位视图
│
├── Extensions/                                # ── 工具扩展 ──
│   ├── Color+Theme.swift                      # 统一设计语言：颜色主题
│   ├── Date+Formatting.swift                  # 日期格式化
│   └── View+Animations.swift                  # 动画修饰符
│
└── Resources/
    └── Assets.xcassets                         # 图片 & 颜色资源
```

### v3 新增文件清单（13 个）

| 文件 | 类别 | 说明 |
|------|------|------|
| Models/LearningTrace.swift | 数据模型 | 设计思维学习轨迹 |
| Models/ModelExtensions.swift | 数据模型 | 所有 Model → DTO 转换方法集中管理 |
| DTOs/LearningTraceDTO.swift | DTO | 学习轨迹传输对象 |
| Services/Protocols/LLMServiceProtocol.swift | 服务协议 | LLM 服务协议定义 |
| Services/Protocols/StructuredExtractorProtocol.swift | 服务协议 | 结构化提取协议定义 |
| Services/Mock/MockLLMService.swift | Mock | 预设回复模拟流式 |
| Services/Mock/MockStructuredExtractor.swift | Mock | 返回固定提取结果 |
| Services/Live/LiveLLMService.swift | Live | 真实 API 调用 |
| Services/Live/LiveStructuredExtractor.swift | Live | 真实 LLM 提取 |
| Services/StageDefinition.swift | 服务 | 9 阶段 ↔ 字段映射规则 |
| Services/ConversationContextBuilder.swift | 服务 | 上下文构造策略 |
| Factories/MockDataFactory.swift | 工厂 | 完整 mock 项目 |
| Factories/SeedDataFactory.swift | 工厂 | 首次启动种子数据 |
| Components/ReflectionCard.swift | UI 组件 | 设计思维反思卡片 |
| Components/ErrorBanner.swift | UI 组件 | 全局错误提示 |

---

## 二、Mock / Live 双模式服务架构

### 为什么第一阶段必须先用 Mock

1. **并行开发**：A 写 LiveLLMService 时，B 和 C 可以用 MockLLMService 同时开发 ChatViewModel 和 ChatPanel，不被 API 阻塞
2. **UI 调试**：课程演示需要稳定效果，Mock 保证每次打开 App 表现一致
3. **降级兜底**：网络断开或 API Key 缺失时，App 自动 fallback 到 Mock，不会白屏崩溃
4. **可测试性**：Mock 服务可以在 XCTest 和 SwiftUI Preview 中使用，不需要网络
5. **开发节奏**：Day 1 就能跑通"输入 → 回复 → 提取 → 进度更新"全链路

### 服务切换机制

```swift
// CoDesign_AgentApp.swift 中注入
enum ServiceMode {
    case mock
    case live
}

// 通过环境变量或 UserDefaults 控制，默认 mock
@main
struct CoDesign_AgentApp: App {
    @AppStorage("serviceMode") private var serviceModeRaw: String = "mock"

    var serviceMode: ServiceMode {
        serviceModeRaw == "live" ? .live : .mock
    }

    var llmService: LLMServiceProtocol {
        switch serviceMode {
        case .mock: return MockLLMService()
        case .live: return LiveLLMService()
        }
    }

    var extractor: StructuredExtractorProtocol {
        switch serviceMode {
        case .mock: return MockStructuredExtractor()
        case .live: return LiveStructuredExtractor(llmService: llmService)
        }
    }

    // ... 注入到 environment 或 ViewModel
}
```

### MockLLMService 设计

```swift
final class MockLLMService: LLMServiceProtocol {
    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?
    ) -> AsyncThrowingStream<String, Error> {
        // 根据 currentStage 返回预设的苏格拉底式提问
        // 用 Task.sleep + 逐字符 yield 模拟流式输出效果
        // 延迟约 1~2 秒，让用户感受到"AI 在思考"
    }
}
```

**Mock 回复库示例：**

```swift
// Mock 回复按阶段组织，每个阶段 3~5 条预设提问
static let stageResponses: [Int: [String]] = [
    1: [
        "你说的这个想法很有意思。能具体描述一下，你觉得谁最可能遇到这个问题？",
        "想象一个具体场景：这个用户在什么时候、什么地方会第一次意识到这个痛点？",
        "如果让你用一句话描述这个痛点，你会怎么说？"
    ],
    2: [
        "市面上有没有类似的产品？它们做得好和做得不好的地方分别是什么？",
        "如果用户只能记住你这个项目的一个特点，你希望是什么？"
    ],
    // ... 阶段 3~9
]
```

### MockStructuredExtractor 设计

```swift
final class MockStructuredExtractor: StructuredExtractorProtocol {
    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractedFields {
        // 模拟延迟
        try await Task.sleep(for: .milliseconds(500))

        // 从最后一条 user message 中提取关键词，生成简单的 ExtractedFields
        // 例如：用户说"面向大学生的" → targetUser = "在校大学生"
        // 返回增量字段（非 nil 表示本轮提取到）
    }
}
```

### LiveLLMService 设计

```swift
final class LiveLLMService: LLMServiceProtocol {
    private let apiKey: String?
    private let baseURL: URL
    private let session: URLSession

    init(apiKey: String? = nil, baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["LLM_API_KEY"]
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
    }

    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?
    ) -> AsyncThrowingStream<String, Error> {
        // 1. 构造 request body（含 messages、model、stream: true）
        // 2. 发起 URLSession.bytes(for:) 请求
        // 3. 逐行解析 SSE data，提取 content delta
        // 4. yield 每个 token
        // 5. 处理错误：网络失败、API Key 缺失、限流、JSON 解析失败
    }
}
```

---

## 三、SwiftData @Model 初始化策略

### 核心原则

1. **每个 @Model 类必须提供显式 init**，不依赖 SwiftData 自动合成
2. **UUID 和 Date 参数有默认值**，方便创建时省略
3. **Relationship 数组参数默认为 `[]`**
4. **Optional 字段参数默认为 `nil`**
5. **ProgressStage.status 在 Model 中用 String 存储**，DTO 中用 StageStatus enum
6. **反向关系（project / brief）不在 init 参数中出现**，由 SwiftData 在 insert 时自动维护

### 各 Model init 签名

```swift
// Project
init(
    id: UUID = UUID(),
    name: String,
    briefDescription: String = "",
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    messages: [ChatMessage] = [],
    stages: [ProgressStage] = []
)

// ChatMessage
init(
    id: UUID = UUID(),
    role: String,
    content: String,
    timestamp: Date = Date(),
    isStreaming: Bool = false
)

// DesignBrief
init(
    id: UUID = UUID(),
    lastExtractedAt: Date? = nil,
    targetUser: String? = nil,
    painPoint: String? = nil,
    useScenario: String? = nil,
    coreValue: String? = nil,
    differentiation: String? = nil,
    boundaryItems: [BoundaryItem] = [],
    mvpFeatures: String? = nil,
    technicalModules: String? = nil,
    interactionFlow: String? = nil,
    operationLogic: String? = nil,
    hardConstraints: String? = nil,
    successMetrics: [SuccessMetric] = [],
    risks: [RiskItem] = [],
    milestones: String? = nil
)

// ProgressStage
init(
    id: UUID = UUID(),
    order: Int,
    name: String,
    status: String = "notStarted",     // Model 层用 String
    completionRatio: Double = 0.0,
    lastUpdated: Date? = nil
)

// BoundaryItem
init(
    id: UUID = UUID(),
    content: String,
    isIncluded: Bool = true
)

// RiskItem
init(
    id: UUID = UUID(),
    description: String,
    probability: Int = 3,
    impact: Int = 3,
    mitigation: String? = nil
)

// SuccessMetric
init(
    id: UUID = UUID(),
    metric: String,
    target: String,
    measurement: String? = nil
)

// LearningTrace
init(
    id: UUID = UUID(),
    stageOrder: Int,
    actionType: String,          // "converge" | "diverge" | "reframe" | "boundaryShrink" | "questionChallenge"
    title: String,
    detail: String,
    timestamp: Date = Date()
)
```

### 避免的常见陷阱

| 陷阱 | 原因 | 解决方案 |
|------|------|---------|
| `@Attribute(.unique)` + 默认值缺失 | SwiftData 不会自动填充 unique | init 中 `id: UUID = UUID()` |
| 忘记 init 导致编译失败 | SwiftData 对复杂 @Model 有时无法合成 init | 手写 init，所有参数有默认值 |
| Relationship 数组初始化为 nil | SwiftData 期望数组非 nil | `= []` |
| status 用 enum 存储 | SwiftData 不直接支持 enum 持久化 | Model 用 String，DTO 用 enum，转换时做 rawValue 映射 |
| 反向关系出现在 init 参数中 | insert 后 SwiftData 自动设置 | init 不包含 project / brief 参数 |

---

## 四、StageDefinition / BriefField 映射机制

### 设计目标

把"9 个阶段对应哪些 DesignBrief 字段"从文档表格变成代码级规则定义，供 ProgressAnalyzer 和 UI 组件使用。

### StageDefinition 结构

```swift
struct StageDefinition {
    let order: Int
    let name: String
    let briefFields: [BriefField]
    let description: String            // 面向用户的阶段说明

    /// 该阶段的完成度 = 已填充字段数 / 总字段数
    func completionRatio(from snapshot: DesignBriefSnapshot) -> Double
}

/// DesignBrief 中可独立判断"是否已填充"的字段
enum BriefField: String, CaseIterable {
    // 阶段 1
    case targetUser
    case painPoint
    case useScenario
    // 阶段 2
    case coreValue
    case differentiation
    // 阶段 3
    case boundaryItems          // 通过 count > 0 判断
    // 阶段 4
    case mvpFeatures
    case technicalModules
    case interactionFlow
    // 阶段 5
    case operationLogic
    // 阶段 6
    case hardConstraints
    // 阶段 7
    case successMetrics         // 通过 count > 0 判断
    // 阶段 8
    case risks                  // 通过 count > 0 判断
    // 阶段 9
    case milestones

    /// 判断该字段在 snapshot 中是否已填充
    func isFilled(in snapshot: DesignBriefSnapshot) -> Bool
}
```

### 静态定义表

```swift
extension StageDefinition {
    static let all: [StageDefinition] = [
        StageDefinition(
            order: 1,
            name: "痛点与场景锚定",
            briefFields: [.targetUser, .painPoint, .useScenario],
            description: "明确目标用户是谁，他们遇到什么具体问题，在什么场景下发生"
        ),
        StageDefinition(
            order: 2,
            name: "差异化价值提炼",
            briefFields: [.coreValue, .differentiation],
            description: "提炼核心价值主张，明确与已有方案的差异"
        ),
        StageDefinition(
            order: 3,
            name: "项目边界划定",
            briefFields: [.boundaryItems],
            description: "明确 MVP 做什么、不做什么，划定项目边界"
        ),
        StageDefinition(
            order: 4,
            name: "功能与技术方案拆解",
            briefFields: [.mvpFeatures, .technicalModules, .interactionFlow],
            description: "拆解核心功能模块、技术选型和交互流程"
        ),
        StageDefinition(
            order: 5,
            name: "运行逻辑与规则定义",
            briefFields: [.operationLogic],
            description: "定义系统运行逻辑、异常处理和规则约束"
        ),
        StageDefinition(
            order: 6,
            name: "硬性约束设计",
            briefFields: [.hardConstraints],
            description: "明确预算、时间、硬件等不可突破的约束"
        ),
        StageDefinition(
            order: 7,
            name: "量化验收标准制定",
            briefFields: [.successMetrics],
            description: "制定可量化的验收指标和目标值"
        ),
        StageDefinition(
            order: 8,
            name: "风险识别与预案制定",
            briefFields: [.risks],
            description: "识别主要风险，制定缓解预案"
        ),
        StageDefinition(
            order: 9,
            name: "项目阶段拆分与排期",
            briefFields: [.milestones],
            description: "拆分开发阶段，制定里程碑与排期"
        ),
    ]
}
```

### ProgressAnalyzer 如何使用

```swift
struct ProgressAnalyzer: ProgressAnalyzerProtocol {
    func analyze(
        brief: DesignBriefSnapshot,
        stages: [ProgressStageSnapshot]
    ) -> [ProgressStageSnapshot] {
        return stages.map { stage in
            guard let definition = StageDefinition.all.first(where: { $0.order == stage.order }) else {
                return stage
            }
            let ratio = definition.completionRatio(from: brief)
            var newStatus = stage.status

            switch (ratio, stage.status) {
            case (0, .notStarted):
                newStatus = .notStarted
            case (0, _):
                // 之前有状态但现在字段被清空了
                newStatus = .active
            case (1.0, _):
                if stage.status != .needsReview {
                    newStatus = .completed
                }
                // needsReview 不会因为字段填充而自动恢复
            default:
                newStatus = .active
            }

            return ProgressStageSnapshot(
                order: stage.order,
                name: stage.name,
                status: newStatus,
                completionRatio: ratio
            )
        }
    }

    func missingFields(brief: DesignBriefSnapshot) -> [String] {
        // 按阶段顺序，找到第一个未完成的阶段
        // 返回该阶段中未填充的字段名称（面向用户的描述）
    }
}
```

---

## 五、conversationSummary 上下文构造策略

### 问题背景

LLM 的上下文窗口有限。随着对话变长，每次请求都发送完整消息历史会导致：
- Token 费用过高
- 超出 context window
- AI 注意力分散，追问质量下降

### 四层上下文构造策略

```swift
struct ConversationContextBuilder {
    /// 构造发送给 LLM 的完整 messages 数组
    func buildContext(
        systemPrompt: String,
        brief: DesignBriefSnapshot,
        summary: String?,                    // 历史对话摘要
        recentMessages: [ChatPayloadMessage], // 最近 N 条消息
        currentStage: ProgressStageSnapshot?
    ) -> [ChatPayloadMessage] {
        var messages: [ChatPayloadMessage] = []

        // ── 第 1 层：系统 Prompt（固定） ──
        messages.append(.system(systemPrompt))

        // ── 第 2 层：设计简报快照（结构化状态注入） ──
        let briefContext = formatBriefSnapshot(brief)
        messages.append(.system("当前项目结构化状态：\n\(briefContext)"))

        // ── 第 3 层：历史摘要（可选） ──
        if let summary, !summary.isEmpty {
            messages.append(.system("历史对话摘要：\(summary)"))
        }

        // ── 第 4 层：最近消息（滑动窗口） ──
        messages.append(contentsOf: recentMessages)

        return messages
    }
}
```

### 滑动窗口参数

| 参数 | V1 值 | 说明 |
|------|-------|------|
| recentMessages 数量 | 最近 10 条（5 轮） | 保证 AI 有足够近期上下文 |
| summary 触发阈值 | 消息总数 > 20 条 | 超过后开始生成摘要 |
| summary 更新频率 | 每 5 轮对话更新一次 | 避免频繁调用 LLM 生成摘要 |
| summary 最大长度 | 500 字 | 控制 token 消耗 |

### summary 生成方式

当消息数超过阈值时，在后台调用一次 LLM（非流式，小模型）：

```
Prompt: "请将以下对话历史压缩为 500 字以内的摘要，保留关键设计决策、用户已明确的需求、
以及尚未解决的问题。不要遗漏任何结构化的设计信息。"
```

生成的 summary 存入 `Project.conversationSummary: String?` 字段（需新增）。

### Project 模型新增字段

```swift
// Project.swift 新增
var conversationSummary: String?       // 历史对话摘要
var lastSummaryAtMessageCount: Int = 0 // 上次生成摘要时的消息数
```

### 上下文 token 预算估算

| 层级 | 预估 token |
|------|-----------|
| 系统 Prompt | ~300 |
| DesignBriefSnapshot | ~200 |
| conversationSummary | ~300 |
| 最近 10 条消息 | ~1000 |
| 预留输出空间 | ~500 |
| **合计** | **~2300** |

V1 使用这个预算完全可控。即使用户对话非常长，也不会超限。

---

## 六、错误状态与降级方案

### 错误类型枚举

```swift
enum AppError: LocalizedError {
    case apiKeyMissing
    case networkFailed(underlying: Error?)
    case rateLimited(retryAfter: TimeInterval?)
    case apiError(statusCode: Int, message: String)
    case jsonParseFailed(rawResponse: String)
    case extractionFailed(reason: String)
    case swiftDataSaveFailed(underlying: Error?)
    case contextTooLong

    var errorDescription: String? { ... }
    var recoverySuggestion: String? { ... }
}
```

### 错误处理矩阵

| 错误 | 触发条件 | UI 表现 | 降级策略 | 是否自动切换 Mock |
|------|---------|---------|---------|----------------|
| **API Key 缺失** | `LiveLLMService` 初始化时 apiKey == nil | ErrorBanner: "API Key 未配置，已切换为演示模式" | 自动降级到 MockLLMService | ✅ 自动 |
| **网络失败** | URLSession 抛出 URLError | ErrorBanner: "网络连接失败，已切换为离线模式" | 自动降级到 MockLLMService | ✅ 自动 |
| **API 限流** | HTTP 429 | ErrorBanner: "请求过于频繁，请 {N} 秒后重试" + 倒计时 | 按钮灰置 + 倒计时后可重试；期间可用 Mock | ⚠️ 提示后手动 |
| **API 错误** | HTTP 4xx/5xx（非 429） | ErrorBanner: "服务暂时不可用，已切换为演示模式" | 降级到 Mock | ✅ 自动 |
| **JSON 解析失败** | LLM 返回的 JSON 无法 decode | 静默失败 + Console 日志；不中断对话流 | 跳过本轮提取，保留原始消息；下轮重试 | ❌ 不切换 |
| **结构化提取失败** | 提取 LLM 调用本身失败 | ErrorBanner: "信息提取暂时失败，对话内容已保存" | 跳过提取，不影响对话显示 | ❌ 不切换 |
| **SwiftData 保存失败** | modelContext.save() 抛出错误 | ErrorBanner: "数据保存失败，请重启 App" | 内存中保留未保存数据；提示用户不要退出 | ❌ 不切换 |
| **上下文过长** | 构造的 messages 超出模型限制 | 自动截断最近消息 + 警告 | 强制生成 summary + 缩减 recentMessages 数量 | ❌ 不切换 |

### ErrorBanner 组件设计

```swift
struct ErrorBanner: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?         // 可选的重试按钮

    var body: some View {
        // 顶部滑入的横幅，3~5 秒后自动消失
        // 红色/黄色背景，根据错误类型区分
        // 如果有 onRetry，显示"重试"按钮
    }
}
```

### ViewModel 中的错误处理模式

```swift
@Observable
final class ChatViewModel {
    var currentError: AppError?         // 驱动 ErrorBanner
    var isUsingMock: Bool = false       // 当前是否在 Mock 模式

    func sendMessage(_ text: String) {
        // ...
        do {
            let stream = try await llmService.streamChat(...)
            for try await token in stream { ... }
        } catch {
            handleStreamError(error)
        }
    }

    private func handleStreamError(_ error: Error) {
        if let appError = error as? AppError {
            switch appError {
            case .apiKeyMissing, .networkFailed, .apiError:
                // 自动降级到 Mock
                currentError = appError
                isUsingMock = true
                // 用 MockLLMService 重新发起
            case .rateLimited:
                currentError = appError  // 显示倒计时，不自动降级
            default:
                currentError = appError  // 其他错误正常提示
            }
        }
    }
}
```

### 降级流程图

```
ChatViewModel 发起请求
    │
    ├── serviceMode == .live?
    │      │
    │      ├── YES → 尝试 LiveLLMService
    │      │          │
    │      │          ├── 成功 → 正常显示
    │      │          │
    │      │          └── 失败 → 判断错误类型
    │      │                    │
    │      │                    ├── apiKeyMissing / networkFailed / apiError
    │      │                    │   → 自动切换 MockLLMService
    │      │                    │   → ErrorBanner 提示
    │      │                    │   → 重新发起请求（Mock）
    │      │                    │
    │      │                    ├── rateLimited
    │      │                    │   → ErrorBanner 倒计时
    │      │                    │   → 不自动降级
    │      │                    │
    │      │                    └── jsonParseFailed / extractionFailed
    │      │                        → 静默处理，不影响对话
    │      │
    │      └── NO → 使用 MockLLMService（正常）
    │
    └── 最终显示结果（无论来自 Live 还是 Mock）
```

---

## 七、LearningTrace / ReflectionCard 设计

### 设计理念

这个 App 的核心价值不是"帮用户生成开题报告"，而是"训练用户的设计思维"。因此需要在关键节点让用户意识到自己完成了什么认知动作。

### LearningTrace 数据模型

```swift
@Model
final class LearningTrace {
    @Attribute(.unique) var id: UUID
    var stageOrder: Int          // 关联的阶段序号 (1~9)
    var actionType: String       // 认知动作类型（见下表）
    var title: String            // 简短标题（如"你收缩了项目边界"）
    var detail: String           // 具体描述
    var timestamp: Date

    var project: Project?        // 反向关系
}
```

### 认知动作类型

| actionType | 触发时机 | 标题模板 |
|-----------|---------|---------|
| `converge` | 从发散讨论收敛到一个明确结论 | "你完成了一次收敛思考" |
| `diverge` | 开始探索新的可能性 | "你开始了一次发散探索" |
| `reframe` | 重新定义问题（用户修改了痛点或目标用户） | "你重新定义了问题" |
| `boundaryShrink` | 明确排除了某个功能/方向 | "你收缩了项目边界" |
| `questionChallenge` | AI 追问后用户修正了自己的假设 | "你挑战了自己的假设" |
| `painToFeature` | 从用户痛点推导出具体功能 | "你把痛点转化为了功能" |
| `riskAwareness` | 首次识别出一个风险 | "你建立了风险意识" |

### 生成时机

LearningTrace 由 ProgressAnalyzer 在检测到关键状态变化时自动生成：

```swift
extension ProgressAnalyzer {
    /// 检测本轮对话是否触发了值得记录的认知动作
    func detectLearningTraces(
        previousBrief: DesignBriefSnapshot,
        currentBrief: DesignBriefSnapshot,
        messages: [ChatPayloadMessage]
    ) -> [LearningTraceDTO] {
        var traces: [LearningTraceDTO] = []

        // 用户修改了 targetUser 或 painPoint → reframe
        if previousBrief.targetUser != currentBrief.targetUser
            || previousBrief.painPoint != currentBrief.painPoint {
            traces.append(.reframe(...))
        }

        // 新增了 excludedFeatures → boundaryShrink
        let prevExcluded = previousBrief.boundaryItems.filter { !$0.isIncluded }.count
        let currExcluded = currentBrief.boundaryItems.filter { !$0.isIncluded }.count
        if currExcluded > prevExcluded {
            traces.append(.boundaryShrink(...))
        }

        // 新增了 risks → riskAwareness
        if currentBrief.risks.count > previousBrief.risks.count {
            traces.append(.riskAwareness(...))
        }

        // ... 其他判断规则

        return traces
    }
}
```

### ReflectionCard UI 组件

```swift
struct ReflectionCard: View {
    let trace: LearningTrace        // 或 LearningTraceDTO

    var body: some View {
        // 设计为对话流中插入的特殊卡片
        // 左侧图标（根据 actionType 选择 SF Symbol）
        // 标题加粗，描述正常文本
        // 背景使用浅色渐变，区别于普通聊天气泡
        // 点击可展开查看更详细的说明
    }
}
```

**UI 特点：**
- 出现在对话流中，紧跟触发它的 AI 回复之后
- 视觉上与普通消息区分（卡片样式、图标、浅色背景）
- 同时在 InsightsPanel 中有一个独立的"学习轨迹"时间线
- V1 实现基础展示，V1.5 增加展开详情和时间线视图

### V1 MVP 范围

| 功能 | V1 | V1.5 |
|------|----|------|
| LearningTrace 数据模型 | ✅ | |
| 3 种核心 actionType（converge, boundaryShrink, reframe） | ✅ | |
| ReflectionCard 基础卡片 | ✅ | |
| 对话流中插入 ReflectionCard | ✅ | |
| 全部 7 种 actionType | | ✅ |
| 学习轨迹时间线视图 | | ✅ |
| 学习轨迹导出 | | ✅ |

---

## 八、修订后的数据模型

### 模型关系总览（v3 新增 LearningTrace）

```
Project (1) ──── (N) ChatMessage
Project (1) ──── (1) DesignBrief
Project (1) ──── (9) ProgressStage
Project (1) ──── (N) LearningTrace       ← [NEW]
DesignBrief (1) ── (N) BoundaryItem
DesignBrief (1) ── (N) RiskItem
DesignBrief (1) ── (N) SuccessMetric
```

### 完整 Model 代码（v3 最终版）

#### Project.swift

```swift
import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var briefDescription: String
    var createdAt: Date
    var updatedAt: Date
    var conversationSummary: String?        // [NEW] 历史对话摘要
    var lastSummaryAtMessageCount: Int      // [NEW] 上次生成摘要时的消息数

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.project)
    var messages: [ChatMessage]

    @Relationship(deleteRule: .cascade, inverse: \DesignBrief.project)
    var brief: DesignBrief?

    @Relationship(deleteRule: .cascade, inverse: \ProgressStage.project)
    var stages: [ProgressStage]

    @Relationship(deleteRule: .cascade, inverse: \LearningTrace.project)
    var learningTraces: [LearningTrace]     // [NEW]

    init(
        id: UUID = UUID(),
        name: String,
        briefDescription: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        conversationSummary: String? = nil,
        lastSummaryAtMessageCount: Int = 0,
        messages: [ChatMessage] = [],
        stages: [ProgressStage] = [],
        learningTraces: [LearningTrace] = []
    ) {
        self.id = id
        self.name = name
        self.briefDescription = briefDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.conversationSummary = conversationSummary
        self.lastSummaryAtMessageCount = lastSummaryAtMessageCount
        self.messages = messages
        self.stages = stages
        self.learningTraces = learningTraces
    }

    var completionRate: Double {
        guard !stages.isEmpty else { return 0 }
        let total = stages.reduce(0.0) { $0 + $1.completionRatio }
        return total / Double(stages.count)
    }
}
```

#### ChatMessage.swift

```swift
import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: String              // "user" | "assistant" | "system"
    var content: String
    var timestamp: Date
    var isStreaming: Bool

    var project: Project?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}
```

#### DesignBrief.swift

```swift
import Foundation
import SwiftData

@Model
final class DesignBrief {
    @Attribute(.unique) var id: UUID
    var lastExtractedAt: Date?

    // ── 阶段 1：痛点与场景锚定 ──
    var targetUser: String?
    var painPoint: String?
    var useScenario: String?

    // ── 阶段 2：差异化价值提炼 ──
    var coreValue: String?
    var differentiation: String?

    // ── 阶段 3：项目边界划定 ──
    @Relationship(deleteRule: .cascade, inverse: \BoundaryItem.brief)
    var boundaryItems: [BoundaryItem]

    // ── 阶段 4：功能与技术方案拆解 ──
    var mvpFeatures: String?
    var technicalModules: String?
    var interactionFlow: String?

    // ── 阶段 5：运行逻辑与规则定义 ──
    var operationLogic: String?

    // ── 阶段 6：硬性约束设计 ──
    var hardConstraints: String?

    // ── 阶段 7：量化验收标准 ──
    @Relationship(deleteRule: .cascade, inverse: \SuccessMetric.brief)
    var successMetrics: [SuccessMetric]

    // ── 阶段 8：风险识别与预案 ──
    @Relationship(deleteRule: .cascade, inverse: \RiskItem.brief)
    var risks: [RiskItem]

    // ── 阶段 9：项目阶段拆分与排期 ──
    var milestones: String?

    var project: Project?

    init(
        id: UUID = UUID(),
        lastExtractedAt: Date? = nil,
        targetUser: String? = nil,
        painPoint: String? = nil,
        useScenario: String? = nil,
        coreValue: String? = nil,
        differentiation: String? = nil,
        boundaryItems: [BoundaryItem] = [],
        mvpFeatures: String? = nil,
        technicalModules: String? = nil,
        interactionFlow: String? = nil,
        operationLogic: String? = nil,
        hardConstraints: String? = nil,
        successMetrics: [SuccessMetric] = [],
        risks: [RiskItem] = [],
        milestones: String? = nil
    ) {
        self.id = id
        self.lastExtractedAt = lastExtractedAt
        self.targetUser = targetUser
        self.painPoint = painPoint
        self.useScenario = useScenario
        self.coreValue = coreValue
        self.differentiation = differentiation
        self.boundaryItems = boundaryItems
        self.mvpFeatures = mvpFeatures
        self.technicalModules = technicalModules
        self.interactionFlow = interactionFlow
        self.operationLogic = operationLogic
        self.hardConstraints = hardConstraints
        self.successMetrics = successMetrics
        self.risks = risks
        self.milestones = milestones
    }

    // ── 便捷计算属性 ──
    var includedFeatures: [BoundaryItem] {
        boundaryItems.filter { $0.isIncluded }
    }
    var excludedFeatures: [BoundaryItem] {
        boundaryItems.filter { !$0.isIncluded }
    }
}
```

#### ProgressStage.swift

```swift
import Foundation
import SwiftData

@Model
final class ProgressStage {
    @Attribute(.unique) var id: UUID
    var order: Int
    var name: String
    var status: String            // "notStarted" | "active" | "completed" | "needsReview"
    var completionRatio: Double
    var lastUpdated: Date?

    var project: Project?

    init(
        id: UUID = UUID(),
        order: Int,
        name: String,
        status: String = "notStarted",
        completionRatio: Double = 0.0,
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.order = order
        self.name = name
        self.status = status
        self.completionRatio = completionRatio
        self.lastUpdated = lastUpdated
    }

    // Model ↔ DTO 状态映射
    var stageStatusValue: StageStatus {
        get { StageStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
    }
}
```

#### BoundaryItem.swift

```swift
import Foundation
import SwiftData

@Model
final class BoundaryItem {
    @Attribute(.unique) var id: UUID
    var content: String
    var isIncluded: Bool

    var brief: DesignBrief?

    init(
        id: UUID = UUID(),
        content: String,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.content = content
        self.isIncluded = isIncluded
    }
}
```

#### RiskItem.swift

```swift
import Foundation
import SwiftData

@Model
final class RiskItem {
    @Attribute(.unique) var id: UUID
    var description: String
    var probability: Int          // 1~5
    var impact: Int               // 1~5
    var mitigation: String?

    var brief: DesignBrief?

    init(
        id: UUID = UUID(),
        description: String,
        probability: Int = 3,
        impact: Int = 3,
        mitigation: String? = nil
    ) {
        self.id = id
        self.description = description
        self.probability = probability
        self.impact = impact
        self.mitigation = mitigation
    }
}
```

#### SuccessMetric.swift

```swift
import Foundation
import SwiftData

@Model
final class SuccessMetric {
    @Attribute(.unique) var id: UUID
    var metric: String
    var target: String
    var measurement: String?

    var brief: DesignBrief?

    init(
        id: UUID = UUID(),
        metric: String,
        target: String,
        measurement: String? = nil
    ) {
        self.id = id
        self.metric = metric
        self.target = target
        self.measurement = measurement
    }
}
```

#### LearningTrace.swift [NEW]

```swift
import Foundation
import SwiftData

@Model
final class LearningTrace {
    @Attribute(.unique) var id: UUID
    var stageOrder: Int
    var actionType: String       // "converge" | "diverge" | "reframe" | "boundaryShrink" | "questionChallenge" | "painToFeature" | "riskAwareness"
    var title: String
    var detail: String
    var timestamp: Date

    var project: Project?

    init(
        id: UUID = UUID(),
        stageOrder: Int,
        actionType: String,
        title: String,
        detail: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stageOrder = stageOrder
        self.actionType = actionType
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
    }
}
```

---

## 九、MockDataFactory / SeedDataFactory

### MockDataFactory — 生成完整演示项目

```swift
struct MockDataFactory {
    /// 生成一个完整的示例项目，包含所有阶段的部分填充数据
    /// 用于：课程演示、SwiftUI Preview、调试
    static func createDemoProject(context: ModelContext) -> Project {
        // 1. 创建 Project
        let project = Project(
            name: "智能校园导航助手",
            briefDescription: "帮助大学新生在复杂校园中快速找到目的地的智能导航应用"
        )
        context.insert(project)

        // 2. 创建 DesignBrief（部分字段已填充）
        let brief = DesignBrief(
            targetUser: "大一新生，尤其是来自外地的学生",
            painPoint: "校园面积大、建筑命名混乱，新生经常找不到教室和办公室",
            useScenario: "开学第一周，新生需要在 10 分钟内从宿舍赶到陌生的教学楼",
            coreValue: "基于 AR 的室内导航，解决 GPS 在建筑内失灵的问题",
            differentiation: "不同于百度/高德地图，专注室内场景 + 校园 POI 数据",
            boundaryItems: [
                BoundaryItem(content: "AR 实时导航箭头", isIncluded: true),
                BoundaryItem(content: "校园 POI 搜索", isIncluded: true),
                BoundaryItem(content: "课表导入与自动导航", isIncluded: true),
                BoundaryItem(content: "社交功能（找同学）", isIncluded: false),
                BoundaryItem(content: "外卖配送", isIncluded: false),
            ],
            mvpFeatures: "AR 导航 + POI 搜索 + 课表导入",
            technicalModules: "ARKit + CoreLocation + 本地 SQLite POI 数据库",
            successMetrics: [
                SuccessMetric(metric: "首次导航成功率", target: "≥ 90%"),
                SuccessMetric(metric: "平均找到目的地时间", target: "≤ 5 分钟",
                              measurement: "从发起导航到到达"),
            ],
            risks: [
                RiskItem(description: "AR 在弱光环境下识别不稳定",
                         probability: 4, impact: 4,
                         mitigation: "增加 2D 地图备选方案"),
                RiskItem(description: "POI 数据采集工作量大",
                         probability: 3, impact: 5,
                         mitigation: "先覆盖主楼，后续众包"),
            ]
        )
        project.brief = brief

        // 3. 创建 9 个 ProgressStage（按填充情况设置不同状态）
        let stages = StageDefinition.all.map { def in
            ProgressStage(order: def.order, name: def.name)
        }
        project.stages = stages
        // 手动设置各阶段状态（模拟真实进度）
        stages[0].status = "completed"; stages[0].completionRatio = 1.0
        stages[1].status = "completed"; stages[1].completionRatio = 1.0
        stages[2].status = "completed"; stages[2].completionRatio = 1.0
        stages[3].status = "active";    stages[3].completionRatio = 0.67
        stages[4].status = "notStarted"
        // ... 5~8 保持 notStarted

        // 4. 创建若干 ChatMessage
        let conversation: [(String, String)] = [
            ("user", "我想做一个帮助大学生在校园里导航的应用"),
            ("assistant", "这个想法很实际！能具体说说，你觉得哪类学生最需要这个？"),
            ("user", "主要是大一新生，尤其是外地来的，对校园完全不熟悉"),
            ("assistant", "你能描述一个具体的场景吗？比如这个新生在什么情况下最着急找不到路？"),
            // ... 更多对话
        ]
        for (role, content) in conversation {
            let msg = ChatMessage(role: role, content: content)
            project.messages.append(msg)
        }

        // 5. 创建 LearningTrace
        let traces: [(Int, String, String, String)] = [
            (1, "converge", "你完成了一次收敛思考",
             "从模糊的\"校园应用\"收敛到了\"导航\"这个具体问题"),
            (1, "reframe", "你重新定义了问题",
             "从\"校园信息应用\"重新定义为\"室内导航\"问题"),
            (3, "boundaryShrink", "你收缩了项目边界",
             "排除了社交功能和外卖配送，聚焦核心导航需求"),
        ]
        for (order, type, title, detail) in traces {
            let trace = LearningTrace(
                stageOrder: order, actionType: type,
                title: title, detail: detail
            )
            project.learningTraces.append(trace)
        }

        return project
    }
}
```

### SeedDataFactory — App 首次启动

```swift
struct SeedDataFactory {
    /// App 首次启动时调用，检查是否需要生成种子数据
    static func seedIfNeeded(context: ModelContext) {
        // 检查是否已有项目
        let descriptor = FetchDescriptor<Project>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // 使用 MockDataFactory 创建演示项目
        _ = MockDataFactory.createDemoProject(context: context)
        try? context.save()
    }
}
```

**在 App 入口调用：**

```swift
// CoDesign_AgentApp.swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .onAppear {
                SeedDataFactory.seedIfNeeded(context: sharedModelContainer.mainContext)
            }
    }
    .modelContainer(sharedModelContainer)
}
```

---

## 十、修订后的核心数据流（v3 完整版）

```
用户输入消息
    │
    ▼
ChatViewModel.sendMessage(text)
    │
    ├─① 保存 ChatMessage(role: "user") → SwiftData
    │
    ├─② 构造上下文
    │   ConversationContextBuilder.buildContext(
    │     systemPrompt: PromptTemplates.system,
    │     brief: brief.toSnapshot(),
    │     summary: project.conversationSummary,
    │     recentMessages: last 10 messages → ChatPayloadMessage,
    │     currentStage: activeStage.toSnapshot()
    │   )
    │
    ├─③ 调用 LLMService.streamChat(context)
    │   │
    │   ├── 成功 → 逐 token 更新 UI
    │   │         → 流式完成 → 保存 ChatMessage(role: "assistant")
    │   │
    │   └── 失败 → handleStreamError(error)
    │               │
    │               ├── apiKeyMissing / networkFailed → 自动切 Mock，重试
    │               ├── rateLimited → ErrorBanner 倒计时
    │               └── 其他 → ErrorBanner 提示
    │
    ├─④ 调用 StructuredExtractor.extract(from:, existing:)
    │   │
    │   ├── 成功 → 得到 ExtractedFields
    │   │         → ViewModel 增量合并到 DesignBrief
    │   │         → ProgressAnalyzer.analyze() 更新阶段状态
    │   │         → ProgressAnalyzer.detectLearningTraces() 检测学习轨迹
    │   │
    │   └── 失败 → 静默跳过，不中断对话
    │
    └─⑤ 检查是否需要更新 conversationSummary
           消息数 > 20 且距上次摘要 > 10 条
           → 后台生成摘要 → 存入 project.conversationSummary
```

---

## 十一、Model ↔ DTO 转换（ModelExtensions.swift）

```swift
// ModelExtensions.swift — 集中管理所有转换方法

extension ChatMessage {
    func toPayload() -> ChatPayloadMessage {
        ChatPayloadMessage(role: role, content: content)
    }
}

extension DesignBrief {
    func toSnapshot() -> DesignBriefSnapshot {
        DesignBriefSnapshot(
            targetUser: targetUser,
            painPoint: painPoint,
            useScenario: useScenario,
            coreValue: coreValue,
            differentiation: differentiation,
            boundaryItems: boundaryItems.map { $0.toDTO() },
            mvpFeatures: mvpFeatures,
            technicalModules: technicalModules,
            interactionFlow: interactionFlow,
            operationLogic: operationLogic,
            hardConstraints: hardConstraints,
            successMetrics: successMetrics.map { $0.toDTO() },
            risks: risks.map { $0.toDTO() },
            milestones: milestones
        )
    }
}

extension ProgressStage {
    func toSnapshot() -> ProgressStageSnapshot {
        ProgressStageSnapshot(
            order: order,
            name: name,
            status: stageStatusValue,
            completionRatio: completionRatio
        )
    }
}

extension BoundaryItem {
    func toDTO() -> BoundaryItemDTO {
        BoundaryItemDTO(id: id, content: content, isIncluded: isIncluded)
    }
}

extension RiskItem {
    func toDTO() -> RiskItemDTO {
        RiskItemDTO(id: id, description: description,
                    probability: probability, impact: impact,
                    mitigation: mitigation)
    }
}

extension SuccessMetric {
    func toDTO() -> SuccessMetricDTO {
        SuccessMetricDTO(id: id, metric: metric,
                         target: target, measurement: measurement)
    }
}

extension LearningTrace {
    func toDTO() -> LearningTraceDTO {
        LearningTraceDTO(id: id, stageOrder: stageOrder,
                         actionType: actionType, title: title,
                         detail: detail, timestamp: timestamp)
    }
}

// ── 反向写入：ExtractedFields → DesignBrief ──
extension DesignBrief {
    func applyExtracted(_ fields: ExtractedFields, context: ModelContext) {
        if let v = fields.targetUser { targetUser = v }
        if let v = fields.painPoint { painPoint = v }
        if let v = fields.useScenario { useScenario = v }
        if let v = fields.coreValue { coreValue = v }
        if let v = fields.differentiation { differentiation = v }
        if let v = fields.mvpFeatures { mvpFeatures = v }
        if let v = fields.technicalModules { technicalModules = v }
        if let v = fields.interactionFlow { interactionFlow = v }
        if let v = fields.operationLogic { operationLogic = v }
        if let v = fields.hardConstraints { hardConstraints = v }
        if let v = fields.milestones { milestones = v }

        // boundaryItems：替换式更新（清空旧的，插入新的）
        if let items = fields.boundaryItems {
            boundaryItems.forEach { context.delete($0) }
            boundaryItems = items.map {
                let bi = BoundaryItem(content: $0.content, isIncluded: $0.isIncluded)
                context.insert(bi)
                return bi
            }
        }

        // risks / successMetrics：同上替换式更新
        // ...

        lastExtractedAt = Date()
    }
}
```

---

## 十二、第一阶段开发顺序（v3 精修版）

### 核心原则：每完成一步，都能在 Xcode 编译运行

| 步骤 | 产出 | 编译验证 | 预计耗时 |
|------|------|---------|---------|
| **Step 1** | Models 全部 8 个 + ModelExtensions + 注册 ModelContainer | ✅ App 能启动，看到空列表 | 0.5 天 |
| **Step 2** | DTOs 全部 8 个 + StageDefinition + BriefField | ✅ 纯 struct，无依赖 | 0.5 天 |
| **Step 3** | MockDataFactory + SeedDataFactory | ✅ App 启动能看到 demo 项目 | 0.5 天 |
| **Step 4** | Color+Theme + Extensions | ✅ 纯工具代码 | 0.5 天 |
| **Step 5** | Protocols + MockLLMService + MockStructuredExtractor | ✅ Mock 可独立编译 | 0.5 天 |
| **Step 6** | ProjectListView + ProjectListViewModel | ✅ 能展示 mock 项目列表 | 0.5 天 |
| **Step 7** | NewProjectView + NewProjectViewModel | ✅ 能新建项目 + 自动初始化 9 阶段 | 0.5 天 |
| **Step 8** | ProjectDetailView 骨架 + Tab 切换 | ✅ 能进入详情页（内容为空） | 0.5 天 |
| **Step 9** | ChatPanel + MessageBubble + ChatViewModel（Mock 模式） | ✅ **关键里程碑：能聊天，有 AI 回复** | 1 天 |
| **Step 10** | StructuredExtractor (Mock) + ProgressAnalyzer | ✅ 聊天后阶段状态自动更新 | 0.5 天 |
| **Step 11** | ProgressPanel + StageNodeView + MissingFieldsCard | ✅ 9 步进度可视化 | 1 天 |
| **Step 12** | PromptTemplates + LiveLLMService | ✅ 切换到 live 模式可真实对话 | 1 天 |
| **Step 13** | LiveStructuredExtractor + 联调 | ✅ 真实 LLM 提取 + 进度更新 | 1 天 |
| **Step 14** | InsightsPanel + BoundaryTableView + RiskMatrixView | ✅ 洞察面板可视化 | 1 天 |
| **Step 15** | ReportExporter + ExportPanel | ✅ 导出 Markdown | 0.5 天 |
| **Step 16** | ReflectionCard + LearningTrace 触发逻辑 | ✅ 反思卡片出现 | 0.5 天 |
| **Step 17** | ConversationContextBuilder + summary 生成 | ✅ 长对话不超限 | 0.5 天 |
| **Step 18** | 错误处理 + ErrorBanner + 降级流程 | ✅ 断网/无 Key 自动降级 | 0.5 天 |
| **Step 19** | TypingIndicatorView + EmptyStateView + 动画打磨 | ✅ UI 完善 | 0.5 天 |

### 三人并行排期（2 周 10 个工作日）

#### 第 1 周

| 天 | A（数据 + API） | B（AI 逻辑） | C（界面） |
|----|----------------|-------------|----------|
| D1 | Step 1-2: Models + DTOs + StageDefinition | PromptTemplates 系统 Prompt 初稿 | Step 4: Color+Theme + 设计语言 |
| D2 | Step 3: MockDataFactory + SeedDataFactory | MockLLMService 预设回复库 | Step 6-7: 列表页 + 新建页 |
| D3 | Step 5: Protocols + Mock 服务 | StructuredExtractorProtocol + Mock 实现 | Step 8: 详情页骨架 + Tab |
| D4 | Step 12: LiveLLMService 流式 | PromptTemplates 提取 Prompt + 调试 | Step 9: ChatPanel + 聊天气泡 |
| D5 | LiveLLMService 错误处理 + 网络兜底 | MockStructuredExtractor 联调 | ChatPanel 完善 + 打字动画 |

> **D5 结束验证点：** 打开 App → 看到 demo 项目 → 新建项目 → 进入聊天 → Mock 模式能正常对话和提取

#### 第 2 周

| 天 | A（数据 + API） | B（AI 逻辑） | C（界面） |
|----|----------------|-------------|----------|
| D6 | Step 17: ConversationContextBuilder | Step 10: ProgressAnalyzer + LearningTrace 检测 | Step 11: 进度面板 + 阶段节点 |
| D7 | LiveStructuredExtractor 联调 | LiveStructuredExtractor 联调 | MissingFieldsCard + 状态渲染 |
| D8 | Step 15: ReportExporter | 回溯逻辑 + needsReview 传播 | Step 14: 洞察面板 + 边界表 + 风险矩阵 |
| D9 | Step 18: 错误处理 + 降级流程 | Prompt 优化 + 边界 case | Step 16: ReflectionCard |
| D10 | 全面联调 + bug 修复 | 全面联调 + 演示数据优化 | 动画打磨 + ExportPanel |

> **D10 结束验证点：** 完整闭环可演示，Live/Mock 无缝切换，断网自动降级

### 里程碑检查点

| 时间点 | 必须跑通的场景 | 验证方式 |
|--------|---------------|---------|
| D2 结束 | App 启动 → 看到 demo 项目（SeedData） | 在模拟器运行 |
| D3 结束 | 创建新项目 → 列表中出现 | 新建 + 返回列表 |
| D5 结束 | 进入聊天 → Mock AI 流式回复 → 阶段状态变化 | 发 3 条消息观察 |
| D7 结束 | Live 模式真实对话 → 自动提取 → 进度更新 | 切换 live 模式测试 |
| D10 结束 | 完整闭环 + 降级 + 演示数据 + 导出 | 课程演示彩排 |

---

## 十三、关于 SwiftData 的设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 持久化方案 | SwiftData | 项目模板已引入；iOS 17+ 原生支持；`@Model` + `@Query` 与 SwiftUI 深度集成 |
| 消息存储 | 每个 ChatMessage 独立持久化 | 方便 `@Query` 按 project 过滤 + 按时间排序 |
| 复杂字段 | V1 用 `String?`（JSON 文本），子表仅用于需要可视化的 | 平衡开发成本与后续扩展性 |
| 删除策略 | 全部 `cascade` | Project 是聚合根，删除项目时子实体自动清理 |
| 并发 | SwiftData 的 `ModelActor` | 结构化提取等耗时操作放在后台 actor 中执行 |
| Service 解耦 | DTO struct 隔离 | Service 层不持有 ModelContext，可独立测试 |
| Model init | 手写 init，所有参数有默认值 | 避免 SwiftData 合成 init 不稳定 |
| enum 存储 | Model 用 String，DTO 用 enum | SwiftData 对 enum 持久化支持有限，String 更稳定 |
| 种子数据 | MockDataFactory 生成 | 启动即有内容，演示和调试体验更好 |

---

## 十四、v3 相对 v2 的变化汇总

| 维度 | v2 | v3 |
|------|----|----|
| 服务模式 | 只有 Protocol + 一个实现 | Mock/Live 双模式 + 自动降级 |
| Model 初始化 | 未明确 init 策略 | 手写 init，所有参数有默认值 |
| 种子数据 | 无 | MockDataFactory + SeedDataFactory |
| 阶段映射 | 文档表格 | StageDefinition + BriefField 代码级定义 |
| 上下文管理 | 未设计 | conversationSummary + 四层上下文策略 |
| 错误处理 | 未设计 | 8 种错误类型 + 降级矩阵 + ErrorBanner |
| 学习追踪 | 无 | LearningTrace + ReflectionCard |
| 开发节奏 | 按周排 | 按 step 排，每步可编译运行 |
| 新增文件数 | — | +13 个文件 |
| 新增 Model | — | +1 (LearningTrace) |
| Project 字段 | — | +2 (conversationSummary, lastSummaryAtMessageCount, learningTraces) |
