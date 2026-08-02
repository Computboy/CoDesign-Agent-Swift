# CoDesign Agent

CoDesign Agent v1.2.0 是一个面向设计类、创新类课程项目的 AI 设计澄清工作台。它不是替用户一键生成方案，而是通过有依据的苏格拉底式追问、9 阶段设计框架、结构化 Design Brief、开放式思维树、Apple Pencil 批注和完整项目包，把模糊想法逐步转化为清晰、可执行、可评审、可继续的设计过程。

![CoDesign Agent 思维树](tree.png)

## 四项核心创新

### 1. 苏格拉底式隐式三段提问与资源卡依据

CoDesign Agent 不以“快速给出完整答案”为目标，而是先判断当前最值得推进的设计变量，每轮只提出一个能够改变设计决策的问题。系统内部使用隐式三段结构：

```text
设计线索 Clue
→ 一个关键问题 Question
→ 可追溯的方法依据 Basis
```

这三段不是界面上的机械模板。默认回复通常只有两个自然的短段落：第一段内化线索或当前判断，第二段提出一个开放问题；依据则通过问题节点上的资源卡呈现。用户因此既不会被“线索 / 提问 / 依据”标题打断，又可以随时查看 AI 为什么这样问。

每个问题在生成前都要通过资格审查：回答必须能够影响目标用户、场景、功能范围、技术路径、交互流程、边界取舍、验收标准、Stage 状态或学习轨迹。用户卡住时，系统先提供理解线索，再继续追问，不会立即抛出选项替用户完成判断。

资源推荐结合当前 Stage、缺失字段、用户回答和问题类型，从本地方法卡、论文卡、案例卡、设计原则与课程框架中选择依据。资源卡绑定到实际使用它的问题节点，记录核心观点、适用原因、使用方式和引用信息，使“问题”与“依据”保持可解释关系。

### 2. 思维树可视化开放式设计流程

CoDesign Agent 把线性聊天记录转化为一棵可生长、可分叉、可回溯的设计推理树。树中同时保留项目种子、关键问题、设计判断、已确认字段、阶段封口、当前主线、历史方案和资源依据。

九个 Stage 提供专业覆盖范围，但不是强制用户顺序填表的封闭流程。进行中的 Stage 保持开放，完成后才生成封口卡片；用户修改旧答案时，系统保留旧分支，并让新判断沿当前分支继续生长。用户可以拖动和缩放画布、双击节点查看详情、长按编辑，并直接展开或收纳问题节点后的资源卡。

思维树让用户、教师和团队成员不只看到“最后决定了什么”，还能够理解“为什么这样决定”“哪些方案曾被放弃”“哪些依据支撑了这次追问”。它是设计过程本身，而不是结果页上的装饰图。

### 3. Apple Pencil 思维树批注，提升 iPad 端移动应用竞争力

思维树批注基于 PencilKit，并支持 Apple 内置的仅 Apple Pencil 书写策略：Apple Pencil 用于写字、圈画与标记，支持单双指手势。用户不需要在“书写模式”和“浏览模式”之间频繁切换，也能减少手指松开时误画或误触节点的问题。

批注支持系统绘图工具、撤销、重做、清空和文本说明，并与问题节点、资源卡和 Stage 建立语义锚点。布局变化后，批注能够重新投影到对应内容；资源卡收纳时批注在固定相对位置渐隐，重新展开时渐显，避免跟随卡片逐帧移动造成性能延迟。

这项能力把 AI 对话、可视化推理和自然手写放进同一个 iPad 工作现场，服务课堂评图、设计工作坊、移动讨论和个人深度思考，是 CoDesign Agent 提升 iPad 端移动应用竞争力的重要差异点。

### 4. `.codesign` 整体状态导入导出，支持协作与思维共享

PDF 和 Markdown 只能保存静态成果，`.codesign` 则保存能够重新打开的设计现场。项目包包含项目与 Stage 状态、完整 Design Brief、思维树节点和父子关系、当前与历史分支、决策路径、资源卡、学习轨迹、Apple Pencil 笔迹、文本批注和语义锚点。

接收者可以先只读预览，再将项目包导入为新项目。应用会重建阶段、Brief、思维结构和批注关系，使其他成员或另一台设备能够沿着原有上下文继续提问、修正和批注，而不是只接收到一份缺少过程的结论文件。

```text
导出完整状态
→ 通过文件或云盘分享
→ 预览设计内容
→ 导入为新项目
→ 恢复思维现场并继续设计
```

当前 `.codesign` 提供文件式、异步协作，不等同于实时多人编辑；它的核心价值是让团队交换的不只是结果，也包括判断依据、历史分支和可继续的思维上下文。

## 功能概览

