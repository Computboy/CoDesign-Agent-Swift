import Foundation
import SwiftData

@Model
final class BoundaryItem {
    @Attribute(.unique) var id: UUID
    var content: String
    var isIncluded: Bool          // true = MVP 做, false = 明确排除

    var brief: DesignBrief?       // 反向关系，SwiftData 自动维护

    init(
        id: UUID = UUID(),
        content: String,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.content = content
        self.isIncluded = isIncluded
    }
}
