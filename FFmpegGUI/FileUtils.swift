import Foundation
import AppKit
import UniformTypeIdentifiers

enum FileUtils {
    static func showSavePanel(allowedContentTypes: [UTType], defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = allowedContentTypes
        panel.nameFieldStringValue = defaultName

        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}
