# CoDesign Agent

CoDesign Agent 是一个面向设计类、创新类课程项目的 iOS 智能导航助手。它通过苏格拉底式追问，帮助学生从模糊想法出发，逐步澄清目标用户、核心痛点、使用场景、项目边界、MVP 功能、验收标准与风险预案，并把这一过程可视化为阶段进度、设计产物和学习轨迹。

它不是普通聊天机器人，也不是“一键生成开题报告”的工具。它更像一位设计思维训练伙伴：不急着替用户给答案，而是帮助用户把自己的项目想清楚。

## 产品定位

设计类课程项目里，常见瓶颈往往不是“不会做”，而是“还没有想清楚要做什么”。CoDesign Agent 聚焦项目早期的任务澄清过程：

- 用户输入一个初始设计想法
- AI 通过连续追问引导用户补充关键判断
- 系统从对话中抽取结构化 Design Brief 字段
- 9 阶段进度随思考推进自动更新
- 用户可以确认、修正、导出自己的设计简报
- 学习轨迹记录用户完成了哪些设计思维动作

核心理念是：**框而不死，活而不乱**。

## 当前体验

v0.3.3 之后，Project Detail 的默认工作台采用 DuetUI-style 三栏结构：

| 区域 | 作用 |
|------|------|
| 左侧阶段流程 | 展示 9 阶段设计流程、当前阶段与进度 |
| 中间协作焦点 | 展示当前 AI 追问、回答输入区、快捷操作、学习轨迹和过程记录 |
| 右侧 Design Brief | 展示可确认、可编辑、可标记不准确的结构化字段 |

视觉上，v0.3.3 收敛了卡片圆角、描边、阴影与按钮层级：正常状态更安静，异常状态更突出，滚动能力保留但滚动条默认隐藏。

## 核心功能

### 1. 9 阶段设计流程

| 阶段 | 名称 | 核心产出 |
|------|------|----------|
| 1 | 痛点与场景锚定 | 目标用户、痛点、使用场景 |
| 2 | 差异化价值提炼 | 核心价值、差异化分析 |
| 3 | 项目边界划定 | MVP 范围与排除项 |
| 4 | 功能与技术方案拆解 | 功能模块、技术选型、交互流程 |
| 5 | 运行逻辑与规则定义 | 业务规则、异常处理 |
| 6 | 硬性约束设计 | 时间、预算、技术限制 |
| 7 | 量化验收标准制定 | 可衡量的成功指标 |
| 8 | 风险识别与预案制定 | 风险评估与缓解策略 |
| 9 | 项目阶段拆分与排期 | 里程碑与时间规划 |

### 2. 苏格拉底式追问

AI 不直接替用户决定方案，而是围绕当前阶段提出问题，例如：

- 谁是真正的目标用户？
- 他们在哪个具体场景下遇到问题？
- 哪些功能是 MVP 必须做的，哪些暂时不做？
- 如果项目成功，应该如何量化验收？
- 最可能失败的风险是什么？

### 3. 结构化 Design Brief

系统会从自由对话中逐步抽取 15+ 个字段，包括：

- 目标用户、核心痛点、使用场景
- 核心价值、差异化分析
- 项目边界、MVP 功能、技术模块
- 交互流程、运行逻辑、硬性约束
- 验收标准、风险预案、里程碑

右侧字段卡支持：

- 点击编辑手动修正字段内容
- 点击确认字段正确
- 点击 warning 图标标记字段不准确
- 左右滑动快捷确认或标记

### 4. 学习轨迹

当用户完成关键思考动作时，系统会生成学习轨迹。例如：

- 你锚定了痛点场景
- 你收缩了项目范围
- 你明确了验收标准
- 你识别了核心风险

这部分用于帮助学生看见自己的设计思维过程，而不只是最终产物。

## 技术栈

- SwiftUI
- SwiftData
- MVVM
- Protocol-based Service Layer
- Mock / Live 双服务模式
- OpenAI-compatible API Client
- iOS 17.0+ / macOS 14.0+（Designed for iPad）

## 快速开始

### 环境要求

- Xcode 26.4（当前验证版本）
- iOS Simulator 26.4
- Swift 5

### 构建

当前推荐使用固定 simulator UUID，避免按名称匹配失败：

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,id=7E83E99D-AA67-488D-B2CC-F1F1DF77EAF8' \
  build
```

macOS 目标：

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=macOS' \
  build
```

通用 iOS Simulator 目标：

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'generic/platform=iOS Simulator' \
  build
