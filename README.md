# CoDesign Agent

面向设计类 / 创新类课程项目的 iOS 智能 Agent 应用。通过苏格拉底式追问，帮助学生从模糊的项目想法出发，逐步澄清痛点、目标用户、使用场景、核心价值、MVP 功能与验收标准，并将这一过程可视化为阶段进度、设计产物与学习轨迹。

## 项目定位

在设计类课程项目中，学生经常遇到的问题不是"不会做"，而是"还没有想清楚要做什么"。

CoDesign Agent 关注的是项目早期的任务澄清过程：

- 用户输入一个模糊的项目想法
- AI 通过苏格拉底式问题持续追问
- 系统从对话中提取结构化设计产物
- 项目阶段进度随思考推进而更新
- 用户在洞察页看到自己的设计思维轨迹

它不是一个简单的聊天机器人，也不是自动生成开题报告的工具，而是一个帮助学生训练设计思维的交互式 Agent。

## 产品理念

**框而不死，活而不乱** —— 不是机械填表工具，也不是普通聊天机器人，而是通过苏格拉底式追问训练用户的设计思维。

### 三层架构

- **底层刚性规则框架**：9 阶段设计流程，定义设计思维推进路径
- **上层 LLM 柔性对话**：AI 通过追问引导思考，而非直接给答案
- **中间结构化提取层**：从自由对话中自动提取 15+ 个结构化字段

## 核心功能

### 项目列表

- 项目卡片展示：名称、摘要、当前阶段、完成进度、探索状态
- 搜索、新建项目、设置入口
- iPad / 宽屏环境下自动适配多列 Grid 布局

### 项目详情页

四个主要 Tab：

| Tab | 功能 |
|-----|------|
| **工作台** | 阶段导轨 + 当前澄清卡片 + 快捷操作 + 用户输入区 |
| **对话** | AI 流式追问，Markdown 渲染 |
| **进度** | 9 阶段进度可视化，每个阶段展示关联字段的完成情况 |
| **洞察** | 设计简报摘要 + 学习轨迹反思卡片 |

### 苏格拉底式追问

AI 不直接替用户给出方案，而是通过连续追问帮助用户思考：

- 谁是你的目标用户？
- 他们在什么场景下遇到问题？
- 如果不解决，最坏的结果是什么？
- 最小可行版本应该包含哪些功能？

### 结构化设计产物

系统从对话中逐步提取并确认 15+ 个设计字段：

- 目标用户、核心痛点、使用场景
- 核心价值、差异化分析
- 项目边界（做什么 / 不做什么）
- MVP 功能、技术模块、交互流程
- 运行逻辑、硬性约束
- 验收标准、风险预案、里程碑

### 可编辑洞察卡片（v0.3）

- **右滑**确认字段正确（绿色状态条）
- **左滑**标记不准确（橙色状态条）
- **点击编辑**手动修正字段内容
- 未提取字段仅显示"手动填写"入口，不展示无意义操作按钮

### 学习轨迹与反思卡片

当用户完成关键思考动作（重新定义问题、收敛思考、收缩边界）时，系统自动生成 Reflection Card，并根据所在阶段显示差异化文案，避免重复。

## 9 阶段设计流程

| 阶段 | 名称 | 核心产出 |
|------|------|---------|
| 1 | 痛点与场景锚定 | 目标用户、痛点、使用场景 |
| 2 | 差异化价值提炼 | 核心价值、差异化分析 |
| 3 | 项目边界划定 | MVP 范围与排除项 |
| 4 | 功能与技术方案拆解 | 功能模块、技术选型、交互流程 |
| 5 | 运行逻辑与规则定义 | 业务规则、异常处理 |
| 6 | 硬性约束设计 | 时间、预算、技术限制 |
| 7 | 量化验收标准制定 | 可衡量的成功指标 |
| 8 | 风险识别与预案制定 | 风险评估与缓解策略 |
| 9 | 项目阶段拆分与排期 | 里程碑与时间规划 |

