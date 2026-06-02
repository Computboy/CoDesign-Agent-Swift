import Foundation

enum ResourceLibrary {
    static let all: [ResourceCard] = [
        ResourceCard(
            id: "reflective-practice-schon",
            title: "Reflective Practice / Schon",
            type: .paper,
            relatedStages: [9],
            tags: ["反思", "学习轨迹", "复盘", "过程", "portfolio"],
            summary: "设计师常常在行动中发现问题、修正判断，而不是先得到完整答案。它适合解释设计过程中的反思与迭代。",
            whyRelevant: "你的作品档案需要呈现思考轨迹，而不只是最后方案。",
            howToUse: "在汇报中用它说明：每次重构问题、收敛边界和补充证据，都是设计能力的一部分。"
        ),
        ResourceCard(
            id: "wicked-problems",
            title: "Wicked Problems / Rittel & Webber",
            type: .paper,
            relatedStages: [1, 8],
            tags: ["模糊问题", "复杂性", "风险", "假设", "痛点"],
            summary: "复杂设计问题往往没有一次性正确的定义，需要在讨论与试探中逐步澄清。",
            whyRelevant: "当前阶段需要接受问题的模糊性，并把它转化为可讨论的场景。",
            howToUse: "把你的项目中最模糊的地方写成问题清单，再逐个转成可验证假设。"
        ),
        ResourceCard(
            id: "socratic-questioning",
            title: "Socratic Questioning",
            type: .courseFramework,
            relatedStages: [4],
            tags: ["追问", "概念", "澄清", "为什么", "苏格拉底"],
            summary: "苏格拉底式追问通过连续提问帮助学习者发现隐藏前提，而不是直接给出答案。",
            whyRelevant: "当方案概念还不清晰时，追问能帮助你区分事实、假设和价值判断。",
            howToUse: "针对一个核心概念连续问三次“为什么”和“依据是什么”，记录答案变化。"
        ),
        ResourceCard(
            id: "double-diamond",
            title: "Design Thinking / Double Diamond",
            type: .courseFramework,
            relatedStages: [2, 9],
            tags: ["发散", "收敛", "价值", "流程", "下一步"],
            summary: "Double Diamond 用发散与收敛解释从发现问题到形成方案的过程。",
            whyRelevant: "它能帮助你判断当前是在扩展可能性，还是在收束设计方向。",
            howToUse: "把已有信息放到“发现、定义、发展、交付”四步中，找出下一步缺口。"
        ),
        ResourceCard(
            id: "how-might-we",
            title: "How Might We",
            type: .method,
            relatedStages: [1],
            tags: ["问题陈述", "痛点", "机会点", "场景"],
            summary: "How Might We 把痛点改写成开放但有边界的设计机会。",
            whyRelevant: "阶段 1 需要把模糊抱怨转化为可继续探索的问题。",
            howToUse: "用“我们如何帮助[用户]在[场景]中解决[痛点]”重写项目问题。"
        ),
        ResourceCard(
            id: "persona",
            title: "Persona / 用户画像",
            type: .method,
            relatedStages: [5],
            tags: ["用户", "目标用户", "画像", "需求", "行为"],
            summary: "用户画像用具体角色承载需求、动机、行为和限制，避免设计对象过于泛化。",
            whyRelevant: "如果目标用户还宽泛，画像能让后续功能判断更稳定。",
            howToUse: "写出一个代表性用户的目标、典型场景、阻碍和一句真实口吻的需求。"
        ),
        ResourceCard(
            id: "journey-map",
            title: "User Journey Map",
            type: .method,
            relatedStages: [1, 5],
            tags: ["旅程", "场景", "用户", "触点", "痛点"],
            summary: "用户旅程图按时间线梳理用户行为、触点、情绪和痛点。",
            whyRelevant: "它能把抽象痛点落到具体时刻，帮助你发现关键干预点。",
            howToUse: "列出使用前、使用中、使用后三个阶段，并标出最痛的一个瞬间。"
        ),
        ResourceCard(
            id: "design-criteria",
            title: "Design Criteria / 评价标准",
            type: .method,
            relatedStages: [2, 6],
            tags: ["评价", "指标", "标准", "成功", "验收"],
            summary: "设计评价标准把“好不好”转化为可以观察、比较或验证的判断依据。",
            whyRelevant: "课程汇报需要说明你的方案为什么成立，而不只是看起来合理。",
            howToUse: "写下 3 条评价标准，并说明每条标准如何被观察或测量。"
        ),
        ResourceCard(
            id: "assumption-mapping",
            title: "Assumption Mapping / 假设识别",
            type: .method,
            relatedStages: [3, 8],
            tags: ["假设", "风险", "边界", "可行性", "验证"],
            summary: "假设地图把项目中的未知判断按重要性和不确定性排序。",
            whyRelevant: "边界和风险阶段都需要看清哪些前提还没有证据支撑。",
            howToUse: "列出 5 个关键假设，优先验证“影响大且不确定”的一项。"
        ),
        ResourceCard(
            id: "progressive-disclosure",
            title: "Progressive Disclosure / 逐级展开",
            type: .designPrinciple,
            relatedStages: [4],
            tags: ["交互", "复杂度", "功能", "信息架构", "概念"],
            summary: "逐级展开通过分层呈现信息，避免用户一次面对过多复杂选择。",
            whyRelevant: "当功能越来越多时，它能帮助你保护核心体验。",
            howToUse: "把功能分成默认可见、按需展开和高级设置三层。"
        ),
        ResourceCard(
            id: "hicks-law",
            title: "Hick's Law / 希克定律",
            type: .designPrinciple,
            relatedStages: [4, 6],
            tags: ["选择", "决策", "复杂度", "约束", "界面"],
            summary: "选择越多，用户做决定通常越慢，界面需要控制同时出现的选项数量。",
            whyRelevant: "它能提醒你在功能拆解时避免把所有能力都塞进第一版。",
            howToUse: "检查核心流程中每一步的选项数量，删掉不服务当前目标的选择。"
        ),
        ResourceCard(
            id: "gestalt-principles",
            title: "Gestalt Principles / 格式塔原则",
            type: .designPrinciple,
            relatedStages: [4],
            tags: ["视觉", "布局", "分组", "界面", "可读性"],
            summary: "格式塔原则解释人们如何通过接近、相似、连续等线索理解界面结构。",
            whyRelevant: "当你准备原型或展示图时，它能提高信息组织的清晰度。",
            howToUse: "检查同类信息是否靠近、样式是否一致、视觉层级是否能被快速扫读。"
        ),
        ResourceCard(
            id: "feedback-loop",
            title: "Feedback Loop / 反馈循环",
            type: .designPrinciple,
            relatedStages: [6],
            tags: ["反馈", "评价", "指标", "迭代", "验证"],
            summary: "反馈循环让用户行为、系统响应和后续改进形成可观察的闭环。",
            whyRelevant: "评价标准不应只停留在结果，也要说明如何回到下一轮设计。",
            howToUse: "为一个关键指标写出：谁提供反馈、何时收集、如何影响下一次迭代。"
        ),
        ResourceCard(
            id: "google-pair-guidebook",
            title: "Google PAIR Guidebook",
            type: .caseStudy,
            relatedStages: [3, 7],
            tags: ["AI", "人机协作", "边界", "可行性", "责任"],
            summary: "PAIR Guidebook 提供以人为中心设计 AI 产品的方法和问题清单。",
            whyRelevant: "如果项目涉及 AI，必须说明系统边界、用户控制和失败处理。",
            howToUse: "用它检查：AI 何时介入、用户如何理解结果、错误输出如何被处理。"
        ),
        ResourceCard(
            id: "notebooklm-audio-overview",
            title: "NotebookLM Audio Overview",
            type: .caseStudy,
            relatedStages: [7],
            tags: ["AI", "案例", "学习", "音频", "原生体验"],
            summary: "NotebookLM 的音频概览展示了 AI 原生学习体验如何把资料转化为可听、可讨论的内容。",
            whyRelevant: "它能启发你思考 AI 不只是生成文本，也可以改变学习材料的呈现方式。",
            howToUse: "分析它把哪些学习动作自动化、哪些判断仍留给用户。"
        ),
        ResourceCard(
            id: "ai-behavior-designer",
            title: "Course Assistant / AI Behavior Designer Framework",
            type: .courseFramework,
            relatedStages: [7],
            tags: ["AI", "助教", "行为", "可行性", "课程"],
            summary: "AI 行为设计关注系统在何时追问、何时建议、何时保持沉默。",
            whyRelevant: "它适合评估课程助教类项目是否真正支持学习过程，而不是替学生完成任务。",
            howToUse: "为你的 AI 写三条行为规则：应该追问什么、推荐什么、避免代替用户做什么。"
        )
    ]
}
