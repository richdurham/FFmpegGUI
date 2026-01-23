//
//  FFmpegGUIApp.swift
//  FFmpegGUI
//
//  A macOS GUI wrapper for FFmpeg commands
//

import SwiftUI

@main
struct FFmpegGUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
    }
}
