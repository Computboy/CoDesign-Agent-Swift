import SwiftUI

enum TreeNodeMetrics {
    static let rootSize = CGSize(width: 208, height: 86)
    static let stageSize = CGSize(width: 282, height: 76)
    static let questionSize = CGSize(width: 240, height: 68)
    static let fieldSize = CGSize(width: 188, height: 122)
    static let processSize = CGSize(width: 182, height: 122)
    static let evidenceSize = CGSize(width: 196, height: 122)
    static let revisionSize = CGSize(width: 180, height: 122)

    static func size(for kind: TreeNodeKind) -> CGSize {
        switch kind {
        case .root:
            return rootSize
        case .stage, .branchStage:
            return stageSize
        case .question:
            return questionSize
        case .field:
            return fieldSize
        case .process:
            return processSize
        case .evidence:
            return evidenceSize
        case .revision:
            return revisionSize
        }
    }
}
