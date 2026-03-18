//
//  FileUtils.swift
//  FFmpegGUI
//
//  Shared utilities for file operations
//

import AppKit
import UniformTypeIdentifiers

struct FileUtils {
    /// Shows an NSSavePanel and returns the selected path if the user clicks OK.
    /// - Parameters:
    ///   - allowedContentTypes: The types of files the user is allowed to save.
    ///   - defaultName: The default name for the file in the save panel.
    /// - Returns: The selected file path string, or nil if the user cancelled.
    static func showSavePanel(allowedContentTypes: [UTType], defaultName: String? = nil) -> String? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = allowedContentTypes
        if let defaultName = defaultName {
            panel.nameFieldStringValue = defaultName
        }

        if panel.runModal() == .OK, let url = panel.url {
            return url.path
        }
        return nil
    }
}
