import Foundation

struct BoundaryItemDTO: Codable, Identifiable {
    var id: UUID?
    var content: String
    var isIncluded: Bool
}
