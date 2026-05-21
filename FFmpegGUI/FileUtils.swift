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
}
