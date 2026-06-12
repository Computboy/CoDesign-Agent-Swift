import Foundation

#if os(iOS)
import UIKit
import ObjectiveC

struct TemporaryExportFile: Identifiable {
    let id = UUID()
    let url: URL

    init(data: Data, defaultFilename: String) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoDesignExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(defaultFilename)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
        url = fileURL
    }
}

@MainActor
enum DocumentExportPresenter {
    static func present(fileURL: URL, onCompletion: @escaping (Result<URL, Error>) -> Void) {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        let delegate = DocumentExportDelegate(fileURL: fileURL, onCompletion: onCompletion)
        picker.delegate = delegate
        objc_setAssociatedObject(
            picker,
            &documentExportDelegateKey,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        guard let presenter = topViewController() else {
            let error = NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.fileNoSuchFile.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "没有找到可用于导出的窗口。"]
            )
            onCompletion(.failure(error))
            return
        }

        presenter.present(picker, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let navigation = root as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }

        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }

        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }

        return root
    }
}

private var documentExportDelegateKey: UInt8 = 0

private final class DocumentExportDelegate: NSObject, UIDocumentPickerDelegate {
    let fileURL: URL
    let onCompletion: (Result<URL, Error>) -> Void

    init(fileURL: URL, onCompletion: @escaping (Result<URL, Error>) -> Void) {
        self.fileURL = fileURL
        self.onCompletion = onCompletion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onCompletion(.success(urls.first ?? fileURL))
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "导出已取消。"]
        )
        onCompletion(.failure(error))
    }
}
#endif
