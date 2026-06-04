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

    init(
        id: UUID = UUID(),
        name: String,
        briefDescription: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = [],
        stages: [ProgressStage] = [],
        learningTraces: [LearningTrace] = [],
        thinkingMoments: [ThinkingMoment] = []
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
    }

    var completionRate: Double {
        guard !stages.isEmpty else { return 0 }
        let total = stages.reduce(0.0) { $0 + $1.completionRatio }
        return total / Double(stages.count)
    }
}
