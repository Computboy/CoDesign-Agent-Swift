import Foundation

struct SuccessMetricDTO: Codable, Identifiable {
    var id: UUID?
    var metric: String
    var target: String
    var measurement: String?
}
