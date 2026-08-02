import Foundation

enum ReportCopy {
    static let documentTitle = "AI 产品设计交接简报"
    static let documentSubtitle = "AI Product Design Handoff Brief"
    static let exportDate = "导出日期"
    static let pending = "待进一步定义"

    enum Section {
        static let projectDefinition = ("01 项目定义", "Project Definition")
        static let productScope = ("02 产品范围", "Product Scope")
        static let coreExperienceFlow = ("03 核心体验流程", "Core Experience Flow")
        static let aiBehavior = ("04 AI 行为与用户控制", "AI Behavior & User Control")
        static let validation = ("05 验证、风险与下一步", "Validation, Risks & Next Steps")

        static let projectDefinitionPurpose = "明确产品面向的用户、使用场景、核心问题与价值。"
        static let productScopePurpose = "界定 MVP 范围、主要产品能力、技术支持与项目约束。"
        static let coreExperienceFlowPurpose = "明确用户、AI、系统与人工确认在核心任务中的分工。"
        static let aiBehaviorPurpose = "说明 AI 的介入方式、行为边界以及用户可保留的控制权。"
        static let validationPurpose = "汇总验证指标、已识别风险与已有的下一步安排。"
    }

    enum Project {
        static let solution = "一句话方案"
        static let targetUser = "目标用户"
        static let scenario = "核心使用场景"
        static let painPoint = "核心痛点"
        static let coreValue = "核心价值"
        static let differentiation = "方案特点"
        static let pending = "项目定义仍有内容待补充"
    }

    enum Scope {
        static let included = "MVP 做什么"
        static let excluded = "MVP 不做什么"
        static let capabilities = "主要产品能力"
        static let technicalSupport = "技术支持模块"
        static let constraints = "项目约束"
        static let pending = "产品范围待进一步明确"
    }

    enum Flow {
        static let title = "核心任务流程"
        static let rules = "关键运行规则"
        static let pending = "核心体验流程待进一步明确"
        static let user = "用户"
        static let ai = "AI"
        static let system = "系统"
        static let humanConfirmation = "人工确认"
        static let unspecified = "角色待定义"
        static let finalConfirmation = "最终确认"
    }

    enum Behavior {
        static let understand = "用户认知任务 · UNDERSTAND"
        static let capability = "AI 能力 · CAPABILITY"
        static let boundary = "行为边界 · BOUNDARY"
        static let pending = "AI 行为与用户控制待进一步明确"

        static let labels: [ReportBehaviorFieldID: String] = [
            .input: "用户输入",
            .cognitiveTask: "用户认知任务",
            .expectedOutput: "预期结果",
            .timing: "介入时机",
            .reasoningMode: "处理方式",
            .outputModality: "结果呈现",
            .feedbackLoop: "反馈与修改",
            .willDo: "AI 会做什么",
            .willNotDo: "AI 不会做什么",
            .approval: "人工确认",
            .responsibility: "责任边界",
            .fallback: "失败降级",
        ]
    }

    enum Validation {
        static let metrics = "成功指标"
        static let metricsContinuation = "成功指标（续）"
        static let metricHeaders = ["指标", "类型", "目标值", "测量方式", "当前状态"]
        static let metricCategoryPending = "待分类"
        static let validationPending = "待验证"
        static let metricsPending = "成功指标待进一步定义"
        static let risksPending = "尚未记录已识别风险"
        static let nextSteps = "下一步设计重点"
    }

    enum Risk {
        static let title = "风险与应对"
        static let continuation = "风险与应对（续）"
        static let risk = "风险"
        static let trigger = "触发条件 / 失败表现"
        static let detection = "发现方式"
        static let response = "应对与恢复"
        static let userControl = "用户控制"
        static let probability = "概率"
        static let impact = "影响"
    }

    static func behaviorGroupTitle(_ id: ReportBehaviorGroupID) -> String {
        switch id {
        case .understand: return Behavior.understand
        case .capability: return Behavior.capability
        case .boundary: return Behavior.boundary
        }
    }

    static func behaviorFieldLabel(_ id: ReportBehaviorFieldID) -> String {
        Behavior.labels[id] ?? id.rawValue
    }
}

enum ReportContentSanitizer {
    private static let replacements: [(String, String)] = [
        ("active branch", "当前方案"),
        ("active leaf", "当前结论"),
        ("archived branch", "历史方案"),
        ("delayed confirmation", "待确认内容"),
        ("Stage lifecycle", "阶段状态"),
        ("completedExpanded", "已完成"),
        ("completedCollapsed", "已完成"),
        ("parentMomentID", "关联记录"),
        ("branchVersion", "方案记录"),
        ("SwiftData", "数据存储"),
        ("semantic mapping", "内容整理"),
        ("pagination engine", "分页机制"),
        ("renderer", "排版模块"),
        ("用于测试完整 Design Brief", ""),
        ("已完成测试任务", ""),
        ("用于测试", ""),
        ("基于当前版本", ""),
        ("当前版本", ""),
        ("本版本", ""),
        ("本次重构", ""),
        ("本次修改", ""),
        ("新版导出", ""),
        ("旧版导出", ""),
        ("当前导出器", ""),
        ("报告生成器", ""),
    ]

    static func clean(_ rawValue: String?) -> String? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        for (needle, replacement) in replacements {
            value = value.replacingOccurrences(
                of: needle,
                with: replacement,
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }
        value = value.replacingOccurrences(
            of: #"(?i)\bv\d+(?:\.\d+){1,3}\b"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"^[：:，,。；;·\-—\s]+"#, with: "", options: .regularExpression)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

enum ReportContentValidator {
    static let prohibitedPhrases = [
        "v1.1.0", "基于当前版本", "当前版本", "本版本", "本次重构", "本次修改",
        "新版导出", "旧版导出", "当前导出器", "报告生成器", "active branch",
        "active leaf", "archived branch", "delayed confirmation", "Stage lifecycle",
        "completedExpanded", "completedCollapsed", "parentMomentID", "branchVersion",
        "SwiftData", "semantic mapping", "renderer", "pagination engine",
        "用于测试完整 Design Brief", "用于测试", "已完成测试任务",
    ]

    static func violations(in document: ReportDocumentModel) -> [String] {
        let text = document.allTextFragments.joined(separator: "\n")
        return prohibitedPhrases.filter {
            text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    static func validate(_ document: ReportDocumentModel) throws {
        let violations = violations(in: document)
        guard violations.isEmpty else {
            throw ReportExportError.encodingFailed("报告包含不应公开的内部文案：\(violations.joined(separator: "、"))")
        }
    }
}
