import SwiftUI

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("serviceMode") private var serviceMode: String = "mock"
    @AppStorage("llmBaseURL") private var baseURL: String = ""
    @AppStorage("llmModel") private var model: String = ""
    @AppStorage("llmThinkingType") private var thinkingType: String = ""
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRaw = AppAppearance.system.rawValue

    @State private var apiKey: String = APIKeyStore.load()
    @State private var apiKeyStorageError: String?
    @FocusState private var focusedField: APISettingsField?
    @State private var showClearAlert = false
    @State private var isTestingAPI = false
    @State private var apiTestSucceeded: Bool?
    @State private var apiTestMessage: String?
    @State private var lastTestedConfigurationFingerprint: String?
    #if DEBUG
    @State private var showDialogueGym = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("界面主题", selection: $appAppearanceRaw) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Label(appearance.title, systemImage: appearance.systemImage)
                                .tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("可跟随系统外观，也可以固定使用浅色或深色主题。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Service Mode Section
                Section("服务模式") {
                    Picker("模式", selection: $serviceMode) {
                        Text("Mock（模拟）").tag("mock")
                        Text("Live（真实 API）").tag("live")
                    }
                    .pickerStyle(.segmented)

                    Text(serviceMode == "live" ? "使用真实 LLM API 进行对话" : "使用模拟数据进行演示")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // API Configuration Section
                Section("API 配置") {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .apiKey)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        #endif

                    TextField("Base URL", text: $baseURL, prompt: Text("https://api.deepseek.com"))
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .baseURL)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif

                    TextField("Model", text: $model, prompt: Text("deepseek-v4-flash"))
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .model)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        #endif

                    Picker("Thinking Type", selection: $thinkingType) {
                        Text("不发送").tag("")
                        Text("disabled").tag("disabled")
                        Text("enabled").tag("enabled")
                    }

                    Button {
                        beginAPIConnectionTest()
                    } label: {
                        HStack {
                            Label(
                                isTestingAPI ? "正在测试 API Key" : "测试 API Key",
                                systemImage: isTestingAPI ? "hourglass" : "checkmark.seal"
                            )

                            Spacer()

                            if isTestingAPI {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isTestingAPI || trimmedAPIKey.isEmpty)

                    if trimmedAPIKey.isEmpty {
                        Label("填入 API Key 后可以测试当前配置是否可用。", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if serviceMode != "live" {
                        Label("当前仍是 Mock 模式，聊天不会调用真实模型。测试成功后会自动切换到 Live。", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let apiTestMessage, let apiTestSucceeded {
                        Label(
                            apiTestMessage,
                            systemImage: apiTestSucceeded ? "checkmark.circle.fill" : "xmark.octagon.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(apiTestSucceeded ? .green : .red)
                    }

                    if let apiKeyStorageError {
                        Label(apiKeyStorageError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Quick Reference Section
                Section("快速参考：百炼 / DeepSeek 配置示例") {
                    DisclosureGroup("点击查看配置示例") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("百炼示例：")
                                .font(.caption.bold())
                            Text("Base URL: https://dashscope.aliyuncs.com/compatible-mode/v1")
                                .font(.caption2)
                            Text("Model: qwen-plus / qwen-turbo / qwen-max")
                                .font(.caption2)
                            Text("Thinking Type: 不发送")
                                .font(.caption2)

                            Divider()
                                .padding(.vertical, 4)

                            Text("DeepSeek 示例：")
                                .font(.caption.bold())
                            Text("Base URL: https://api.deepseek.com")
                                .font(.caption2)
                            Text("Model: deepseek-v4-flash")
                                .font(.caption2)
                            Text("Thinking Type: disabled")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Clear Configuration Section
                Section {
                    Button("清除 API 配置", role: .destructive) {
                        showClearAlert = true
                    }
                }

                #if DEBUG
                // MARK: - AI Dialogue Quality Lab
                Section {
                    Button {
                        showDialogueGym = true
                    } label: {
                        Label("AI Dialogue Quality Lab", systemImage: "figure.mind.and.body")
                    }

                    Text("调试工具：调用真实 CoDesign Agent + LLM 模拟学生 + LLM 评估对话质量")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("AI Dialogue Quality Lab")
                }
                #endif
            }
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("确认清除", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    clearConfiguration()
                }
            } message: {
                Text("这将清空所有 API 配置，但不会影响已有项目数据。")
            }
            .onChange(of: apiKey) { _, newValue in
                apiKeyStorageError = APIKeyStore.save(newValue)
                    ? nil
                    : "API Key 未能写入系统钥匙串，请稍后重试。"
                resetAPITestResult()
            }
            .onChange(of: baseURL) { _, _ in resetAPITestResult() }
            .onChange(of: model) { _, _ in resetAPITestResult() }
            .onChange(of: thinkingType) { _, _ in resetAPITestResult() }
            .interactiveDismissDisabled(isTestingAPI)
            #if DEBUG
            .sheet(isPresented: $showDialogueGym) {
                DialogueGymDebugView()
                    .presentationDragIndicator(.visible)
            }
            #endif
        }
    }

    private enum APISettingsField: Hashable {
        case apiKey
        case baseURL
        case model
    }

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveBaseURLString: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "https://api.deepseek.com" : trimmed
    }

    private var effectiveModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "deepseek-v4-flash" : trimmed
    }

    private var effectiveThinkingType: String? {
        let trimmed = thinkingType.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func clearConfiguration() {
        apiKey = ""
        APIKeyStore.delete()
        baseURL = ""
        model = ""
        thinkingType = ""
        serviceMode = "mock"
        resetAPITestResult()
    }

    private func resetAPITestResult() {
        guard !isTestingAPI else { return }
        guard configurationFingerprint != lastTestedConfigurationFingerprint else { return }
        apiTestSucceeded = nil
        apiTestMessage = nil
    }

    private func beginAPIConnectionTest() {
        guard !isTestingAPI else { return }
        focusedField = nil
        isTestingAPI = true
        apiTestSucceeded = nil
        apiTestMessage = nil
        lastTestedConfigurationFingerprint = nil

        Task {
            await testAPIConnection()
        }
    }

    @MainActor
    private func testAPIConnection() async {
        defer {
            isTestingAPI = false
        }

        guard !trimmedAPIKey.isEmpty else {
            apiTestSucceeded = false
            apiTestMessage = APIError.missingAPIKey.localizedDescription
            return
        }

        guard let url = URL(string: effectiveBaseURLString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            apiTestSucceeded = false
            apiTestMessage = APIError.invalidURL.localizedDescription
            return
        }

        let config = LLMAPIConfig(
            baseURL: url,
            apiKey: trimmedAPIKey,
            model: effectiveModel,
            timeoutSeconds: 20,
            thinkingType: effectiveThinkingType
        )
        let client = LLMAPIClient(config: config)

        do {
            let reply = try await client.testConnection()
            persistLiveConfiguration(config)
            serviceMode = "live"
            lastTestedConfigurationFingerprint = configurationFingerprint
            apiTestSucceeded = true
            apiTestMessage = "连接成功，已切换到 Live 模式。模型返回：\(shortMessage(reply))"
            NotificationCenter.default.post(name: LLMRuntimeNotification.configurationChanged, object: nil)
        } catch {
            apiTestSucceeded = false
            apiTestMessage = shortMessage(error.localizedDescription)
        }
    }

    private func persistLiveConfiguration(_ config: LLMAPIConfig) {
        apiKey = config.apiKey
        APIKeyStore.save(config.apiKey)
        baseURL = config.baseURL.absoluteString
        model = config.model
        thinkingType = config.thinkingType ?? ""
        UserDefaults.standard.synchronize()
    }

    private var configurationFingerprint: String {
        [
            apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            model.trimmingCharacters(in: .whitespacesAndNewlines),
            thinkingType.trimmingCharacters(in: .whitespacesAndNewlines),
        ].joined(separator: "\u{1F}")
    }

    private func shortMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 140 else { return trimmed }
        return String(trimmed.prefix(140)) + "..."
    }
}

#Preview {
    APISettingsView()
}
