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
    @State private var openedPackage: CoDesignPackage?
    @State private var packageOpenError: String?
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRaw = AppAppearance.system.rawValue

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
            MindTreeAnnotation.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .coDesignHideScrollIndicators()
                .preferredColorScheme(appAppearance.colorScheme)
                .environment(\.llmService, ModeSwitchingLLMService())
                .environment(\.structuredExtractor, ModeSwitchingStructuredExtractor())
                .onOpenURL { url in
                    openCodesignPackage(at: url)
                }
                .sheet(item: $openedPackage) { package in
                    CoDesignPackagePreviewView(package: package)
                        #if os(iOS)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        #endif
                }
                .alert(
                    "打开项目包失败",
                    isPresented: Binding(
                        get: { packageOpenError != nil },
                        set: { if !$0 { packageOpenError = nil } }
                    )
                ) {
                    Button("好", role: .cancel) {
                        packageOpenError = nil
                    }
                } message: {
                    Text(packageOpenError ?? "")
                }
                .task {
                    SeedDataFactory.seedIfNeeded(
                        context: sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

    private func configureScrollIndicators() {
        #if canImport(UIKit)
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        #endif
    }

    private func openCodesignPackage(at url: URL) {
        guard url.pathExtension.lowercased() == "codesign" else { return }

        do {
            openedPackage = try CoDesignPackageImporter().loadPackage(from: url)
            packageOpenError = nil
        } catch {
            packageOpenError = error.localizedDescription
        }
    }
}

private final class ModeSwitchingLLMService: LLMServiceProtocol {
    private let mock = MockLLMService()
    private let live = LiveLLMService()

    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> AsyncThrowingStream<String, Error> {
        currentMode == .live
            ? live.streamChat(
                messages: messages,
                briefSnapshot: briefSnapshot,
                currentStage: currentStage,
                mode: mode,
                resourceCards: resourceCards
            )
            : mock.streamChat(
                messages: messages,
                briefSnapshot: briefSnapshot,
                currentStage: currentStage,
                mode: mode,
                resourceCards: resourceCards
            )
    }

    private var currentMode: ServiceMode {
        ServiceMode(rawValue: UserDefaults.standard.string(forKey: "serviceMode") ?? "") ?? .mock
    }
}

private final class ModeSwitchingStructuredExtractor: StructuredExtractorProtocol {
    private let mock = MockStructuredExtractor()
    private let live = LiveStructuredExtractor()

    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome {
        if currentMode == .live {
            return try await live.extract(from: messages, existing: existing)
        }
        return try await mock.extract(from: messages, existing: existing)
    }

    private var currentMode: ServiceMode {
        ServiceMode(rawValue: UserDefaults.standard.string(forKey: "serviceMode") ?? "") ?? .mock
    }
}
