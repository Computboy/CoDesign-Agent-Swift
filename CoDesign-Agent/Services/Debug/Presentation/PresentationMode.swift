#if DEBUG
import Foundation

enum PresentationMode {
    static let launchArgument = "PRESENTATION_MODE"
    static let projectName = "期末展示：非遗 AI 短视频共创"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
}
#endif
