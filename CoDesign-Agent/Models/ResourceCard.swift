import Foundation

enum ResourceType: String, CaseIterable, Identifiable {
    case paper
    case method
    case caseStudy
    case designPrinciple
    case courseFramework

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paper: return "论文"
        case .method: return "方法"
        case .caseStudy: return "案例"
        case .designPrinciple: return "设计原则"
        case .courseFramework: return "课程框架"
        }
    }
}

enum ResourceCardRole: String, CaseIterable, Identifiable {
    case content
    case questionStrategy
    case cognitiveDepth
    case reflectionDetector
    case stageReflection
    case onboarding
    case correctionFeedback
    case errorRecovery
    case feedbackStrategy
    case scaffoldingStrategy
    case loadControl
    case selfRegulation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .content: return "内容依据"
        case .questionStrategy: return "提问策略"
        case .cognitiveDepth: return "认知深度"
        case .reflectionDetector: return "反思识别"
        case .stageReflection: return "阶段复盘"
        case .onboarding: return "使用说明"
        case .correctionFeedback: return "纠正反馈"
        case .errorRecovery: return "错误恢复"
        case .feedbackStrategy: return "形成性反馈"
        case .scaffoldingStrategy: return "脚手架"
        case .loadControl: return "信息负荷"
        case .selfRegulation: return "自我调节"
        }
    }
}

enum ResourceEvidenceLevel: String, CaseIterable, Identifiable {
    case direct
    case adapted
    case heuristic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .direct: return "直接依据"
        case .adapted: return "转化应用"
        case .heuristic: return "启发规则"
        }
    }
}

struct ResourceCard: Identifiable, Hashable {
    let id: String
    let title: String
    let type: ResourceType
    let relatedStages: [Int]
    let tags: [String]
    let summary: String
    let whyRelevant: String
    let howToUse: String
    var triggerProblem: String? = nil
    var coreIdea: String? = nil
    var agentUse: String? = nil
    var displayText: String? = nil
    var exampleQuestion: String? = nil
    var processAction: String? = nil
    var sourceURL: URL? = nil
    var year: Int? = nil
    var venue: String? = nil
    var cardRole: ResourceCardRole = .content
    var source: String? = nil
    var sourceType: String? = nil
    var evidenceLevel: ResourceEvidenceLevel = .adapted
    var problemTypes: [String] = []
    var relatedFields: [BriefField] = []
    var requiredContext: [String] = []
    var globalMoments: [String] = []
    var priority: Int = 50
    var applicationScope: [String] = ["user_project"]
    var uiOutputs: [String] = []
    var triggerSignals: [String] = []
    var avoidWhen: [String] = []

    var sourceDisplayText: String? {
        source ?? venue
    }

    var promptTriggerProblem: String {
        triggerProblem ?? triggerSignals.first ?? whyRelevant
    }

    var promptCoreIdea: String {
        coreIdea ?? summary
    }

    var promptAgentUse: String {
        agentUse ?? howToUse
    }

    var userDisplayText: String {
        displayText ?? summary
    }

    var promptExampleQuestion: String {
        exampleQuestion ?? "基于当前阶段，只提出一个能推动设计判断的问题。"
    }

    var processActionText: String {
        processAction ?? cardRole.displayName
    }
}
