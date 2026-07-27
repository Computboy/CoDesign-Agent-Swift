import Foundation
import SwiftData
import Testing
@testable import CoDesign_Agent

#if os(iOS) && canImport(PencilKit)
import PencilKit
import UIKit
#endif

struct MindTreeAnnotationTests {
    #if os(iOS) && canImport(PencilKit)
    @Test func pencilDrawingDataCanBeSavedAndRestored() throws {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 20, y: 30),
                timeOffset: 0,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 0.5,
                azimuth: 0,
                altitude: .pi / 2
            ),
            PKStrokePoint(
                location: CGPoint(x: 80, y: 90),
                timeOffset: 0.1,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 0.5,
                azimuth: 0,
                altitude: .pi / 2
            ),
        ]
        let stroke = PKStroke(
            ink: PKInk(.pen, color: .systemBlue),
            path: PKStrokePath(controlPoints: points, creationDate: Date())
        )
        let original = PKDrawing(strokes: [stroke])
        let data = original.dataRepresentation()
        let restored = try PKDrawing(data: data)

        #expect(!data.isEmpty)
        #expect(restored.strokes.count == 1)
        #expect(restored.bounds == original.bounds)
    }
    #endif

    @Test func annotationSnapshotJSONRoundTrip() throws {
        let snapshot = makeAnnotationSnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MindTreeAnnotationSnapshot.self, from: data)

        #expect(decoded.id == snapshot.id)
        #expect(decoded.drawingData == snapshot.drawingData)
        #expect(decoded.contentWidth == snapshot.contentWidth)
        #expect(decoded.treeFingerprint == snapshot.treeFingerprint)
        #expect(decoded.expandedTransitionOrders == "1,3")
        #expect(decoded.textItemsData == snapshot.textItemsData)
    }

    @Test func textAnnotationItemsCanBeSavedAndRestored() {
        let item = MindTreeTextAnnotationItem(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            text: "需要补充用户旅程",
            x: 420,
            y: 680,
            width: 260,
            height: 112,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let data = MindTreeTextAnnotationCodec.encode([item])
        let restored = MindTreeTextAnnotationCodec.decode(data)

        #expect(!data.isEmpty)
        #expect(restored == [item])
    }

    @Test func textAnnotationDragUsesGraphCoordinatesWithoutScaleAmplification() {
        let destination = MindTreeTextAnnotationGeometry.translatedCenter(
            from: CGPoint(x: 420, y: 680),
            by: CGSize(width: 36, height: -24)
        )

        #expect(destination == CGPoint(x: 456, y: 656))
    }

    @Test @MainActor func expansionStateAnnotationLayersCoexist() {
        let collapsed = MindTreeAnnotation(
            drawingData: Data([1]),
            contentWidth: 1680,
            contentHeight: 2200,
            treeFingerprint: "collapsed"
        )
        let expanded = MindTreeAnnotation(
            drawingData: Data([2]),
            contentWidth: 2100,
            contentHeight: 2600,
            treeFingerprint: "expanded"
        )

        let annotations = [collapsed, expanded]
        let collapsedLayer = MindTreeAnnotationLayerSelector.annotation(
            matching: "collapsed",
            in: annotations
        )
        let expandedLayer = MindTreeAnnotationLayerSelector.annotation(
            matching: "expanded",
            in: annotations
        )

        #expect(collapsedLayer?.id == collapsed.id)
        #expect(expandedLayer?.id == expanded.id)
        #expect(!collapsed.isArchived)
        #expect(!expanded.isArchived)
    }

    @Test @MainActor func schema10PackageStillDecodes() throws {
        let package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())
        let data = try makeLegacy10Data(from: package)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(CoDesignPackage.self, from: data)

        #expect(decoded.schemaVersion == "1.0")
        #expect(decoded.mindTreeAnnotations == nil)
        #expect(CoDesignPackageImporter.supportedSchemaVersions.contains("1.0"))
    }

    @Test @MainActor func schema11PackageRestoresAnnotations() throws {
        let container = try ExportTestFixtures.makeInMemoryContainer()
        let context = container.mainContext
        let sourceProject = ExportTestFixtures.makeProject(insertInto: context)
        let textItemsData = MindTreeTextAnnotationCodec.encode([
            MindTreeTextAnnotationItem(
                text: "验证文字批注",
                x: 300,
                y: 500
            )
        ])
        let annotation = MindTreeAnnotation(
            drawingData: Data([1, 2, 3, 4]),
            textItemsData: textItemsData,
            contentWidth: 1680,
            contentHeight: 2200,
            treeFingerprint: "fingerprint-1",
            expandedTransitionOrders: "1,3",
            expandedArchivedStageOrders: "2",
            authorName: "测试者",
            authorRole: "学生"
        )
        context.insert(annotation)
        sourceProject.mindTreeAnnotations.append(annotation)
        try context.save()

        let package = CoDesignPackageBuilder().build(project: sourceProject)
        let imported = try CoDesignPackageImporter().importAsNewProject(
            package: package,
            context: context
        )

        #expect(package.schemaVersion == "1.1")
        #expect(package.mindTreeAnnotations?.count == 1)
        #expect(imported.mindTreeAnnotations.count == 1)
        #expect(imported.mindTreeAnnotations[0].drawingData == Data([1, 2, 3, 4]))
        #expect(imported.mindTreeAnnotations[0].textItemsData == textItemsData)
        #expect(imported.mindTreeAnnotations[0].treeFingerprint == "fingerprint-1")
        #expect(imported.mindTreeAnnotations[0].id != annotation.id)
    }

    @Test @MainActor func deletingProjectCascadesToAnnotations() throws {
        let container = try ExportTestFixtures.makeInMemoryContainer()
        let context = container.mainContext
        let project = ExportTestFixtures.makeProject(insertInto: context)
        let annotation = MindTreeAnnotation(
            drawingData: Data([9]),
            contentWidth: 100,
            contentHeight: 200,
            treeFingerprint: "cascade-test"
        )
        context.insert(annotation)
        project.mindTreeAnnotations.append(annotation)
        try context.save()

        context.delete(project)
        try context.save()

        let annotations = try context.fetch(FetchDescriptor<MindTreeAnnotation>())
        #expect(annotations.isEmpty)
    }

    @Test func treeFingerprintIsStableForIdenticalInput() {
        let nodes = fingerprintNodes()
        let first = MindTreeAnnotationFingerprint.make(
            nodes: nodes,
            expandedTransitionOrders: [3, 1],
            expandedArchivedStageOrders: [2],
            contentWidth: 1680,
            contentHeight: 2200
        )
        let second = MindTreeAnnotationFingerprint.make(
            nodes: Array(nodes.reversed()),
            expandedTransitionOrders: [1, 3],
            expandedArchivedStageOrders: [2],
            contentWidth: 1680,
            contentHeight: 2200
        )

        #expect(first == second)
        #expect(first.count == 64)
    }

    @Test func treeFingerprintChangesWhenNodesOrExpansionChange() {
        let nodes = fingerprintNodes()
        let baseline = MindTreeAnnotationFingerprint.make(
            nodes: nodes,
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [],
            contentWidth: 1680,
            contentHeight: 2200
        )
        let changedNode = MindTreeAnnotationFingerprint.make(
            nodes: nodes + [
                MindTreeFingerprintNode(
                    id: "decision-1",
                    parentID: "stage-1",
                    kind: "field",
                    stageOrder: 1,
                    branchVersion: 1
                )
            ],
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [],
            contentWidth: 1680,
            contentHeight: 2200
        )
        let changedExpansion = MindTreeAnnotationFingerprint.make(
            nodes: nodes,
            expandedTransitionOrders: [1, 2],
            expandedArchivedStageOrders: [],
            contentWidth: 1680,
            contentHeight: 2200
        )

        #expect(baseline != changedNode)
        #expect(baseline != changedExpansion)
    }

    @Test @MainActor func legacyProjectWithoutAnnotationsImportsWithoutCrash() throws {
        let package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())
        let data = try makeLegacy10Data(from: package)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let legacyPackage = try decoder.decode(CoDesignPackage.self, from: data)
        let container = try ExportTestFixtures.makeInMemoryContainer()

        let imported = try CoDesignPackageImporter().importAsNewProject(
            package: legacyPackage,
            context: container.mainContext
        )

        #expect(imported.mindTreeAnnotations.isEmpty)
    }

    private func makeAnnotationSnapshot() -> MindTreeAnnotationSnapshot {
        let textItemsData = MindTreeTextAnnotationCodec.encode([
            MindTreeTextAnnotationItem(
                text: "快照文字",
                x: 320,
                y: 640
            )
        ])
        return MindTreeAnnotationSnapshot(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!.uuidString,
            drawingData: Data([0, 1, 2, 3]),
            textItemsData: textItemsData,
            contentWidth: 1680,
            contentHeight: 2200,
            treeFingerprint: "stable-fingerprint",
            expandedTransitionOrders: "1,3",
            expandedArchivedStageOrders: "2",
            authorName: "测试者",
            authorRole: "学生",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            isArchived: false
        )
    }

    private func fingerprintNodes() -> [MindTreeFingerprintNode] {
        [
            MindTreeFingerprintNode(
                id: "root",
                parentID: nil,
                kind: "root",
                stageOrder: nil,
                branchVersion: 1
            ),
            MindTreeFingerprintNode(
                id: "stage-1",
                parentID: "root",
                kind: "stage",
                stageOrder: 1,
                branchVersion: 1
            ),
        ]
    }

    @MainActor
    private func makeLegacy10Data(from package: CoDesignPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        object["schemaVersion"] = "1.0"
        object.removeValue(forKey: "mindTreeAnnotations")
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
