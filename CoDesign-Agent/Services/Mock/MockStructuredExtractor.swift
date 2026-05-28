import Foundation

final class MockStructuredExtractor: StructuredExtractorProtocol {
    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractedFields {
        // 模拟异步处理延迟
        try await Task.sleep(for: .milliseconds(300))

        // 找到最后一条用户消息
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            return ExtractedFields()
        }

        let text = lastUserMessage.content
        var fields = ExtractedFields()

        // MARK: 阶段 1：痛点与场景锚定

        // targetUser
        let userKeywords = ["大学生", "新生", "学生", "老人", "儿童", "白领", "上班族",
                            "设计师", "开发者", "老师", "用户"]
        for keyword in userKeywords where text.contains(keyword) {
            fields.targetUser = extractContext(around: keyword, in: text)
            break
        }

        // painPoint
        let painKeywords = ["找不到", "困难", "麻烦", "太慢", "复杂", "不会", "不懂",
                           "不方便", "效率低", "容易出错", "迷路", "焦虑"]
        for keyword in painKeywords where text.contains(keyword) {
            fields.painPoint = extractContext(around: keyword, in: text)
            break
        }

        // useScenario
        let scenarioKeywords = ["在", "当", "时候", "每天", "上课", "考试", "开会",
                               "出门", "回家", "开学", "宿舍", "教学楼"]
        for keyword in scenarioKeywords where text.contains(keyword) {
            fields.useScenario = extractContext(around: keyword, in: text)
            break
        }

        // MARK: 阶段 2：差异化价值提炼

        // differentiation
        let diffKeywords = ["不同于", "比", "优势", "独特", "核心", "区别", "差异", "不一样"]
        for keyword in diffKeywords where text.contains(keyword) {
            fields.differentiation = extractContext(around: keyword, in: text)
            break
        }

        // coreValue
        let valueKeywords = ["价值", "解决", "帮助", "提升", "降低", "节省", "让用户", "核心价值"]
        for keyword in valueKeywords where text.contains(keyword) {
            fields.coreValue = extractContext(around: keyword, in: text)
            break
        }

        // MARK: 阶段 3：项目边界划定

        var boundaryItems: [BoundaryItemDTO] = []

        // 排除项
        let excludeKeywords = ["不做", "排除", "不考虑", "暂时不", "v1 不", "第一版不"]
        for keyword in excludeKeywords where text.contains(keyword) {
            boundaryItems.append(
                BoundaryItemDTO(content: extractContext(around: keyword, in: text), isIncluded: false)
            )
            break
        }

        // 包含项
        let includeKeywords = ["要做", "必须做", "保留", "核心功能", "MVP"]
        for keyword in includeKeywords where text.contains(keyword) {
            boundaryItems.append(
                BoundaryItemDTO(content: extractContext(around: keyword, in: text), isIncluded: true)
            )
            break
        }

        if !boundaryItems.isEmpty {
            fields.boundaryItems = boundaryItems
        }

        // MARK: 阶段 4：功能与技术方案拆解

        // mvpFeatures
        let featureKeywords = ["功能", "MVP", "第一版", "核心功能", "主要功能"]
        for keyword in featureKeywords where text.contains(keyword) {
            fields.mvpFeatures = extractContext(around: keyword, in: text)
            break
        }

        // technicalModules
        let techKeywords = ["技术", "模块", "API", "SwiftData", "SwiftUI", "ARKit",
                           "CoreLocation", "LLM", "模型"]
        for keyword in techKeywords where text.contains(keyword) {
            fields.technicalModules = extractContext(around: keyword, in: text)
            break
        }

        // interactionFlow
        let flowKeywords = ["流程", "步骤", "用户先", "然后", "最后", "打开 App", "进入"]
        for keyword in flowKeywords where text.contains(keyword) {
            fields.interactionFlow = extractContext(around: keyword, in: text)
            break
        }

        // MARK: 阶段 5：运行逻辑与规则定义

        // operationLogic
        let logicKeywords = ["规则", "逻辑", "运行", "判断", "触发", "自动", "手动",
                            "异常", "报错", "恢复"]
        for keyword in logicKeywords where text.contains(keyword) {
            fields.operationLogic = extractContext(around: keyword, in: text)
            break
        }

        // MARK: 阶段 6：硬性约束设计

        // hardConstraints
        let constraintKeywords = ["时间", "预算", "设备", "平台", "iOS", "限制", "约束"]
        for keyword in constraintKeywords where text.contains(keyword) {
            fields.hardConstraints = extractContext(around: keyword, in: text)
            break
        }

        // MARK: 阶段 7：量化验收标准制定

        // successMetrics
        let metricKeywords = ["成功", "指标", "准确率", "完成率", "满意度", "时间减少", "评分"]
        for keyword in metricKeywords where text.contains(keyword) {
            fields.successMetrics = [
                SuccessMetricDTO(
                    metric: "从对话中提取的指标",
                    target: extractContext(around: keyword, in: text)
                )
            ]
            break
        }

        // MARK: 阶段 8：风险识别与预案制定

        // risks
        let riskKeywords = ["风险", "失败", "做不到", "不稳定", "延迟", "错误", "成本高"]
        for keyword in riskKeywords where text.contains(keyword) {
            fields.risks = [
                RiskItemDTO(
                    desc: extractContext(around: keyword, in: text),
                    probability: 3,
                    impact: 3,
                    mitigation: nil
                )
            ]
            break
        }

        // MARK: 阶段 9：项目阶段拆分与排期

        // milestones
        let milestoneKeywords = ["里程碑", "第一阶段", "第二阶段", "排期", "计划", "周", "天"]
        for keyword in milestoneKeywords where text.contains(keyword) {
            fields.milestones = extractContext(around: keyword, in: text)
            break
        }

        return fields
    }

    // MARK: - Helper

    /// 提取关键词周围的上下文（前约 10 字符、后约 20 字符）
    private func extractContext(around keyword: String, in text: String) -> String {
        guard let range = text.range(of: keyword) else { return keyword }
        let center = text.distance(from: text.startIndex, to: range.lowerBound)
        let start = max(0, center - 10)
        let end = min(text.count, center + keyword.count + 20)
        let startIdx = text.index(text.startIndex, offsetBy: start)
        let endIdx = text.index(text.startIndex, offsetBy: end)
        return String(text[startIdx..<endIdx])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