```

查看可用 destination：

```bash
xcodebuild -scheme CoDesign-Agent -showdestinations
```

### API 配置

默认使用 Mock 模式，无需 API Key，适合演示和开发。

Live 模式可在 App 设置页中配置：

1. 进入项目列表页
2. 点击右上角设置按钮
3. 切换 Service Mode 为 Live
4. 填入 API Key、Base URL、Model 和 Thinking Type

配置优先级：

1. UserDefaults（设置页）
2. `LLM_*` 环境变量
3. `DEEPSEEK_*` 旧版兼容变量
4. 默认配置

示例：

```text
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-flash
LLM_THINKING_TYPE=disabled
```

## 项目结构

```text
CoDesign-Agent/
├── Models/                  # SwiftData 数据模型
├── DTOs/                    # API 与快照传输对象
├── ViewModels/              # MVVM 状态与业务编排
├── Services/
│   ├── Protocols/           # LLM / Extractor 协议
│   ├── Mock/                # 离线开发与演示
│   ├── Live/                # 真实 API 集成
│   ├── API/                 # OpenAI-compatible 客户端
│   └── Prompts/             # 对话与抽取 Prompt
├── Views/
│   ├── DesignSystem/        # 统一设计 token 与组件
│   ├── ProjectList/         # 项目列表
│   ├── NewProject/          # 新建项目
│   ├── ProjectDetail/       # 三栏工作台、聊天、进度、洞察
│   ├── Components/          # 通用 UI 组件
│   └── Settings/            # API 设置页
├── Factories/               # Mock / Seed 数据
└── Extensions/              # 颜色与基础主题扩展
```

## 架构说明

### 三层智能架构

- **刚性规则层**：9 阶段流程定义推进路径
- **LLM 对话层**：根据当前阶段进行苏格拉底式追问
- **结构化抽取层**：从自由对话中提取 Design Brief JSON 字段

### 服务层模式

服务通过协议抽象，支持 Mock 与 Live 实现：

- `LLMServiceProtocol`
- `StructuredExtractorProtocol`
- `MockLLMService`
- `LiveLLMService`
- `MockStructuredExtractor`
- `LiveStructuredExtractor`

Live 服务失败时应 fallback 到 Mock，保证演示和开发环境稳定。

## 开发约定

- 不硬编码 API Key
- 新 UI 优先使用 `Views/DesignSystem/` 中的 token 和组件
- 自定义按钮使用 `.buttonStyle(.plain)`
- iOS-only API 使用平台条件保护
- 修改 SwiftData 模型时注意迁移影响
- Project Detail 的三栏结构是当前主交互骨架，UI polish 不应改变核心业务流

## 版本历史

| 版本 | 时间 | 内容 |
|------|------|------|
| v0.3.3 | 2026-06-01 | 滚动条隐藏兜底、ProjectDetail UI polish、Design Brief 卡片降噪、完成态 Brief Snapshot、阶段流程连接线、学习轨迹文案具体化、固定 iPhone 17 Pro simulator UUID 构建验证 |
| v0.3.2 | 2026-06-01 | 工作台结构性布局修复：保留单一页面级滚动，移除三栏独立滚动条，固定 AI 回复区域高度，输入框进入当前澄清卡片 |
| v0.3.1 | 2026-05 | UI polish、ReflectionCard 阶段差异化、项目列表宽屏 Grid、统一圆角阴影 |
| v0.3 | 2026-05 | DuetUI-style 澄清工作台、设计系统、可编辑洞察卡片、过程记录、快捷操作 |
| v0.2.1 | 2026-05 | API 配置泛化、设置页、Markdown 渲染、键盘交互优化 |
| v0.2 | 2026-05 | Live API 集成、流式对话、结构化提取 |
| v0.1 | 2026-05 | MVP 核心闭环、Mock 模式、9 阶段流程 |

## 文档

- [产品愿景与设计原则](docs/product-brief.md)
- [MVP 技术规格 v0.1](docs/v0.1-mvp-spec.md)
- [Live API 集成规格 v0.2](docs/v0.2-spec.md)
- [v0.2.1 发布说明](docs/v0.2.1-release-notes.md)
- [DuetUI 设计目标与流程 v0.3](docs/v0.3-duetui-design-goals-and-flow.md)
- [工作台布局结构修复说明 v0.3.2](docs/v0.3.2-layout-structure-notes.md)
- [v0.3.3 工作报告](docs/v0.3.3-report.md)
- [使用说明书](docs/Instruction-Navigator.md)

## License

由 GitHub/Computboy 开发，本项目仅用于课程学习与展示。
