import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var briefDescription: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.project)
    var messages: [ChatMessage]

    @Relationship(deleteRule: .cascade, inverse: \DesignBrief.project)
    var brief: DesignBrief?

    @Relationship(deleteRule: .cascade, inverse: \ProgressStage.project)
    var stages: [ProgressStage]

    @Relationship(deleteRule: .cascade, inverse: \LearningTrace.project)
    var learningTraces: [LearningTrace]

    @Relationship(deleteRule: .cascade, inverse: \ThinkingMoment.project)
    var thinkingMoments: [ThinkingMoment]

    @Relationship(deleteRule: .cascade, inverse: \MindTreeAnnotation.project)
    var mindTreeAnnotations: [MindTreeAnnotation]

    init(
        id: UUID = UUID(),
        name: String,
        briefDescription: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = [],
        stages: [ProgressStage] = [],
        learningTraces: [LearningTrace] = [],
        thinkingMoments: [ThinkingMoment] = [],
        mindTreeAnnotations: [MindTreeAnnotation] = []
    ) {
        self.id = id
        self.name = name
        self.briefDescription = briefDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.stages = stages
        self.learningTraces = learningTraces
        self.thinkingMoments = thinkingMoments
        self.mindTreeAnnotations = mindTreeAnnotations
    }

    var completionRate: Double {
        guard !stages.isEmpty else { return 0 }
        let total = stages.reduce(0.0) { $0 + $1.completionRatio }
        return total / Double(stages.count)
    }

    // MARK: - Thinking Moments Auto-Generation

    /// Ensures the project has at least a root ThinkingMoment.
    /// If thinkingMoments is empty (e.g. project was created before the
    /// ThinkingMoment model existed), generates a seed moment + moments
    /// from any already-filled BriefFields.
    func ensureThinkingMoments(context: ModelContext) {
        guard thinkingMoments.isEmpty else { return }

        // 1. Root seed
        let root = ThinkingMoment(
            momType: "seed",
            content: "项目想法诞生",
            stageOrder: 0
        )
        context.insert(root)
        thinkingMoments.append(root)

        // 2. Build moments from filled brief fields
        let brief = self.brief?.toSnapshot() ?? DesignBriefSnapshot()
        let stagesSorted = stages.sorted { $0.order < $1.order }

        for stage in stagesSorted {
            guard let def = StageDefinition.all.first(where: { $0.order == stage.order }) else { continue }
            let filledFields = def.briefFields.filter { $0.isFilled(in: brief) }
            guard !filledFields.isEmpty || stage.stageStatusValue != .notStarted else { continue }

            // Stage branch moment
            let branch = ThinkingMoment(
                momType: "branch",
                content: "探索: \(def.name)",
                stageOrder: stage.order,
                parentMomentID: root.id
            )
            context.insert(branch)
            thinkingMoments.append(branch)

            // Field deepen moments
            for field in filledFields {
                let deepen = ThinkingMoment(
                    momType: "deepen",
                    content: field.displayName,
                    stageOrder: stage.order,
                    relatedField: field.rawValue,
                    parentMomentID: branch.id
                )
                context.insert(deepen)
                thinkingMoments.append(deepen)
            }
        }

        try? context.save()
    }
}
