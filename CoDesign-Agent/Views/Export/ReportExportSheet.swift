import SwiftUI
import UniformTypeIdentifiers

struct ReportExportSheet: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @State private var options = ReportExportOptions.defaults(for: .markdown)
    @State private var isExportingReport = false
    @State private var isExportingCodesign = false
    @State private var reportDocument = GeneratedReportDocument()
    @State private var codesignDocument = CoDesignPackageDocument(package: .empty)
    @State private var contentType: UTType = .markdownReport
    @State private var defaultFilename = "CoDesign报告.md"
    @State private var statusMessage: ExportStatusMessage?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    formatSection
                    optionsSection
                    formatExplanation

                    if let statusMessage {
                        statusView(statusMessage)
                    }
                }
                .padding(AppTheme.spacingLarge)
            }
            .background(Color.appBackground)
            .navigationTitle("导出 AI 产品设计报告")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("导出") {
                        export()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onChange(of: options.format) { _, newValue in
            options = ReportExportOptions.defaults(for: newValue)
            statusMessage = nil
        }
        .fileExporter(
            isPresented: $isExportingReport,
            document: reportDocument,
            contentType: contentType,
            defaultFilename: defaultFilename,
            onCompletion: handleExportResult
        )
        .fileExporter(
            isPresented: $isExportingCodesign,
            document: codesignDocument,
            contentType: .codesignProject,
            defaultFilename: defaultFilename,
            onCompletion: handleExportResult
        )
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("格式选择")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(ReportExportFormat.allCases) { format in
                    Button {
                        options = ReportExportOptions.defaults(for: format)
                    } label: {
                        ReportFormatRow(
                            format: format,
                            isSelected: options.format == format
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("导出内容")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 0) {
                Toggle("最终设计报告", isOn: $options.includeReportSections)
                    .disabled(options.format == .json || options.format == .codesignPackage)
                Toggle("设计决策路径", isOn: $options.includeDecisionTrace)
                    .disabled(true)
                Toggle("资源线索与引用", isOn: $options.includeResources)
                    .disabled(options.format == .json || options.format == .codesignPackage)
                Toggle("对话摘要", isOn: $options.includeConversationSummary)

                if options.format.isStaticReport {
                    Divider().padding(.vertical, AppTheme.spacingSmall)
                    Toggle("完整思维树快照", isOn: $options.includeFullMindTree)
                    Toggle("回溯分支与旧方案", isOn: $options.includeArchivedBranches)
                        .disabled(!options.includeFullMindTree)
                } else {
                    Divider().padding(.vertical, AppTheme.spacingSmall)
                    Toggle("完整思维树", isOn: .constant(true))
                        .disabled(true)
                    Toggle("回溯分支与旧方案", isOn: .constant(true))
                        .disabled(true)
                    Toggle("Design Brief", isOn: .constant(true))
                        .disabled(true)
                    Toggle("报告结构", isOn: .constant(true))
                        .disabled(true)
                }
            }
            .toggleStyle(.switch)
            .font(AppTheme.Typography.body)
            .padding(AppTheme.Layout.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
            )
        }
    }

    @ViewBuilder
    private var formatExplanation: some View {
        if options.format == .codesignPackage {
            Label(
                "此文件可在 CoDesign Agent 中重新打开，查看可交互思维树、设计决策路径、回溯分支、Design Brief 与资源线索。",
                systemImage: "point.3.connected.trianglepath.dotted"
            )
            .font(AppTheme.Typography.caption)
            .foregroundStyle(Color.primaryAccent)
            .padding(AppTheme.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(Color.primaryAccent.opacity(AppTheme.Opacity.light))
            )
        }
    }

    private func statusView(_ message: ExportStatusMessage) -> some View {
        Label(message.text, systemImage: message.isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
            .font(AppTheme.Typography.caption.weight(.medium))
            .foregroundStyle(message.isError ? Color.danger : Color.success)
            .padding(AppTheme.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill((message.isError ? Color.danger : Color.success).opacity(AppTheme.Opacity.light))
            )
    }

    private func export() {
        var exportOptions = options
        exportOptions.normalizeForFormat()
        let snapshot = ProjectReportSnapshotBuilder().build(project: project, options: exportOptions)
        defaultFilename = ReportFileWriter.defaultFileName(projectName: project.name, format: exportOptions.format)
        contentType = exportOptions.format.contentType

        do {
            switch exportOptions.format {
            case .markdown:
                let markdown = MarkdownReportRenderer().render(snapshot: snapshot)
                reportDocument = GeneratedReportDocument(data: Data(markdown.utf8))
                isExportingReport = true
            case .json:
                reportDocument = GeneratedReportDocument(data: try JSONReportRenderer().render(snapshot: snapshot))
                isExportingReport = true
            case .pdf:
                reportDocument = GeneratedReportDocument(data: try PDFReportRenderer().render(snapshot: snapshot))
                isExportingReport = true
            case .codesignPackage:
                let package = CoDesignPackageBuilder().build(from: snapshot)
                codesignDocument = CoDesignPackageDocument(package: package)
                isExportingCodesign = true
            }
        } catch {
            statusMessage = ExportStatusMessage(text: error.localizedDescription, isError: true)
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            statusMessage = ExportStatusMessage(text: "导出文件已生成", isError: false)
        case .failure(let error):
            statusMessage = ExportStatusMessage(text: error.localizedDescription, isError: true)
        }
    }
}

private struct ReportFormatRow: View {
    let format: ReportExportFormat
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? Color.primaryAccent : Color.textTertiary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text(format.displayName)
                    .font(AppTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(format.subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(isSelected ? Color.primaryAccent.opacity(AppTheme.Opacity.light) : Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.primaryAccent.opacity(AppTheme.Opacity.noticeable) : AppTheme.Border.color,
                    lineWidth: AppTheme.Border.thin
                )
        )
    }
}

private struct ExportStatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}
