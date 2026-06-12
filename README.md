# CoDesign Agent

CoDesign Agent 是一个面向设计类、创新类课程项目的 iOS 设计澄清工作台。它通过苏格拉底式 AI 追问、9 阶段澄清流程、结构化 Design Brief 抽取、思维树可视化、学习轨迹记录和多格式导出，帮助用户把模糊项目想法逐步转化为清晰、可执行、可评审的 AI 产品设计简报。

![CoDesign Agent 思维树](tree.png)

## 功能亮点

- **苏格拉底式设计对话**：AI 不急着替用户下结论，而是围绕当前设计阶段提出聚焦问题。
- **9 阶段澄清框架**：覆盖痛点场景、差异化价值、项目边界、功能技术拆解、运行规则、硬性约束、验收标准、风险预案和里程碑。
- **结构化 Design Brief**：从自然语言对话中持续抽取项目字段，并支持用户确认、编辑和标记不准确。
- **思维树可视化**：展示问题链、设计判断、已填字段、当前主线和回溯后的旧分支。
- **资源线索脚手架**：当用户卡住时，基于本地设计方法卡提供“线索 + 追问”。
- **学习轨迹记录**：沉淀用户完成的关键设计思维动作，适合课程过程记录与反思。
- **成果看板与作品档案**：提供成熟度、澄清地图、MVP 边界、风险矩阵、设计旅程、证据墙和 Brief 海报等展示材料。
- **报告导出与项目包导入**：支持 PDF、Markdown、JSON 和 `.codesign` 交互项目包。
- **Mock / Live 双模式**：默认离线可用，也可接入 OpenAI-compatible API。

## 产品流程

```text
创建项目
→ 输入模糊想法
→ 回答 AI 澄清问题
→ 查看并修正 Design Brief 字段
→ 阶段进度与思维树同步更新
→ 查看成果看板与作品档案
→ 导出报告或 .codesign 项目包
```

## 运行环境

- iOS 17.0+
- macOS 14.0+（Designed for iPad / macOS 构建）
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
| `.codesign` | 保存可重新打开的项目包，包含思维树、决策路径、Design Brief、回溯分支和资源线索 |

`.codesign` 文件可以从首页导入，支持只读预览，也可以导入为新项目。

## 文档

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

当前产品文档目标版本：**v1.0**。

v1.0 代表应用已经形成从项目创建、AI 引导澄清、结构化 Brief 抽取、思维树可视化、作品档案复盘到多格式导出的完整闭环。

## License

由 GitHub/Computboy 开发，本项目仅用于课程学习与展示。
