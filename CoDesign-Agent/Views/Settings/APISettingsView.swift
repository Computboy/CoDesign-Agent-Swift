import SwiftUI

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("serviceMode") private var serviceMode: String = "mock"
    @AppStorage("llmAPIKey") private var apiKey: String = ""
    @AppStorage("llmBaseURL") private var baseURL: String = ""
    @AppStorage("llmModel") private var model: String = ""
    @AppStorage("llmThinkingType") private var thinkingType: String = ""

    @State private var showClearAlert = false
    @State private var showDialogueGym = false

    var body: some View {
        NavigationStack {
            Form {
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

                    TextField("Base URL", text: $baseURL, prompt: Text("https://api.deepseek.com"))

                    TextField("Model", text: $model, prompt: Text("deepseek-v4-flash"))

                    Picker("Thinking Type", selection: $thinkingType) {
                        Text("不发送").tag("")
                        Text("disabled").tag("disabled")
                        Text("enabled").tag("enabled")
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

                // MARK: - Developer Section

                Section {
                    Button {
                        showDialogueGym = true
                    } label: {
                        Label("Run Dialogue Gym", systemImage: "figure.mind.and.body")
                    }

                    Text("Developer-only 工具：调用真实 CoDesign Agent + LLM 模拟学生 + LLM 评估对话质量")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Developer")
                }
            }
            .navigationTitle("API 设置")
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
            .sheet(isPresented: $showDialogueGym) {
                DialogueGymDebugView()
            }
        }
    }

    private func clearConfiguration() {
        apiKey = ""
        baseURL = ""
        model = ""
        thinkingType = ""
    }
}

#Preview {
    APISettingsView()
}
