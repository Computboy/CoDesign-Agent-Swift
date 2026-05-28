# CoDesign Agent

苏格拉底式设计思维训练 iOS App，帮助设计类学生通过 AI 引导对话，将模糊的项目创意转化为清晰的设计方案。

## 产品理念

**框而不死，活而不乱** —— 不是机械填表工具，也不是普通聊天机器人，而是通过苏格拉底式追问训练用户的设计思维。

### 三层架构

- **底层刚性规则框架**：9 阶段设计流程（痛点锚定 → 差异化价值 → 项目边界 → 功能拆解 → 运行逻辑 → 硬性约束 → 验收标准 → 风险预案 → 阶段排期）
- **上层 LLM 柔性对话**：AI 通过追问引导思考，而非直接给答案
- **中间结构化提取层**：从自由对话中自动提取 15+ 个结构化字段

## 核心功能

- 🤖 **AI 苏格拉底式对话**：流式输出，自然追问
- 📊 **9 阶段进度可视化**：实时追踪设计思维成熟度
- 🎯 **结构化信息提取**：自动从对话中提取项目要素
- 📋 **项目边界表**：明确 MVP 范围
- ⚠️ **风险矩阵**：识别与预案
- 📈 **设计成熟度分析**：量化评估
- 🔄 **Mock/Live 双模式**：支持离线开发和真实 API 集成

## 技术栈

- **SwiftUI** - UI 框架
- **SwiftData** - 本地数据持久化
- **MVVM 架构** - 清晰的关注点分离
- **OpenAI-compatible API** - 支持 DeepSeek、DashScope 等

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

# macOS (Designed for iPad)
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=macOS' \
  build
```

或直接在 Xcode 中打开 `CoDesign-Agent.xcodeproj`，按 `Cmd+R` 运行。

### 配置 API（Live 模式）

#### 方式 1：App 内设置（推荐）

1. 启动 App
2. 点击项目列表页的 ⚙️ 设置按钮
3. 选择 "Live（真实 API）" 模式
4. 填入 API 配置：

**百炼（DashScope）**:
```
API Key: sk-你的百炼密钥
Base URL: https://dashscope.aliyuncs.com/compatible-mode/v1
Model: qwen-plus / qwen-turbo / qwen-max
Thinking Type: 不发送
```

**DeepSeek**:
```
API Key: sk-你的 DeepSeek 密钥
Base URL: https://api.deepseek.com
Model: deepseek-v4-flash
Thinking Type: disabled
```

#### 方式 2：环境变量

在 Xcode Scheme 中设置：
```
LLM_API_KEY=sk-你的密钥
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-flash
LLM_THINKING_TYPE=disabled
```

## 项目结构

```
CoDesign-Agent/
├── Models/              # SwiftData 数据模型
├── ViewModels/          # 业务逻辑层
├── Views/               # SwiftUI 视图
│   ├── ProjectList/     # 项目列表页
│   ├── ProjectDetail/   # 项目详情页
│   ├── Components/      # 自定义组件
│   └── Settings/        # API 设置页
├── Services/            # 服务层
│   ├── Protocols/       # 服务协议
│   ├── Mock/            # Mock 实现（离线模式）
│   ├── Live/            # Live 实现（真实 API）
│   ├── API/             # OpenAI-compatible 客户端
│   └── Prompts/         # LLM Prompt 模板
├── DTOs/                # 数据传输对象
└── Extensions/          # Swift 扩展

docs/
├── product-brief.md     # 产品愿景与设计原则
├── v0.1-mvp-spec.md     # MVP 技术规格
├── v0.2-spec.md         # Live API 集成规格
└── v0.2.1-release-notes.md  # 最新版本说明
```

## 核心概念

### Service Mode

- **Mock 模式**（默认）：使用预设回复，无需 API，适合开发和演示
- **Live 模式**：调用真实 LLM API，适合实际使用

切换方式：设置页或 `UserDefaults.standard.set("live", forKey: "serviceMode")`

### 9 阶段设计流程

1. **痛点与场景锚定** - 明确用户、痛点、使用场景
2. **差异化价值提炼** - 核心价值与竞品差异
3. **项目边界划定** - MVP 范围与排除项
4. **功能与技术方案拆解** - 功能模块、技术选型、交互流程
5. **运行逻辑与规则定义** - 业务规则、异常处理
6. **硬性约束设计** - 时间、预算、技术限制
7. **量化验收标准制定** - 可衡量的成功指标
8. **风险识别与预案制定** - 风险评估与缓解策略
9. **项目阶段拆分与排期** - 里程碑与时间规划

### 结构化提取字段

AI 从对话中自动提取：
- `targetUser` - 目标用户
- `painPoint` - 核心痛点
- `useScenario` - 使用场景
- `coreValue` - 核心价值
- `differentiation` - 差异化
- `boundaryItems` - 项目边界
- `mvpFeatures` - MVP 功能
- `technicalModules` - 技术模块
- `interactionFlow` - 交互流程
- `operationLogic` - 运行逻辑
- `hardConstraints` - 硬性约束
- `successMetrics` - 验收标准
- `risks` - 风险项
- `milestones` - 里程碑

## 测试

```bash
# 运行单元测试
xcodebuild test \
  -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 文档

- [产品愿景与设计原则](docs/product-brief.md)
- [MVP 技术规格 (v0.1)](docs/v0.1-mvp-spec.md)
- [Live API 集成规格 (v0.2)](docs/v0.2-spec.md)
- [最新版本说明 (v0.2.1)](docs/v0.2.1-release-notes.md)

## 开发注意事项

- **禁止硬编码 API Key**：始终使用环境变量或 UserDefaults
- **Fallback 机制**：Live 服务失败时自动降级到 Mock
- **平台兼容性**：部分 UI 修饰符仅支持 iOS（如 `.textInputAutocapitalization`），使用 `#if os(iOS)` 保护
- **SwiftData 迁移**：修改数据模型时注意版本迁移

## 版本历史

- **v0.2.1** (2026-05-29) - API 配置泛化、设置页、Markdown 渲染、键盘交互优化
- **v0.2** - Live API 集成、流式对话、结构化提取
- **v0.1** - MVP 核心闭环、Mock 模式、9 阶段流程

## 课程背景

本项目为《信息与交互设计技术》课程大作业，展示完整的 iOS App 开发能力：
- SwiftUI 界面开发
- 本地数据持久化（SwiftData）
- 网络 API 集成
- 自定义组件与动画
- MVVM 架构模式
- 文档与任务拆分

## License

Course Project - 仅供课程作业使用
