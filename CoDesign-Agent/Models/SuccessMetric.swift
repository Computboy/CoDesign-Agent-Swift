import Foundation
import SwiftData

@Model
final class SuccessMetric {
    @Attribute(.unique) var id: UUID
    var metric: String
    var target: String
    var measurement: String?

    var brief: DesignBrief?       // 反向关系，SwiftData 自动维护

    init(
        id: UUID = UUID(),
        metric: String,
        target: String,
        measurement: String? = nil
    ) {
        self.id = id
        self.metric = metric
        self.target = target
        self.measurement = measurement
    }
}
