import Foundation

struct RiskItemDTO: Codable, Identifiable {
    var id: UUID?
    var desc: String              // 与 RiskItem.desc 保持一致（避免 SwiftData 冲突）
    var probability: Int          // 1~5
    var impact: Int               // 1~5
    var mitigation: String?
}