- **9 阶段澄清框架**：覆盖痛点场景、差异化价值、项目边界、功能技术拆解、运行规则、硬性约束、验收标准、风险预案和里程碑。
- **结构化 Design Brief**：从自然语言对话中持续抽取项目字段，并支持用户确认、编辑和标记不准确。
- **问题节点资源卡组**：资源依据收纳在所属问题后方，可通过直接拖动展开或收回。
- **学习轨迹记录**：沉淀用户完成的关键设计思维动作，适合课程过程记录与反思。
- **成果看板与作品档案**：提供成熟度、澄清地图、MVP 边界、风险矩阵、设计旅程、证据墙和 Brief 海报。
- **多格式输出**：支持中文 PDF 交接简报、Markdown、JSON 和 `.codesign` 交互项目包。
- **Mock / Live 双模式**：默认离线可用，也可接入 OpenAI-compatible API。

## 产品流程

```text
创建项目
→ 输入模糊想法
→ 查看设计线索，回答一个有依据的 AI 澄清问题
→ 查看并修正 Design Brief 字段
→ 阶段进度与思维树同步更新
→ 展开资源卡检查依据，使用 Apple Pencil 批注
→ 查看成果看板与作品档案
→ 导出报告，或通过 .codesign 分享并继续完整设计状态
```

## 运行环境

- iOS / iPadOS 26.4+
- macOS 26.3+（Designed for iPad / macOS 构建）
- 支持 SwiftUI 与 SwiftData 的 Xcode
- 可选：OpenAI-compatible API Key，用于 Live 模式

## 快速开始

克隆仓库并用 Xcode 打开：

```bash
git clone <repository-url>
cd CoDesign-Agent
open CoDesign-Agent.xcodeproj
```

构建 iOS Simulator 版本：

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

运行测试：

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

构建 macOS 版本：

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=macOS' \
  build
```

## API 配置

应用默认使用 **Mock 模式**，无需 API Key，适合离线演示、课堂展示和开发调试。

如需调用真实模型，可在应用设置页切换到 **Live 模式** 并填写：

- API Key
- Base URL
- Model
- Thinking Type

设置页提供 **测试 API Key**。测试成功后，应用会保存配置并自动切换到 Live 模式。

也可以使用环境变量配置：

```text
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-flash
LLM_THINKING_TYPE=disabled
```

配置优先级：

1. 应用设置页写入的 UserDefaults
2. `LLM_*` 环境变量
3. 旧版兼容的 `DEEPSEEK_*` 环境变量
4. 内置默认配置

## 支持的 API 类型

API 客户端兼容 OpenAI Chat Completions 风格接口，可接入：

- DeepSeek
- 阿里云百炼 / DashScope
- 其他 OpenAI-compatible chat completion endpoint

DeepSeek 示例：

```text
Base URL: https://api.deepseek.com
Model: deepseek-v4-flash
Thinking Type: disabled
```

百炼 / DashScope 示例：

```text
Base URL: https://dashscope.aliyuncs.com/compatible-mode/v1
Model: qwen-plus
Thinking Type: 不发送
```

## 导出格式

| 格式 | 适合用途 |
|---|---|
| PDF | 提交、评审、归档和对外展示 |
| Markdown | 继续编辑，同步到 Notion / 飞书 / GitHub / PRD |
| JSON | 备份、调试和未来数据迁移 |
| `.codesign` | 保存可重新打开的项目包，包含 Stage、Design Brief、思维树、回溯分支、资源依据、学习轨迹与批注 |

`.codesign` 文件可以从首页导入，支持只读预览，也可以导入为新项目。

## 文档

- [v1.2.0 产品说明](docs/v1.2.0-product-spec.md)
- [v1.1.0 产品说明](docs/v1.1.0-product-spec.md)
- [v1.0 应用说明](docs/v1.0-app-guide.md)
- [产品愿景与设计原则](docs/product-brief.md)
- [v0.8 说明文档](docs/v0.8-release-notes.md)
- [v0.5 资源脚手架与阶段连线思维树](docs/v0.5-resource-scaffold-and-transition-tree.md)
- [v0.4 思维发散树](docs/v0.4-thinking-tree.md)
- [v0.2 Live API 集成规格](docs/v0.2-spec.md)
- [使用说明书](docs/Instruction-Navigator.md)

## 测试

默认测试路径使用 Mock 模式，不依赖外部 API：

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Live 模式测试需要有效 API Key 和兼容接口。

## 版本

当前产品文档目标版本：**v1.2.0**。

v1.2.0 代表应用已经形成从有依据的隐式苏格拉底式追问、结构化 Brief 抽取、开放式思维树、问题节点资源卡、Apple Pencil 原生批注，到 `.codesign` 完整状态协作与多格式交接的产品闭环。

## License

由 GitHub/Computboy 开发，本项目仅用于课程学习与展示。