## 技术栈

- **SwiftUI** — UI 框架
- **SwiftData** — 本地数据持久化
- **MVVM + Service 三层架构** — View / ViewModel / Service 清晰分离
- **Protocol-based Service Layer** — Mock / Live 双模式，协议驱动
- **OpenAI-compatible API** — 支持 DeepSeek、DashScope 等兼容服务
- **目标平台** — iOS 17.0+ / macOS 14.0+（Designed for iPad）

## 快速开始

### 环境要求

- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

### 构建与运行

```bash
# iOS Simulator
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# macOS（Designed for iPad）
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=macOS' \
  build

# 运行测试
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

或直接在 Xcode 中打开 `CoDesign-Agent.xcodeproj`，按 `Cmd+R` 运行。

### 配置 API（Live 模式）

**方式 1：App 内设置（推荐）**

1. 启动 App → 点击项目列表页 ⚙️ 设置
2. 选择 "Live（真实 API）" 模式
3. 填入 API 配置

百炼（DashScope）示例：
```
API Key: sk-你的百炼密钥
Base URL: https://dashscope.aliyuncs.com/compatible-mode/v1
Model: qwen-plus
Thinking Type: 不发送
```

DeepSeek 示例：
```
API Key: sk-你的 DeepSeek 密钥
Base URL: https://api.deepseek.com
Model: deepseek-v4-flash
Thinking Type: disabled
```

**方式 2：环境变量**

在 Xcode Scheme 中设置：
```
LLM_API_KEY=sk-你的密钥
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-flash
LLM_THINKING_TYPE=disabled
```

配置优先级：UserDefaults（设置页）> 环境变量 > 旧版兼容变量 > 默认值

## 项目结构

```text
CoDesign-Agent/
├── Models/                      # SwiftData 数据模型
│   ├── Project.swift            # 根实体
│   ├── DesignBrief.swift        # 15+ 结构化字段
│   ├── ProgressStage.swift      # 9 阶段进度
│   ├── ChatMessage.swift        # 对话消息
│   ├── LearningTrace.swift      # 学习轨迹
│   ├── RiskItem.swift           # 风险项
│   ├── SuccessMetric.swift      # 验收指标
│   ├── BoundaryItem.swift       # 项目边界项
│   └── ModelExtensions.swift
├── ViewModels/                  # MVVM 业务逻辑层
│   ├── ChatViewModel.swift              # 对话 + 流式输出
│   ├── NewProjectViewModel.swift        # 创建项目
│   ├── ProjectDetailViewModel.swift     # 详情页状态 + Tab 定义
│   └── ProjectListViewModel.swift       # 列表页
├── Views/                       # SwiftUI 视图
│   ├── DesignSystem/            # v0.3 统一设计系统
│   │   ├── CoDesignTheme.swift          # 排版 / 间距 / 阴影 / 动画
│   │   ├── CoDesignButton.swift         # 统一按钮（Primary / Secondary / Ghost / Small）
│   │   ├── CoDesignCard.swift           # 卡片容器（Normal / Elevated / Highlighted / Bordered）
│   │   ├── CoDesignStatusBadge.swift    # 胶囊形状态标签
│   │   ├── CoDesignStagePill.swift      # 阶段胶囊导航
│   │   ├── CoDesignSectionHeader.swift
│   │   └── CoDesignFlowLayout.swift
│   ├── NewProject/              # 新建项目（Design Seed）
│   │   └── NewProjectView.swift
│   ├── ProjectList/             # 项目列表页
│   │   ├── ProjectListView.swift        # 主容器 + Grid 布局
│   │   ├── ProjectCard.swift            # 项目卡片
│   │   └── ProjectEmptyStateView.swift
│   ├── ProjectDetail/           # 项目详情 + 工作台
│   │   ├── ProjectDetailView.swift      # 主容器（Tab 切换）
│   │   ├── ClarificationWorkspaceView.swift  # 澄清工作台
│   │   ├── WorkspaceHeader.swift
│   │   ├── StageRail.swift              # 9 阶段水平导轨
│   │   ├── CurrentClarificationCard.swift    # 当前澄清卡片 + 快捷操作
│   │   ├── AnswerComposer.swift         # 回答输入区
│   │   ├── InsightCardsPanel.swift      # 可交互洞察卡片列表
│   │   ├── EditableInsightCard.swift    # 单字段卡片（滑动 / 编辑 / 确认）
│   │   ├── InsightFieldEditSheet.swift  # 字段编辑弹窗
│   │   ├── ProcessLogDisclosure.swift   # 可折叠过程记录
│   │   ├── ChatPanel.swift              # 传统聊天视图
│   │   ├── InsightsPanel.swift          # 设计简报 + 学习轨迹
│   │   └── ProgressPanel.swift          # 进度面板
│   ├── Components/              # 通用组件
│   │   ├── MessageBubble.swift
│   │   ├── InlineToast.swift
│   │   ├── ReflectionCard.swift
│   │   ├── StageNodeView.swift
│   │   ├── StageExplanationPopover.swift
│   │   └── TypingIndicatorView.swift
│   └── Settings/                # API 设置页
│       └── APISettingsView.swift
├── Services/                    # 服务层
│   ├── Protocols/               # 服务协议
│   │   ├── LLMServiceProtocol.swift
│   │   └── StructuredExtractorProtocol.swift
│   ├── Mock/                    # Mock 实现（离线开发 / 演示）
│   │   ├── MockLLMService.swift
│   │   └── MockStructuredExtractor.swift
│   ├── Live/                    # Live 实现（真实 API）
│   │   ├── LiveLLMService.swift
│   │   └── LiveStructuredExtractor.swift
│   ├── API/                     # OpenAI-compatible 客户端
│   │   ├── LLMAPIClient.swift
│   │   ├── LLMAPIConfig.swift
│   │   ├── ChatCompletionRequest.swift
│   │   ├── ChatCompletionResponse.swift
│   │   └── APIError.swift
│   ├── Prompts/                 # LLM Prompt 模板
│   │   ├── SocraticPromptTemplates.swift
│   │   └── ExtractionPromptTemplates.swift
│   ├── ProgressAnalyzer.swift
│   └── StageDefinition.swift    # 9 阶段静态定义 + 思考问题
├── DTOs/                        # 数据传输对象
├── Factories/                   # 数据工厂（MockData / SeedData）
└── Extensions/                  # Swift 扩展
    └── Color+Theme.swift        # 颜色 Token + 圆角 / 间距基础值

