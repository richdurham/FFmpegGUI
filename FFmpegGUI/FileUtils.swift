import Foundation
import UniformTypeIdentifiers
import AppKit

struct FileUtils {
    static func showSavePanel(allowedContentTypes: [UTType], defaultName: String?) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = allowedContentTypes
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save File"
        if let defaultName = defaultName {
            panel.nameFieldStringValue = defaultName
        }

        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }

    static func selectFileInputs(
        allowsMultipleSelection: Bool = false,
        canChooseDirectories: Bool = false,
        canChooseFiles: Bool = true,
        onComplete: ([URL]) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseDirectories = canChooseDirectories
        panel.canChooseFiles = canChooseFiles

        if panel.runModal() == .OK {
            onComplete(panel.urls)
        }
    }
}
