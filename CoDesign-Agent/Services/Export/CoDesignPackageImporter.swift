import Foundation
import SwiftData

struct CoDesignPackageImporter {
    static let supportedSchemaVersions: Set<String> = ["1.0", "1.1", "1.2"]

    func loadPackage(from url: URL) throws -> CoDesignPackage {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let package = try decoder.decode(CoDesignPackage.self, from: data)
            guard package.documentType == "codesign.project" else {
                throw ReportExportError.invalidPackage("documentType 应为 codesign.project。")
            }
            return package
        } catch let error as ReportExportError {
            throw error
        } catch {
            throw ReportExportError.decodingFailed(error.localizedDescription)
        }
    }

    @MainActor
    func importAsNewProject(package: CoDesignPackage, context: ModelContext) throws -> Project {
        try validateForImport(package)

        let now = Date()
        let project = Project(
            name: "\(package.project.name)（导入）",
            briefDescription: package.project.briefDescription,
            createdAt: now,
            updatedAt: now
        )
        context.insert(project)

        let brief = DesignBrief(
            targetUser: package.brief.targetUser,
            painPoint: package.brief.painPoint,
            useScenario: package.brief.useScenario,
            coreValue: package.brief.coreValue,
            differentiation: package.brief.differentiation,
            mvpFeatures: package.brief.mvpFeatures,
            technicalModules: package.brief.technicalModules,
            interactionFlow: package.brief.interactionFlow,
            operationLogic: package.brief.operationLogic,
            hardConstraints: package.brief.hardConstraints,
            milestones: package.brief.milestones
        )
        context.insert(brief)
        project.brief = brief

        brief.boundaryItems = package.brief.boundaryItems.map { item in
            let model = BoundaryItem(content: item.content, isIncluded: item.isIncluded)
            context.insert(model)
            return model
        }
        brief.successMetrics = package.brief.successMetrics.map { item in
            let model = SuccessMetric(metric: item.metric, target: item.target, measurement: item.measurement)
            context.insert(model)
            return model
        }
        brief.risks = package.brief.risks.map { item in
            let model = RiskItem(
                desc: item.desc,
                probability: item.probability,
                impact: item.impact,
                mitigation: item.mitigation
            )
            context.insert(model)
            return model
        }

        project.stages = restoredStages(from: package, context: context)
        let momentNodes = package.mindTree.nodes
            .filter { $0.momType != "project" && $0.momType != "stage" }
        var importedMomentIDs: [String: UUID] = [:]
        for node in momentNodes {
            importedMomentIDs[strippedMomentID(node.id)] = UUID()
        }

        project.thinkingMoments = momentNodes
            .compactMap { node in
                let sourceID = strippedMomentID(node.id)
                guard let newID = importedMomentIDs[sourceID] else { return nil }
                let parentID = node.parentID.map(strippedMomentID).flatMap { importedMomentIDs[$0] }
                let model = ThinkingMoment(
                    id: newID,
                    momType: node.momType,
                    content: node.content,
                    stageOrder: node.stageOrder,
                    relatedField: node.relatedField,
                    parentMomentID: parentID,
                    timestamp: node.timestamp ?? now,
                    isActiveBranch: node.isActiveBranch,
                    branchVersion: node.branchVersion,
                    archivedAt: node.archivedAt
                )
                context.insert(model)
                return model
            }

        project.learningTraces = package.learningTraces.map { trace in
            let model = LearningTrace(
                id: UUID(),
                stageOrder: trace.stageOrder,
                actionType: trace.actionType,
                title: trace.title,
                detail: trace.detail,
                timestamp: trace.timestamp
            )
            context.insert(model)
            return model
        }

        let momentIDMapping = importedMomentIDs.reduce(into: [UUID: UUID]()) { result, pair in
            guard let sourceUUID = UUID(uuidString: pair.key) else { return }
            result[sourceUUID] = pair.value
        }
        project.mindTreeAnnotations = (package.mindTreeAnnotations ?? []).map { annotation in
            let model = MindTreeAnnotation(
                id: UUID(),
                drawingData: annotation.drawingData,
                textItemsData: remappedTextItemsData(
                    annotation.textItemsData,
                    momentIDMapping: momentIDMapping
                ),
                anchoredInkData: remappedInkData(
                    annotation.anchoredInkData,
                    momentIDMapping: momentIDMapping
                ),
                layoutSnapshotsData: remappedLayoutSnapshotsData(
                    annotation.layoutSnapshotsData,
                    momentIDMapping: momentIDMapping
                ),
                contentWidth: annotation.contentWidth,
                contentHeight: annotation.contentHeight,
                treeFingerprint: annotation.treeFingerprint,
                annotationDocumentVersion: annotation.annotationDocumentVersion,
                lastKnownFingerprint: annotation.lastKnownFingerprint,
                migrationStateRaw: annotation.migrationStateRaw,
                legacySourceAnnotationID: annotation.legacySourceAnnotationID.flatMap(UUID.init(uuidString:)),
                expandedTransitionOrders: annotation.expandedTransitionOrders,
                expandedArchivedStageOrders: annotation.expandedArchivedStageOrders,
                authorName: annotation.authorName,
                authorRole: annotation.authorRole,
                createdAt: annotation.createdAt,
                updatedAt: annotation.updatedAt,
                isArchived: annotation.isArchived,
                project: project
            )
            context.insert(model)
            return model
        }

        do {
            try context.save()
            return project
        } catch {
            throw ReportExportError.importFailed(error.localizedDescription)
        }
    }

    func validateForImport(_ package: CoDesignPackage) throws {
        guard package.documentType == "codesign.project" else {
            throw ReportExportError.invalidPackage("documentType 应为 codesign.project。")
        }
        guard Self.supportedSchemaVersions.contains(package.schemaVersion) else {
            throw ReportExportError.unsupportedSchema(package.schemaVersion)
        }
    }

    private func restoredStages(from package: CoDesignPackage, context: ModelContext) -> [ProgressStage] {
        let stageSnapshots = package.stages.isEmpty
            ? StageDefinition.all.map {
                StageExportSnapshot(
                    id: UUID().uuidString,
                    order: $0.order,
                    name: $0.name,
                    status: $0.order == package.project.currentStageOrder ? "active" : "notStarted",
                    completionRatio: 0,
                    lastUpdated: nil
                )
            }
            : package.stages

        return stageSnapshots.sorted { $0.order < $1.order }.map { stage in
            let model = ProgressStage(
                id: UUID(),
                order: stage.order,
                name: stage.name,
                status: stage.status,
                completionRatio: stage.completionRatio,
                lastUpdated: stage.lastUpdated
            )
            context.insert(model)
            return model
        }
    }

    private func strippedMomentID(_ id: String) -> String {
        id.replacingOccurrences(of: "moment-", with: "")
    }

    private func remappedTextItemsData(
        _ data: Data?,
        momentIDMapping: [UUID: UUID]
    ) -> Data? {
        guard let data,
              let items = try? JSONDecoder().decode([MindTreeTextAnnotationItem].self, from: data)
        else {
            return data
        }
        let remapped = items.map { item in
            var copy = item
            copy.anchor = item.anchor?.remappingMomentIDs(momentIDMapping)
            return copy
        }
        guard remapped != items else { return data }
        return try? JSONEncoder().encode(remapped)
    }

    private func remappedInkData(
        _ data: Data?,
        momentIDMapping: [UUID: UUID]
    ) -> Data? {
        guard let data,
              let groups = try? JSONDecoder().decode([MindTreeAnchoredInkGroup].self, from: data)
        else {
            return data
        }
        let remapped = groups.map { $0.remappingMomentIDs(momentIDMapping) }
        guard remapped != groups else { return data }
        return try? JSONEncoder().encode(remapped)
    }

    private func remappedLayoutSnapshotsData(
        _ data: Data?,
        momentIDMapping: [UUID: UUID]
    ) -> Data? {
        guard let data,
              let snapshots = try? JSONDecoder().decode(
                [MindTreeAnnotationLayoutSnapshot].self,
                from: data
              )
        else {
            return data
        }
        let remapped = snapshots.map { $0.remappingMomentIDs(momentIDMapping) }
        guard remapped != snapshots else { return data }
        return try? JSONEncoder().encode(remapped)
    }
}
