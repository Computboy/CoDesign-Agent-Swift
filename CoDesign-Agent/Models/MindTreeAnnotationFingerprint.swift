import CryptoKit
import Foundation

struct MindTreeFingerprintNode: Equatable {
    let id: String
    let parentID: String?
    let kind: String
    let stageOrder: Int?
    let branchVersion: Int
}

enum MindTreeAnnotationFingerprint {
    static func make(
        nodes: [MindTreeFingerprintNode],
        expandedTransitionOrders: Set<Int>,
        expandedArchivedStageOrders: Set<Int>,
        contentWidth: Double,
        contentHeight: Double
    ) -> String {
        let sortedNodes = nodes.sorted {
            if $0.id != $1.id { return $0.id < $1.id }
            if ($0.parentID ?? "") != ($1.parentID ?? "") {
                return ($0.parentID ?? "") < ($1.parentID ?? "")
            }
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            if ($0.stageOrder ?? -1) != ($1.stageOrder ?? -1) {
                return ($0.stageOrder ?? -1) < ($1.stageOrder ?? -1)
            }
            return $0.branchVersion < $1.branchVersion
        }

        var canonicalLines = ["codesign-mind-tree-annotation-v1"]
        canonicalLines.append(
            "canvas|\(normalizedDimension(contentWidth))|\(normalizedDimension(contentHeight))"
        )
        canonicalLines.append(
            "expanded-transitions|\(MindTreeAnnotationExpansionCodec.encode(expandedTransitionOrders))"
        )
        canonicalLines.append(
            "expanded-archived|\(MindTreeAnnotationExpansionCodec.encode(expandedArchivedStageOrders))"
        )

        canonicalLines.append(contentsOf: sortedNodes.map { node in
            [
                node.id,
                node.parentID ?? "",
                node.kind,
                node.stageOrder.map(String.init) ?? "",
                String(node.branchVersion),
            ]
            .map(lengthPrefixed)
            .joined(separator: "|")
        })

        let digest = SHA256.hash(data: Data(canonicalLines.joined(separator: "\n").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func lengthPrefixed(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }

    private static func normalizedDimension(_ value: Double) -> String {
        guard value.isFinite else { return "0.000" }
        return String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}

enum MindTreeAnnotationExpansionCodec {
    static func encode(_ orders: Set<Int>) -> String {
        orders.sorted().map(String.init).joined(separator: ",")
    }

    static func decode(_ value: String) -> Set<Int> {
        Set(
            value
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }
}
