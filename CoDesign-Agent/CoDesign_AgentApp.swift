//
//  CoDesign_AgentApp.swift
//  CoDesign-Agent
//
//  Created by mac on 2026/5/28.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ServiceMode

enum ServiceMode: String {
    case mock
    case live
}

// MARK: - EnvironmentKeys

private struct LLMServiceKey: EnvironmentKey {
    static let defaultValue: any LLMServiceProtocol = MockLLMService()
}

extension EnvironmentValues {
    var llmService: any LLMServiceProtocol {
        get { self[LLMServiceKey.self] }
        set { self[LLMServiceKey.self] = newValue }
    }
}

private struct StructuredExtractorKey: EnvironmentKey {
    static let defaultValue: any StructuredExtractorProtocol = MockStructuredExtractor()
}

extension EnvironmentValues {
    var structuredExtractor: any StructuredExtractorProtocol {
        get { self[StructuredExtractorKey.self] }
        set { self[StructuredExtractorKey.self] = newValue }
    }
}

// MARK: - App

@main
struct CoDesign_AgentApp: App {
    @AppStorage("serviceMode") private var serviceModeRaw: String = "mock"

    init() {
        configureScrollIndicators()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self,
            ChatMessage.self,
            DesignBrief.self,
            ProgressStage.self,
            BoundaryItem.self,
            RiskItem.self,
            SuccessMetric.self,
            LearningTrace.self,
            ExtractionAuditLog.self,
            ThinkingMoment.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var serviceMode: ServiceMode {
        ServiceMode(rawValue: serviceModeRaw) ?? .mock
    }

    var llmService: any LLMServiceProtocol {
        serviceMode == .live ? LiveLLMService() : MockLLMService()
    }

    var extractor: any StructuredExtractorProtocol {
        serviceMode == .live ? LiveStructuredExtractor() : MockStructuredExtractor()
    }

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .coDesignHideScrollIndicators()
                .environment(\.llmService, llmService)
                .environment(\.structuredExtractor, extractor)
                .task {
                    SeedDataFactory.seedIfNeeded(
                        context: sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func configureScrollIndicators() {
        #if canImport(UIKit)
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        #endif
    }
}
