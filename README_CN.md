# CoDesign Agent

> **An AI-native design clarification workspace for iPad — helping users form decisions instead of generating answers for them.**  
> 面向开放式设计项目的人–AI 协同工作台：让每一次追问、判断、依据、回溯与批注都成为可保存的设计过程。

<p align="center">
  <a href="README.md">English Version</a>
</p>

![Platform](https://img.shields.io/badge/Platform-iPadOS%20%7C%20iOS%20%7C%20macOS-111111)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-F05138)
![SwiftData](https://img.shields.io/badge/Persistence-SwiftData-0A84FF)
![PencilKit](https://img.shields.io/badge/iPad-PencilKit-8E8E93)
![AI](https://img.shields.io/badge/AI-OpenAI--compatible-10A37F)
![Version](https://img.shields.io/badge/version-v1.2.0-5C73D6)

CoDesign Agent v1.2.0 是一个面向设计类、创新类课程与开放式项目的 **AI 设计澄清工作台**。

CoDesign 将大语言模型嵌入一条可解释、可回溯、可批注、可迁移的设计流程：从模糊想法出发，通过有依据的苏格拉底式追问逐步形成结构化设计简报（Design Brief），并将问题、判断、历史分支、资源依据与 Apple Pencil 批注统一沉淀为可继续工作的项目状态。

## 产品界面

<p align="center">
  <img src="attachments/main-interface.png" alt="包含思维树、澄清面板与阶段导航的 CoDesign Agent 主工作台" width="82%">
</p>

iPad 主工作台将当前思维树、AI 澄清问题、设计依据与九阶段进度集中呈现，让用户能在对话、推理结构和项目状态之间自然切换，同时保留完整上下文。

---

## Why CoDesign

开放式设计项目真正困难的部分，往往不是“想不到功能”，而是：

- 目标用户、核心场景与真实痛点始终没有被定义清楚；
- 普通 Chatbot 过早给出完整方案，用户跳过了问题定义与取舍过程；
- 方法论与参考资料散落在文档里，却无法解释“为什么这一轮要问这个问题”；
- 线性聊天无法表达方案回溯、历史分支和阶段性判断；
- iPad 端常被当作桌面界面的缩小版，缺乏原生书写与移动评图体验；
- 项目导出后只剩静态结果，完整设计上下文无法跨设备、跨成员继续。

CoDesign Agent 的目标不是“让 AI 替用户设计”，而是：

> **让 AI 帮助用户把项目想清楚，并把“如何形成这个判断”完整保留下来。**

---

## Core Features

### 1. 有依据的苏格拉底式 AI 追问

每轮 AI 不追求输出更多内容，而是识别当前最值得推进的设计变量，只提出一个足以影响设计决策的问题。

内部采用隐式三段结构：

```text
Clue
→ Question
→ Basis
```

- **Clue**：指出当前方案中的缺口、矛盾或隐含假设；
- **Question**：提出一个能真正改变 Design Brief / Stage / 设计判断的开放问题；
- **Basis**：从本地方法卡、论文卡、案例卡与设计原则中提供可追溯依据。

用户侧默认不会看到机械的“三段标题”。线索被内化进自然语言，方法依据则绑定到具体问题节点上的资源卡。

---

### 2. 开放式 Thinking Tree：把 AI 对话转成设计推理结构

传统 AI 对话只能留下时间顺序；CoDesign Agent 将它投影为一棵可以生长、分叉和回溯的 **Thinking Tree**：

- 项目初始想法；
- AI 关键问题与用户回答；
- 当前有效设计主线；
- 回溯后的历史方案；
- Design Brief 已确认字段；
- Stage 封口节点；
- 与问题绑定的资源依据；
- Apple Pencil 笔迹与文本批注。

进行中的 Stage 不会被强行“封口”。只有阶段真正完成后，系统才在当前有效叶节点上生成 Stage Completion。  
当用户修改旧答案时，原方案不会被覆盖，而是保留为历史分支，新判断沿当前分支继续生长。

---

### 3. iPad 原生 Apple Pencil 批注

批注能力基于 **PencilKit**，并针对 iPad 交互处理了“书写”和“画布导航”之间的输入冲突：

- Apple Pencil：书写、圈画、标记、补充连线；
- 单指：继续平移思维树；
- 双指：继续缩放画布；
- 支持系统绘图工具、撤销、重做、清空；
- 笔迹与文本批注随项目持久化。

批注不是简单保存屏幕坐标。节点、资源卡或 Stage 重新布局时，系统基于**语义锚点**重新投影批注，使笔迹能够跟随“内容”而不是跟随某一帧 UI。

---

### 4. `.codesign`：可恢复的完整设计状态包

PDF / Markdown 适合阅读与提交，但只能保存静态结果。
`.codesign` 用于保存一个可以重新打开并继续工作的设计现场，包括：

- Project / Stage 状态；
- 完整 Design Brief；
- Thinking Tree 节点、父子关系与分支；
- 当前主线与历史方案；
- 资源卡与学习轨迹；
- Apple Pencil 笔迹；
- 文本批注与语义锚点；
- 画布与阶段状态；
- schema 兼容与迁移信息。

```text
Export project state
→ Share file
→ Read-only preview
→ Import as a new project
→ Rebuild context
→ Continue reasoning / annotation / iteration
```

`.codesign` 当前定位为**文件式异步协作**，而不是实时多人编辑。

---

## Technical Highlights

这个项目不仅是一个 AI 产品原型，也包含一套完整的 iOS / iPadOS 工程实践。

### Cross-platform SwiftUI Application

- 使用 **SwiftUI** 构建 iPadOS / iOS / macOS 统一界面；
- 以 iPad 作为核心交互终端，针对横屏工作台、触控、Apple Pencil 做专门适配；
- 同一产品状态在桌面与移动设备之间保持一致的逻辑模型。

### Local-first State Management with SwiftData

项目、对话、Design Brief、Stage、Thinking Tree、学习轨迹与批注使用 **SwiftData** 本地持久化。

应用关闭、重启后，用户仍可继续原项目，不依赖在线会话重新恢复上下文。

### Structured AI Pipeline

CoDesign Agent 不是简单的：

```text
Prompt → LLM → Text
```

而是由每次有效回答驱动多个产品状态同步更新：

1. 对话上下文；
2. Design Brief 候选字段；
3. 用户确认后的结构化状态；
4. Stage 完成度；
5. Thinking Tree；
6. 学习轨迹；
7. 导出状态。

这使 AI 输出从“聊天文本”转化为真正可计算、可保存、可继续的产品状态。

### Mock / Live Dual-mode AI Service

- **Mock Mode**：无需 API Key，可离线运行，适合演示、调试与稳定测试；
- **Live Mode**：支持 OpenAI-compatible Chat Completions；
- 可配置 `API Key / Base URL / Model / Thinking Type`；
- 设置页提供 API 连通性检查，减少真实演示时的配置失败。

### OpenAI-compatible Model Layer

当前客户端兼容 OpenAI Chat Completions 风格接口，可接入：

- DeepSeek；
- 阿里云百炼 / DashScope；
- 其他兼容 OpenAI API 协议的模型服务。

AI Provider 与产品逻辑解耦，使模型可以替换，而不需要重写核心交互流程。

### Semantic Annotation Anchoring

Apple Pencil 批注不仅是 Drawing Data：

- 批注与问题节点 / 资源卡 / Stage 建立语义关系；
- UI 重新布局后重新投影；
- 资源卡收纳时批注渐隐，重新展开后恢复；
- 连续书写采用延迟保存，减少高频持久化带来的性能开销。

### Versioned Project Serialization

`.codesign` 支持 `1.0 / 1.1 / 1.2` schema：

- 导入前只读预览；
- 导入为新项目，不覆盖本地已有数据；
- 导入时重新映射节点标识；
- 重建父子关系与批注语义锚点；
- 为未来版本迁移保留兼容路径。

---

## Tech Stack

| Layer | Technology | Usage |
|---|---|---|
| UI | SwiftUI | iOS / iPadOS / macOS interface |
| Persistence | SwiftData | Project, Brief, Stage, Tree, Trace, Annotation |
| Handwriting | PencilKit | Apple Pencil drawing and annotation |
| AI | OpenAI-compatible Chat Completions | Live clarification and structured generation |
| Offline AI | Mock Service | Demo, test and offline workflow |
| Structured State | Design Brief + Stage Model | Convert conversation into explicit project state |
| Visualization | Custom Thinking Tree | Branching, rollback and resource-node interaction |
| Serialization | `.codesign` | Full project state import / export |
| Output | PDF / Markdown / JSON | Submission, editing, debug and backup |
| Build & Test | Xcode / `xcodebuild` | Simulator, macOS build and automated test path |

---

## Architecture at a Glance

```text
┌──────────────────────────────────────────────┐
│                  SwiftUI UI                  │
│ Home · Workspace · Brief · Tree · Portfolio  │
└─────────────────────┬────────────────────────┘
                      │
┌─────────────────────▼────────────────────────┐
│              Product State Layer             │
│ Project · Stage · Brief · Tree · Trace       │
└──────────────┬─────────────────┬─────────────┘
               │                 │
┌──────────────▼───────┐ ┌───────▼─────────────┐
│      AI Service      │ │  Annotation / Input │
│ Mock / Live / API    │ │ PencilKit + Gestures│
└──────────────┬───────┘ └───────┬─────────────┘
               │                 │
┌──────────────▼─────────────────▼─────────────┐
│             SwiftData Persistence            │
└──────────────┬───────────────────────────────┘
               │
┌──────────────▼───────────────────────────────┐
│  PDF · Markdown · JSON · .codesign Export    │
└──────────────────────────────────────────────┘
```

---

## Product Workflow

![CoDesign Agent 从模糊想法到可共享设计状态的完整工作流程](attachments/app-workflow.png)

整个流程在人类判断与 AI 辅助之间交替推进：模糊想法经过有依据的阶段化追问，逐步转化为经用户确认的设计判断，并同步更新 Design Brief、Stage 进度与思维树；最终结果可以继续审阅、批注、导出或共享。

CoDesign 使用九个 Stage 覆盖开放式项目从问题定义到项目计划的完整范围：

| Stage | Focus |
|---|---|
| 1 | 痛点与场景锚定 |
| 2 | 差异化价值提炼 |
| 3 | 项目边界划定 |
| 4 | 功能与技术方案拆解 |
| 5 | 运行逻辑与规则定义 |
| 6 | 硬性约束设计 |
| 7 | 量化验收标准制定 |
| 8 | 风险识别与预案制定 |
| 9 | 项目阶段拆分与排期 |

---

## Output Formats

| Format | Purpose |
|---|---|
| PDF | 提交、评审、归档 |
| Markdown | 二次编辑、协作文档 |
| JSON | 调试、备份、数据迁移 |
| `.codesign` | 完整项目状态、异步协作、跨设备继续 |

---

## Runtime Requirements

- iOS / iPadOS 26.4+
- macOS 26.3+
- Xcode with SwiftUI / SwiftData support
- Optional: OpenAI-compatible API Key for Live Mode

---

## Quick Start

```bash
git clone https://github.com/Computboy/CoDesign-Agent-Swift.git
cd CoDesign-Agent-Swift
open CoDesign-Agent.xcodeproj
```

Build for iOS Simulator:

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Run tests:

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Build macOS:

```bash
xcodebuild -scheme CoDesign-Agent \
  -destination 'platform=macOS' \
  build
```

---

## API Configuration

默认使用 **Mock Mode**，无需 API Key。切换到 Live Mode 后，可以在应用设置中配置：

```text
API Key
Base URL
Model
Thinking Type
```

也支持环境变量：

```text
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-flash
LLM_THINKING_TYPE=disabled
```

配置优先级：

1. App Settings / UserDefaults
2. `LLM_*`
3. Legacy `DEEPSEEK_*`
4. Built-in defaults

---

## Documentation

- [v1.2.0 产品说明](docs/v1.2.0-product-spec.md)
- [v1.1.0 产品说明](docs/v1.1.0-product-spec.md)
- [v1.0 应用说明](docs/v1.0-app-guide.md)
- [产品愿景与设计原则](docs/product-brief.md)
- [使用说明书](docs/Instruction-Navigator.md)

---

## Engineering Notes

这个项目中比较值得继续深入的技术问题包括：

- 超深 Thinking Tree 下的虚拟化与布局性能；
- Apple Pencil 批注在复杂节点重排后的稳定语义映射；
- `.codesign` schema 的向前 / 向后兼容与版本迁移；
- 多人实时编辑、分支合并与冲突解决；
- 可插拔 LLM Provider 与本地模型支持；
- 团队自定义 Resource Library 与检索增强。

---

## Award

🏆 **2026 中国高校计算机大赛 · 移动应用创新赛 · 华东赛区二等奖（省级二等奖）**

项目从产品定义、交互设计、SwiftUI / iPadOS 实现、AI 能力接入、状态持久化，到最终真机演示与竞赛交付，形成了完整的端到端开发闭环。

---

## Version

Current release: **v1.2.0**

> **用有依据的追问推动设计，用开放思维树保存推理，用 Apple Pencil 留下人的判断，再用 `.codesign` 把完整设计现场交给下一位参与者。**

---

## License

This repository is currently intended for learning, academic showcase and portfolio purposes.
