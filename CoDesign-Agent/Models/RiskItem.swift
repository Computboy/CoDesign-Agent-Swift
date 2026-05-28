import Foundation
import SwiftData

@Model
final class RiskItem {
    @Attribute(.unique) var id: UUID
    var desc: String              // 不用 description：与 CustomStringConvertible 冲突
    var probability: Int          // 1~5
    var impact: Int               // 1~5
    var mitigation: String?

    var brief: DesignBrief?       // 反向关系，SwiftData 自动维护

    init(
        id: UUID = UUID(),
        desc: String,
        probability: Int = 3,
        impact: Int = 3,
        mitigation: String? = nil
    ) {
        self.id = id
        self.desc = desc
        self.probability = probability
        self.impact = impact
        self.mitigation = mitigation
    }
}