docs/
├── product-brief.md
├── v0.1-mvp-spec.md
├── v0.2-spec.md
├── v0.2.1-release-notes.md
└── v0.3-duetui-design-goals-and-flow.md
```

## 架构说明

### Service Layer

协议驱动的服务层，Mock / Live 双模式：

- **Mock 模式**（默认）：使用预设回复，无需 API，适合开发和演示
- **Live 模式**：调用真实 LLM API，适合实际使用

切换方式：设置页或 `UserDefaults.standard.set("live", forKey: "serviceMode")`

Live 服务失败时自动降级到 Mock：

```swift
do {
    return try await liveService.call()
} catch {
    print("[Service] Live failed, fallback to Mock: \(error)")
    return try await mockService.call()
}
```

### CoDesign 设计系统（v0.3）

统一的设计 Token 和组件库：

| 组件 | 用途 |
|------|------|
| `CoDesignButton` | Primary / Secondary / Ghost 三种样式，支持 Loading 和 Disabled |
| `CoDesignSmallButton` | 紧凑按钮（32pt），用于行内操作 |
| `CoDesignCard` | Normal / Elevated / Highlighted / Bordered 四种卡片风格 |
| `CoDesignStatusBadge` | 胶囊形状态标签（Complete / Active / Warning / Info / Locked / Partial） |
| `CoDesignStagePill` | 9 阶段胶囊导航 |
| `CoDesignFlowLayout` | 自动换行的 Chip 布局 |

设计 Token：
- **Typography** — 8 级字体规格（LargeTitle → CaptionMono）
- **Spacing** — 6 级间距（4 / 8 / 12 / 20 / 32 / 48）
- **Shadow** — 3 级阴影（Card / Elevated / Focus），统一轻量化
- **Corner Radius** — 3 级圆角（Small 12 / Medium 20 / Large 24）
- **Animation** — 统一动画曲线（Quick / Standard / Slow / Spring）

## 开发约定

- **禁止硬编码 API Key**：始终使用环境变量或 UserDefaults
- **Fallback 机制**：Live 服务失败时自动降级到 Mock
- **设计系统优先**：新 UI 使用 DesignSystem 组件，避免裸 `Button` + `.background()`
- **按钮单层背景**：`CoDesignSmallButton` 自带背景，外层不再套背景修饰符
- **`.buttonStyle(.plain)`**：所有自定义 Button 组件必须设置 `.buttonStyle(.plain)` 去除系统默认边框
- **平台兼容性**：iOS-only 修饰符（如 `.textInputAutocapitalization`）使用 `#if os(iOS)` 保护
- **SwiftData 迁移**：修改数据模型时注意版本迁移

