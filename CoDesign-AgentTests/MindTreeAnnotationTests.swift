import Foundation
import SwiftData
import Testing
@testable import CoDesign_Agent

#if os(iOS) && canImport(PencilKit)
import PencilKit
import UIKit
#endif

@MainActor
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

    @Test @MainActor func schema12PackageRestoresAnnotations() throws {
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

        #expect(package.schemaVersion == "1.2")
        #expect(package.mindTreeAnnotations?.count == 1)
        #expect(imported.mindTreeAnnotations.count == 1)
        #expect(imported.mindTreeAnnotations[0].drawingData == Data([1, 2, 3, 4]))
        #expect(
            MindTreeTextAnnotationCodec.decode(imported.mindTreeAnnotations[0].textItemsData ?? Data())
                == MindTreeTextAnnotationCodec.decode(textItemsData)
        )
        #expect(imported.mindTreeAnnotations[0].treeFingerprint == "fingerprint-1")
        #expect(imported.mindTreeAnnotations[0].id != annotation.id)
    }

    @Test func semanticAnchorsRoundTripThroughJSON() throws {
        let momentID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let anchors: [MindTreeAnnotationAnchor] = [
            .project,
            .stage(order: 3),
            .transition(stageOrder: 4),
            .moment(id: momentID, branchVersion: 2, stageOrder: 1),
            .archivedBranch(stageOrder: 2, branchVersion: 5),
        ]

        let data = try JSONEncoder().encode(anchors)
        let decoded = try JSONDecoder().decode([MindTreeAnnotationAnchor].self, from: data)

        #expect(decoded == anchors)
        #expect(Set(decoded.map(\.stableID)).count == anchors.count)
    }

    @Test func legacyTextItemJSONDecodesWithoutAnchorFields() throws {
        let legacy = LegacyTextItem(
            id: UUID(),
            text: "旧文字批注",
            x: 120,
            y: 240,
            width: 260,
            height: 112,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let decoded = try JSONDecoder().decode(
            MindTreeTextAnnotationItem.self,
            from: JSONEncoder().encode(legacy)
        )

        #expect(decoded.text == legacy.text)
        #expect(decoded.anchor == nil)
        #expect(decoded.migrationVersion == nil)
    }

    @Test @MainActor func modernProjectDocumentWinsOverNewerLegacyLayer() {
        let modern = MindTreeAnnotation(
            contentWidth: 100,
            contentHeight: 100,
            treeFingerprint: "old-modern-fingerprint",
            annotationDocumentVersion: MindTreeAnnotationDocument.currentVersion,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newerLegacy = MindTreeAnnotation(
            contentWidth: 100,
            contentHeight: 100,
            treeFingerprint: "current",
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let selection = MindTreeAnnotationLayerSelector.selection(
            matching: "current",
            in: [newerLegacy, modern]
        )

        #expect(selection?.annotation.id == modern.id)
        #expect(selection?.source == .modernProjectDocument)
    }

    @Test @MainActor func exactLegacyLayerWinsBeforeLatestLegacyFallback() {
        let exact = MindTreeAnnotation(
            contentWidth: 100,
            contentHeight: 100,
            treeFingerprint: "current",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newerMismatch = MindTreeAnnotation(
            contentWidth: 100,
            contentHeight: 100,
            treeFingerprint: "other",
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let selection = MindTreeAnnotationLayerSelector.selection(
            matching: "current",
            in: [newerMismatch, exact]
        )

        #expect(selection?.annotation.id == exact.id)
        #expect(selection?.source == .exactLegacyLayer)
    }

    @Test @MainActor func latestLegacyLayerIsReturnedInsteadOfBlank() {
        let latest = MindTreeAnnotation(
            contentWidth: 100,
            contentHeight: 100,
            treeFingerprint: "old",
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let selection = MindTreeAnnotationLayerSelector.selection(
            matching: "new",
            in: [latest]
        )

        #expect(selection?.annotation.id == latest.id)
        #expect(selection?.source == .legacyLayerNeedsMigration)
        #expect(selection?.needsMigration == true)
    }

    @Test func anchoredTextFollowsStageAfterLayoutMoves() {
        let first = makeLayoutSnapshot(
            anchors: [anchorFrame(.stage(order: 1), x: 100, y: 200)],
            width: 1000,
            height: 1000,
            fingerprint: "first"
        )
        let second = makeLayoutSnapshot(
            anchors: [anchorFrame(.stage(order: 1), x: 360, y: 520)],
            width: 1000,
            height: 1000,
            fingerprint: "second"
        )
        let base = MindTreeTextAnnotationItem(text: "阶段旁", x: 125, y: 180)
        let anchored = MindTreeAnnotationProjectionService.anchoredTextItem(
            base,
            at: CGPoint(x: 125, y: 180),
            in: first,
            fingerprint: first.fingerprint
        )
        let projected = MindTreeAnnotationProjectionService.projectedTextItem(
            anchored,
            in: second,
            knownAnchors: [.stage(order: 1)]
        )

        #expect(projected.x == 385)
        #expect(projected.y == 500)
        #expect(projected.resolutionState == .resolved)
    }

    @Test func collapsedAnchorIsHiddenButRetained() {
        var item = MindTreeTextAnnotationItem(
            text: "折叠分支批注",
            x: 200,
            y: 300,
            anchor: .moment(id: UUID(), branchVersion: 1, stageOrder: 1),
            localX: 10,
            localY: 20,
            fallbackNormalizedX: 0.2,
            fallbackNormalizedY: 0.3
        )
        let anchor = item.anchor!
        item = MindTreeAnnotationProjectionService.projectedTextItem(
            item,
            in: makeLayoutSnapshot(anchors: [], fingerprint: "collapsed"),
            knownAnchors: [anchor]
        )

        #expect(item.resolutionState == .hidden)
        #expect(item.anchor == anchor)
    }

    @Test @MainActor func resourceCardAnnotationStaysFixedWhileDeckMoves() {
        let project = Project(name: "资源批注", briefDescription: "")
        project.stages = [
            ProgressStage(order: 1, name: "阶段 1", status: "active", completionRatio: 0.4)
        ]
        let question = ThinkingMoment(
            momType: "question",
            content: "用户最担心什么？",
            stageOrder: 1
        )
        let resource = ResourceLibrary.all[0]
        let method = ThinkingMoment(
            momType: "method",
            content: "调用依据：\(resource.title)",
            stageOrder: 1,
            resourceCardID: resource.id,
            parentMomentID: question.id
        )
        project.thinkingMoments = [question, method]

        let collapsedGraph = MindTreeCanonicalLayout.layout(
            TreeBuilder().build(
                project: project,
                expandedTransitionOrders: [1]
            ),
            visibleStageLimit: 1,
            in: CGSize(width: 1_000, height: 800)
        )
        let expandedGraph = MindTreeCanonicalLayout.layout(
            TreeBuilder().build(
                project: project,
                expandedTransitionOrders: [1]
            ),
            visibleStageLimit: 1,
            in: CGSize(width: 1_000, height: 800)
        )
        let collapsedSnapshot = MindTreeAnnotationProjectionService.layoutSnapshot(
            graph: collapsedGraph,
            fingerprint: "resource-collapsed",
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: []
        )
        let expandedSnapshot = MindTreeAnnotationProjectionService.layoutSnapshot(
            graph: expandedGraph,
            fingerprint: "resource-expanded",
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [],
            resourceDeckProgressByQuestionID: [
                "moment-\(question.id)": 1
            ]
        )
        let draggingSnapshot = MindTreeAnnotationProjectionService.layoutSnapshot(
            graph: expandedGraph,
            fingerprint: "resource-dragging",
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [],
            resourceDeckProgressByQuestionID: [
                "moment-\(question.id)": 0.55
            ]
        )
        let anchor = MindTreeAnnotationAnchor.moment(
            id: method.id,
            branchVersion: method.branchVersion,
            stageOrder: method.stageOrder
        )
        let annotation = MindTreeTextAnnotationItem(
            text: "资源批注",
            x: 0,
            y: 0,
            anchor: anchor,
            localX: 8,
            localY: 12,
            fallbackNormalizedX: 0.5,
            fallbackNormalizedY: 0.5
        )
        let collapsed = MindTreeAnnotationProjectionService.projectedTextItem(
            annotation,
            in: collapsedSnapshot,
            knownAnchors: [anchor]
        )
        let restored = MindTreeAnnotationProjectionService.projectedTextItem(
            collapsed,
            in: expandedSnapshot,
            knownAnchors: [anchor]
        )
        let dragging = MindTreeAnnotationProjectionService.projectedTextItem(
            collapsed,
            in: draggingSnapshot,
            knownAnchors: [anchor]
        )

        #expect(collapsedSnapshot.frame(for: anchor) != nil)
        #expect(expandedSnapshot.frame(for: anchor) != nil)
        #expect(draggingSnapshot.frame(for: anchor) != nil)
        #expect(collapsed.resolutionState == .resolved)
        #expect(restored.resolutionState == .resolved)
        #expect(dragging.resolutionState == .resolved)
        #expect(restored.anchor == anchor)
        #expect(dragging.y == restored.y)
        #expect(dragging.x == restored.x)
        #expect(collapsed.x == restored.x)
        #expect(
            QuestionResourceDeckLayout.annotationOpacity(
                cardProgress: 0
            ) == 0
        )
        #expect(
            QuestionResourceDeckLayout.annotationOpacity(
                cardProgress: 1
            ) == 1
        )
    }

    @Test func deletedAnchorUsesNormalizedFallbackAndIsMarkedUnresolved() {
        let removedAnchor = MindTreeAnnotationAnchor.moment(
            id: UUID(),
            branchVersion: 3,
            stageOrder: 2
        )
        let item = MindTreeTextAnnotationItem(
            text: "待恢复",
            x: 0,
            y: 0,
            anchor: removedAnchor,
            localX: 0,
            localY: 0,
            fallbackNormalizedX: 0.25,
            fallbackNormalizedY: 0.75
        )
        let snapshot = makeLayoutSnapshot(
            anchors: [],
            width: 800,
            height: 1200,
            fingerprint: "deleted"
        )
        let projected = MindTreeAnnotationProjectionService.projectedTextItem(
            item,
            in: snapshot,
            knownAnchors: [.project]
        )

        #expect(projected.x == 200)
        #expect(projected.y == 900)
        #expect(projected.resolutionState == .unresolved)
    }

    @Test func legacyTextMigrationUsesNormalizedCanvasPosition() {
        let snapshot = makeLayoutSnapshot(
            anchors: [anchorFrame(.project, x: 1000, y: 1000)],
            width: 2000,
            height: 2000,
            fingerprint: "expanded"
        )
        let legacy = MindTreeTextAnnotationItem(text: "旧位置", x: 500, y: 250)

        let migrated = MindTreeAnnotationProjectionService.migrateLegacyTextItems(
            [legacy],
            sourceWidth: 1000,
            sourceHeight: 500,
            to: snapshot,
            fingerprint: snapshot.fingerprint
        )[0]

        #expect(migrated.x == 1000)
        #expect(migrated.y == 1000)
        #expect(migrated.anchor == .project)
        #expect(migrated.migrationVersion == 1)
    }

    @Test func draggingTextRebindsItToNearestSemanticAnchor() {
        let snapshot = makeLayoutSnapshot(
            anchors: [
                anchorFrame(.stage(order: 1), x: 100, y: 100),
                anchorFrame(.stage(order: 2), x: 700, y: 700),
            ],
            width: 1000,
            height: 1000,
            fingerprint: "drag"
        )
        let item = MindTreeTextAnnotationItem(text: "移动", x: 110, y: 110)
        let rebound = MindTreeAnnotationProjectionService.anchoredTextItem(
            item,
            at: CGPoint(x: 680, y: 720),
            in: snapshot,
            fingerprint: snapshot.fingerprint
        )

        #expect(rebound.anchor == .stage(order: 2))
        #expect(rebound.localX == -20)
        #expect(rebound.localY == 20)
    }

    @Test func repeatedSnapshotCaptureIsIdempotentPerFingerprint() {
        let old = makeLayoutSnapshot(anchors: [], fingerprint: "same")
        let replacement = makeLayoutSnapshot(
            anchors: [anchorFrame(.project, x: 20, y: 20)],
            fingerprint: "same"
        )
        let merged = MindTreeAnnotationProjectionService.mergedSnapshots(
            existing: [old],
            adding: replacement
        )

        #expect(merged.count == 1)
        #expect(merged[0].anchors.count == 1)
    }

    @Test func anchorMomentIDCanBeRemappedForImportedProject() {
        let source = UUID()
        let destination = UUID()
        let anchor = MindTreeAnnotationAnchor.moment(
            id: source,
            branchVersion: 2,
            stageOrder: 4
        )

        let remapped = anchor.remappingMomentIDs([source: destination])

        #expect(
            remapped == .moment(
                id: destination,
                branchVersion: 2,
                stageOrder: 4
            )
        )
    }

    @Test func anchoredInkAndLayoutCodecsRoundTrip() {
        let group = MindTreeAnchoredInkGroup(
            anchor: .transition(stageOrder: 2),
            drawingData: Data([4, 5, 6]),
            sourceAnchorX: 200,
            sourceAnchorY: 300,
            sourceAnchorWidth: 40,
            sourceAnchorHeight: 80,
            fallbackNormalizedX: 0.2,
            fallbackNormalizedY: 0.3,
            createdAgainstFingerprint: "ink"
        )
        let layout = makeLayoutSnapshot(
            anchors: [anchorFrame(.transition(stageOrder: 2), x: 200, y: 300)],
            fingerprint: "ink"
        )

        #expect(MindTreeAnchoredInkCodec.decode(MindTreeAnchoredInkCodec.encode([group])) == [group])
        #expect(MindTreeAnnotationLayoutCodec.decode(MindTreeAnnotationLayoutCodec.encode([layout])) == [layout])
    }

    @Test func projectionSummaryCountsHiddenAndUnresolvedItems() {
        var hiddenText = MindTreeTextAnnotationItem(text: "hidden", x: 0, y: 0)
        hiddenText.resolutionState = .hidden
        var unresolvedInk = MindTreeAnchoredInkGroup(
            anchor: .project,
            drawingData: Data(),
            sourceAnchorX: 0,
            sourceAnchorY: 0,
            sourceAnchorWidth: 1,
            sourceAnchorHeight: 1,
            fallbackNormalizedX: 0.5,
            fallbackNormalizedY: 0.5,
            createdAgainstFingerprint: "summary"
        )
        unresolvedInk.resolutionState = .unresolved

        let summary = MindTreeAnnotationProjectionService.summary(
            textItems: [hiddenText],
            inkGroups: [unresolvedInk]
        )

        #expect(summary.hiddenCount == 1)
        #expect(summary.unresolvedCount == 1)
        #expect(summary.hasExceptions)
    }

    @Test @MainActor func schema11PackageStillDecodesWithLegacyAnnotationFields() throws {
        let container = try ExportTestFixtures.makeInMemoryContainer()
        let project = ExportTestFixtures.makeProject(insertInto: container.mainContext)
        let annotation = MindTreeAnnotation(
            drawingData: Data([7, 8]),
            contentWidth: 800,
            contentHeight: 1200,
            treeFingerprint: "legacy-11"
        )
        container.mainContext.insert(annotation)
        project.mindTreeAnnotations.append(annotation)
        let package = CoDesignPackageBuilder().build(project: project)
        let data = try makeLegacy11Data(from: package)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(CoDesignPackage.self, from: data)

        #expect(decoded.schemaVersion == "1.1")
        #expect(decoded.mindTreeAnnotations?.first?.drawingData == Data([7, 8]))
        #expect(decoded.mindTreeAnnotations?.first?.annotationDocumentVersion == nil)
    }

    @Test @MainActor func schema12ImportRemapsMomentAnchors() throws {
        let container = try ExportTestFixtures.makeInMemoryContainer()
        let context = container.mainContext
        let sourceProject = ExportTestFixtures.makeProject(insertInto: context)
        let sourceMoment = try #require(sourceProject.thinkingMoments.first)
        let anchoredText = MindTreeTextAnnotationItem(
            text: "跟随问题",
            x: 100,
            y: 100,
            anchor: .moment(
                id: sourceMoment.id,
                branchVersion: sourceMoment.branchVersion,
                stageOrder: sourceMoment.stageOrder
            ),
            localX: 12,
            localY: 18,
            fallbackNormalizedX: 0.1,
            fallbackNormalizedY: 0.1
        )
        let annotation = MindTreeAnnotation(
            textItemsData: MindTreeTextAnnotationCodec.encode([anchoredText]),
            contentWidth: 1000,
            contentHeight: 1000,
            treeFingerprint: "export",
            annotationDocumentVersion: MindTreeAnnotationDocument.currentVersion
        )
        context.insert(annotation)
        sourceProject.mindTreeAnnotations.append(annotation)
        let package = CoDesignPackageBuilder().build(project: sourceProject)

        let imported = try CoDesignPackageImporter().importAsNewProject(
            package: package,
            context: context
        )
        let importedMoment = try #require(
            imported.thinkingMoments.first { $0.content == sourceMoment.content }
        )
        let importedAnnotation = try #require(imported.mindTreeAnnotations.first)
        let importedTextData = try #require(importedAnnotation.textItemsData)
        let importedItem = try #require(
            MindTreeTextAnnotationCodec.decode(importedTextData).first
        )

        #expect(importedMoment.id != sourceMoment.id)
        #expect(
            importedItem.anchor == .moment(
                id: importedMoment.id,
                branchVersion: sourceMoment.branchVersion,
                stageOrder: sourceMoment.stageOrder
            )
        )
    }

    #if os(iOS) && canImport(PencilKit)
    @Test func inkStrokeFollowsItsAnchorAfterLayoutMoves() throws {
        let drawing = PKDrawing(strokes: [makeStroke(from: CGPoint(x: 90, y: 95), to: CGPoint(x: 110, y: 105))])
        let first = makeLayoutSnapshot(
            anchors: [anchorFrame(.stage(order: 1), x: 100, y: 100)],
            width: 1000,
            height: 1000,
            fingerprint: "first"
        )
        let second = makeLayoutSnapshot(
            anchors: [anchorFrame(.stage(order: 1), x: 400, y: 300)],
            width: 1000,
            height: 1000,
            fingerprint: "second"
        )
        let groups = MindTreeAnnotationInkService.groups(
            from: drawing.dataRepresentation(),
            in: first,
            fingerprint: first.fingerprint
        )
        let projected = MindTreeAnnotationInkService.project(
            groups,
            into: second,
            knownAnchors: [.stage(order: 1)]
        )
        let restored = try PKDrawing(data: projected.drawingData)

        #expect(abs(restored.bounds.midX - 400) < 1)
        #expect(abs(restored.bounds.midY - 300) < 1)
        #expect(projected.groups.first?.resolutionState == .resolved)
    }

    @Test func collapsedInkIsNotRenderedButItsGroupSurvives() throws {
        let drawing = PKDrawing(strokes: [makeStroke(from: CGPoint(x: 90, y: 95), to: CGPoint(x: 110, y: 105))])
        let expanded = makeLayoutSnapshot(
            anchors: [anchorFrame(.transition(stageOrder: 1), x: 100, y: 100)],
            fingerprint: "expanded"
        )
        let groups = MindTreeAnnotationInkService.groups(
            from: drawing.dataRepresentation(),
            in: expanded,
            fingerprint: expanded.fingerprint
        )
        let collapsed = makeLayoutSnapshot(anchors: [], fingerprint: "collapsed")
        let projected = MindTreeAnnotationInkService.project(
            groups,
            into: collapsed,
            knownAnchors: [.transition(stageOrder: 1)]
        )
        let restored = try PKDrawing(data: projected.drawingData)

        #expect(restored.strokes.isEmpty)
        #expect(projected.groups.count == 1)
        #expect(projected.groups[0].resolutionState == .hidden)
    }
    #endif

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

    private struct LegacyTextItem: Codable {
        var id: UUID
        var text: String
        var x: Double
        var y: Double
        var width: Double
        var height: Double
        var createdAt: Date
        var updatedAt: Date
    }

    private func makeLayoutSnapshot(
        anchors: [MindTreeAnnotationAnchorFrame],
        width: Double = 1000,
        height: Double = 1000,
        fingerprint: String
    ) -> MindTreeAnnotationLayoutSnapshot {
        MindTreeAnnotationLayoutSnapshot(
            anchors: anchors,
            contentWidth: width,
            contentHeight: height,
            expandedTransitionOrders: "",
            expandedArchivedStageOrders: "",
            fingerprint: fingerprint,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func anchorFrame(
        _ anchor: MindTreeAnnotationAnchor,
        x: Double,
        y: Double
    ) -> MindTreeAnnotationAnchorFrame {
        MindTreeAnnotationAnchorFrame(
            anchor: anchor,
            nodeID: anchor.stableID,
            x: x,
            y: y,
            width: 100,
            height: 80
        )
    }

    #if os(iOS) && canImport(PencilKit)
    private func makeStroke(from start: CGPoint, to end: CGPoint) -> PKStroke {
        let points = [
            PKStrokePoint(
                location: start,
                timeOffset: 0,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 0.5,
                azimuth: 0,
                altitude: .pi / 2
            ),
            PKStrokePoint(
                location: end,
                timeOffset: 0.1,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 0.5,
                azimuth: 0,
                altitude: .pi / 2
            ),
        ]
        return PKStroke(
            ink: PKInk(.pen, color: .systemBlue),
            path: PKStrokePath(controlPoints: points, creationDate: Date())
        )
    }
    #endif

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

    @MainActor
    private func makeLegacy11Data(from package: CoDesignPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        object["schemaVersion"] = "1.1"
        if var annotations = object["mindTreeAnnotations"] as? [[String: Any]] {
            let modernKeys = [
                "anchoredInkData",
                "layoutSnapshotsData",
                "annotationDocumentVersion",
                "lastKnownFingerprint",
                "migrationStateRaw",
                "legacySourceAnnotationID",
            ]
            annotations = annotations.map { annotation in
                var legacy = annotation
                modernKeys.forEach { legacy.removeValue(forKey: $0) }
                return legacy
            }
            object["mindTreeAnnotations"] = annotations
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
