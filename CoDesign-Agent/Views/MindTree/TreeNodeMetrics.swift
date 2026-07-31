import SwiftUI

enum TreeNodeMetrics {
    static let rootSize = CGSize(width: 208, height: 86)
    static let stageSize = CGSize(width: 282, height: 76)
    static let branchStageSize = CGSize(width: 250, height: 62)
    static let questionSize = CGSize(width: 276, height: 112)
    static let fieldSize = CGSize(width: 188, height: 122)
    static let processSize = CGSize(width: 182, height: 122)
    static let revisionSize = CGSize(width: 180, height: 122)

    static func size(for kind: TreeNodeKind) -> CGSize {
        switch kind {
        case .root:
            return rootSize
        case .stage:
            return stageSize
        case .branchStage:
            return branchStageSize
        case .question:
            return questionSize
        case .field:
            return fieldSize
        case .process:
            return processSize
        case .revision:
            return revisionSize
        }
    }
}