## 项目亮点

### 从"聊天"转向"思维训练"

重点不是让 AI 给答案，而是通过追问让用户自己逐步澄清问题。

### 从"结果生成"转向"过程可视化"

系统不仅展示最终设计产物，也展示用户在思考过程中完成了哪些认知动作（重新定义问题、收敛思考、收缩边界）。

### 从"通用 AI 助手"转向"设计课程场景"

针对设计类 / 创新类课程项目，9 阶段流程对应设计思维方法论，而非泛用聊天或通用效率工具。

### Mock-first 开发策略

优先保证核心交互闭环可运行，再逐步接入真实 AI 服务，降低开发风险和 API 费用。


## 版本历史

| 版本 | 时间 | 内容 |
|------|------|------|
| v0.3.2 | 2026-06 | 工作台结构性布局修复：wide layout 保留单一页面级滚动但隐藏滚动指示器，移除三栏独立滚动条；移除中间顶部 AIContextNotice；AI 回复文本撑满卡片宽度并固定回复区域高度；发送输入框移入“当前澄清”卡片并置于快捷操作上方；发送按钮使用 `.buttonStyle(.plain)` 避免默认灰色背景叠加；去重 ProcessLogDisclosure。 |
| v0.3.1 | 2026-05 | UI polish：去除调试文字、空卡片按钮优化、ReflectionCard 按阶段差异化、项目列表宽屏 Grid 布局、统一圆角阴影 |
| v0.3 | 2026-05 | 澄清工作台、CoDesign 设计系统、可编辑洞察卡片（滑动手势）、过程记录、快捷操作 |
| v0.2.1 | — | API 配置泛化、设置页、Markdown 渲染、键盘交互优化 |
| v0.2 | — | Live API 集成、流式对话、结构化提取 |
| v0.1 | — | MVP 核心闭环、Mock 模式、9 阶段流程 |

## 文档

- [产品愿景与设计原则](docs/product-brief.md)
- [MVP 技术规格 (v0.1)](docs/v0.1-mvp-spec.md)
- [Live API 集成规格 (v0.2)](docs/v0.2-spec.md)
- [Duet UI 设计目标与流程 (v0.3)](docs/v0.3-duetui-design-goals-and-flow.md)
- [工作台布局结构修复说明 (v0.3.2)](docs/v0.3.2-layout-structure-notes.md)
- [最新版本说明 (v0.3.1)](#版本历史)

## License

由GitHub/Computboy开发，本项目仅用于课程学习与展示。
