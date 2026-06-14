#if DEBUG
import SwiftUI
import SwiftData

struct PresentationHostView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var project: Project?

    var body: some View {
        NavigationStack {
            Group {
                if let project {
                    ProjectDetailView(project: project, isPresentationMode: true)
                } else {
                    ProgressView("正在准备展示模式...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.appBackground)
                }
            }
        }
        .task {
            guard project == nil else { return }
            project = PresentationDemoDataFactory.resetProject(context: modelContext)
        }
    }
}
#endif
