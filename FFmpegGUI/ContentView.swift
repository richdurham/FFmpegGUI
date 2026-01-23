//
//  ContentView.swift
//  FFmpegGUI
//
//  Main UI with tabs for all FFmpeg operations
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var ffmpeg = FFmpegWrapper()
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(ffmpeg: ffmpeg)
            
            Divider()
            
            // Tab Selection
            HStack(spacing: 0) {
                TabButton(title: "Convert", icon: "arrow.triangle.2.circlepath", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Trim", icon: "scissors", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "Merge", icon: "rectangle.stack.badge.plus", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                TabButton(title: "Images → Video", icon: "photo.stack", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
            
            // Content Area
            ScrollView {
                VStack {
                    switch selectedTab {
                    case 0:
                        ConvertView(ffmpeg: ffmpeg, showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                    case 1:
                        TrimView(ffmpeg: ffmpeg, showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                    case 2:
                        MergeView(ffmpeg: ffmpeg, showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                    case 3:
                        ImageSequenceView(ffmpeg: ffmpeg, showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                    default:
                        ConvertView(ffmpeg: ffmpeg, showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Status/Log Area
            StatusView(ffmpeg: ffmpeg)
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var ffmpeg: FFmpegWrapper
    @State private var ffmpegInstalled = false
    @State private var ffmpegVersion = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FFmpeg GUI")
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(ffmpegInstalled ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(ffmpegInstalled ? ffmpegVersion : "FFmpeg not found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if ffmpeg.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    
                    Button("Cancel") {
                        ffmpeg.cancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .onAppear {
            ffmpegInstalled = ffmpeg.isFFmpegInstalled()
            if ffmpegInstalled {
                ffmpegVersion = ffmpeg.getFFmpegVersion()
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .secondary)
    }
}

// MARK: - Convert View

struct ConvertView: View {
    @ObservedObject var ffmpeg: FFmpegWrapper
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var inputPath = ""
    @State private var outputPath = ""
    @State private var selectedVideoCodec = 0
    @State private var selectedAudioCodec = 0
    @State private var videoBitrate = ""
    @State private var audioBitrate = ""
    @State private var selectedOutputFormat = "mp4"
    
    let outputFormats = ["mp4", "mov", "avi", "mkv", "webm", "mp3", "aac", "wav", "flac"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Convert Video/Audio Format")
                .font(.headline)
            
            // Input File
            GroupBox("Input File") {
                HStack {
                    TextField("Select input file...", text: $inputPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectInputFile()
                    }
                }
                .padding(8)
            }
            
            // Output Settings
            GroupBox("Output Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Format:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $selectedOutputFormat) {
                            ForEach(outputFormats, id: \.self) { format in
                                Text(format.uppercased()).tag(format)
                            }
                        }
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Video Codec:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $selectedVideoCodec) {
                            ForEach(0..<SupportedFormats.videoCodecs.count, id: \.self) { index in
                                Text(SupportedFormats.videoCodecs[index].0).tag(index)
                            }
                        }
                        .frame(width: 200)
                    }
                    
                    HStack {
                        Text("Audio Codec:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $selectedAudioCodec) {
                            ForEach(0..<SupportedFormats.audioCodecs.count, id: \.self) { index in
                                Text(SupportedFormats.audioCodecs[index].0).tag(index)
                            }
                        }
                        .frame(width: 200)
                    }
                    
                    HStack {
                        Text("Video Bitrate:")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g., 5M, 2000k", text: $videoBitrate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                        Text("(optional)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Audio Bitrate:")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g., 192k, 320k", text: $audioBitrate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                        Text("(optional)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(8)
            }
            
            // Output File
            GroupBox("Output File") {
                HStack {
                    TextField("Select output location...", text: $outputPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectOutputFile()
                    }
                }
                .padding(8)
            }
            
            // Convert Button
            HStack {
                Spacer()
                Button("Convert") {
                    startConversion()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputPath.isEmpty || outputPath.isEmpty || ffmpeg.isProcessing)
            }
        }
    }
    
    private func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            inputPath = url.path
            // Auto-generate output path
            let inputURL = URL(fileURLWithPath: inputPath)
            let outputURL = inputURL.deletingPathExtension().appendingPathExtension(selectedOutputFormat)
            outputPath = outputURL.path
        }
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: selectedOutputFormat) ?? .movie]
        panel.nameFieldStringValue = "output.\(selectedOutputFormat)"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startConversion() {
        let videoCodec = SupportedFormats.videoCodecs[selectedVideoCodec].1
        let audioCodec = SupportedFormats.audioCodecs[selectedAudioCodec].1
        
        ffmpeg.convertFormat(
            inputPath: inputPath,
            outputPath: outputPath,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            videoBitrate: videoBitrate.isEmpty ? nil : videoBitrate,
            audioBitrate: audioBitrate.isEmpty ? nil : audioBitrate
        ) { success, message in
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            showAlert = true
        }
    }
}

// MARK: - Trim View

struct TrimView: View {
    @ObservedObject var ffmpeg: FFmpegWrapper
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var inputPath = ""
    @State private var outputPath = ""
    @State private var startTime = ""
    @State private var endTime = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Trim Video")
                .font(.headline)
            
            // Input File
            GroupBox("Input File") {
                HStack {
                    TextField("Select input file...", text: $inputPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectInputFile()
                    }
                }
                .padding(8)
            }
            
            // Trim Settings
            GroupBox("Trim Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Start Time:")
                            .frame(width: 100, alignment: .leading)
                        TextField("HH:MM:SS or seconds", text: $startTime)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        Text("e.g., 00:01:30 or 90")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("End Time:")
                            .frame(width: 100, alignment: .leading)
                        TextField("HH:MM:SS or seconds", text: $endTime)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        Text("e.g., 00:05:00 or 300")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Text("Leave empty to trim from start or to end")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            
            // Output File
            GroupBox("Output File") {
                HStack {
                    TextField("Select output location...", text: $outputPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectOutputFile()
                    }
                }
                .padding(8)
            }
            
            // Trim Button
            HStack {
                Spacer()
                Button("Trim Video") {
                    startTrim()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputPath.isEmpty || outputPath.isEmpty || ffmpeg.isProcessing)
            }
        }
    }
    
    private func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            inputPath = url.path
            // Auto-generate output path
            let inputURL = URL(fileURLWithPath: inputPath)
            let baseName = inputURL.deletingPathExtension().lastPathComponent
            let ext = inputURL.pathExtension
            let outputURL = inputURL.deletingLastPathComponent()
                .appendingPathComponent("\(baseName)_trimmed.\(ext)")
            outputPath = outputURL.path
        }
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        let inputURL = URL(fileURLWithPath: inputPath)
        let ext = inputURL.pathExtension
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .movie]
        panel.nameFieldStringValue = "trimmed.\(ext)"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startTrim() {
        ffmpeg.trimVideo(
            inputPath: inputPath,
            outputPath: outputPath,
            startTime: startTime,
            endTime: endTime
        ) { success, message in
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            showAlert = true
        }
    }
}

// MARK: - Merge View

struct MergeView: View {
    @ObservedObject var ffmpeg: FFmpegWrapper
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var inputFiles: [String] = []
    @State private var outputPath = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Merge Files")
                .font(.headline)
            
            // Input Files
            GroupBox("Input Files (in order)") {
                VStack(alignment: .leading, spacing: 8) {
                    // File List
                    if inputFiles.isEmpty {
                        Text("No files added. Click 'Add Files' to select files to merge.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        List {
                            ForEach(inputFiles.indices, id: \.self) { index in
                                HStack {
                                    Text("\(index + 1).")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30)
                                    Text(URL(fileURLWithPath: inputFiles[index]).lastPathComponent)
                                    Spacer()
                                    Button(action: { removeFile(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .onMove(perform: moveFiles)
                        }
                        .frame(height: 150)
                    }
                    
                    HStack {
                        Button("Add Files...") {
                            addFiles()
                        }
                        
                        Button("Clear All") {
                            inputFiles.removeAll()
                        }
                        .disabled(inputFiles.isEmpty)
                        
                        Spacer()
                        
                        Text("\(inputFiles.count) file(s)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
            
            // Output File
            GroupBox("Output File") {
                HStack {
                    TextField("Select output location...", text: $outputPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectOutputFile()
                    }
                }
                .padding(8)
            }
            
            // Info
            Text("Note: Files should have the same codec and resolution for best results.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Merge Button
            HStack {
                Spacer()
                Button("Merge Files") {
                    startMerge()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputFiles.count < 2 || outputPath.isEmpty || ffmpeg.isProcessing)
            }
        }
    }
    
    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            inputFiles.append(contentsOf: panel.urls.map { $0.path })
        }
    }
    
    private func removeFile(at index: Int) {
        inputFiles.remove(at: index)
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        inputFiles.move(fromOffsets: source, toOffset: destination)
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        if let firstFile = inputFiles.first {
            let ext = URL(fileURLWithPath: firstFile).pathExtension
            panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .movie]
            panel.nameFieldStringValue = "merged.\(ext)"
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startMerge() {
        ffmpeg.mergeFiles(inputPaths: inputFiles, outputPath: outputPath) { success, message in
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            showAlert = true
        }
    }
}

// MARK: - Image Sequence View

struct ImageSequenceView: View {
    @ObservedObject var ffmpeg: FFmpegWrapper
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var inputFolder = ""
    @State private var outputPath = ""
    @State private var frameRate = "24"
    @State private var selectedCodec = 0
    @State private var imageCount = 0
    @State private var analysisResult: FFmpegWrapper.ImageAnalysisResult?
    @State private var autoCorrectDimensions = true
    @State private var customWidth = ""
    @State private var customHeight = ""
    @State private var useCustomDimensions = false
    
    let codecs = [
        ("H.264 (Best Compatibility)", "libx264"),
        ("H.265/HEVC (Better Compression)", "libx265"),
        ("ProRes (High Quality)", "prores_ks")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Image Sequence to Video")
                .font(.headline)
            
            // Input Folder
            GroupBox("Input Folder") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Select folder containing images...", text: $inputFolder)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectInputFolder()
                        }
                    }
                    
                    if imageCount > 0 {
                        Text("\(imageCount) image(s) found")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    // Dimension analysis
                    if let analysis = analysisResult {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Most common size:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(analysis.mostCommonDimension.width)×\(analysis.mostCommonDimension.height)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("(\(analysis.mostCommonDimension.count) images)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let warning = analysis.warningMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(warning)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if analysis.hasMixedSizes {
                                Text("Sizes: " + analysis.uniqueDimensions.map { "\($0.width)×\($0.height) (\($0.count))" }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(8)
            }
            
            // Dimension Controls
            GroupBox("Dimension Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-correct odd dimensions", isOn: $autoCorrectDimensions)
                        .help("Automatically ensures width and height are even numbers (required for most codecs)")
                    
                    Toggle("Use custom dimensions", isOn: $useCustomDimensions)
                    
                    if useCustomDimensions {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Width:")
                                    .frame(width: 60, alignment: .leading)
                                TextField("Auto", text: $customWidth)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                Text("px")
                                
                                Spacer().frame(width: 20)
                                
                                Text("Height:")
                                    .frame(width: 60, alignment: .leading)
                                TextField("Auto", text: $customHeight)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                Text("px")
                            }
                            
                            HStack(spacing: 8) {
                                Text("Presets:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("1920×1080") { customWidth = "1920"; customHeight = "1080" }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Button("1280×720") { customWidth = "1280"; customHeight = "720" }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Button("3840×2160") { customWidth = "3840"; customHeight = "2160" }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                if let analysis = analysisResult {
                                    Button("Original (\(analysis.mostCommonDimension.width)×\(analysis.mostCommonDimension.height))") {
                                        customWidth = String(analysis.mostCommonDimension.width)
                                        customHeight = String(analysis.mostCommonDimension.height)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            Text("Leave blank for auto-calculation. Scale filter: Lanczos (high quality)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }
            
            // Settings
            GroupBox("Video Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Frame Rate:")
                            .frame(width: 100, alignment: .leading)
                        TextField("FPS", text: $frameRate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("fps")
                        
                        Spacer()
                        
                        // Quick presets
                        Text("Presets:")
                            .foregroundColor(.secondary)
                        Button("24") { frameRate = "24" }
                            .buttonStyle(.bordered)
                        Button("30") { frameRate = "30" }
                            .buttonStyle(.bordered)
                        Button("60") { frameRate = "60" }
                            .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Text("Codec:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $selectedCodec) {
                            ForEach(0..<codecs.count, id: \.self) { index in
                                Text(codecs[index].0).tag(index)
                            }
                        }
                        .frame(width: 280)
                    }
                    
                    Text("Supported formats: PNG, JPG, JPEG, BMP, TIFF")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            
            // Output File
            GroupBox("Output File") {
                HStack {
                    TextField("Select output location...", text: $outputPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectOutputFile()
                    }
                }
                .padding(8)
            }
            
            // Duration estimate
            if imageCount > 0, let fps = Int(frameRate), fps > 0 {
                let duration = Double(imageCount) / Double(fps)
                Text("Estimated duration: \(String(format: "%.2f", duration)) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Create Video Button
            HStack {
                Spacer()
                Button("Create Video") {
                    startImageSequence()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputFolder.isEmpty || outputPath.isEmpty || imageCount == 0 || ffmpeg.isProcessing)
            }
        }
    }
    
    private func selectInputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK, let url = panel.url {
            inputFolder = url.path
            countImages()
            
            // Auto-generate output path
            outputPath = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent)_video.mp4").path
        }
    }
    
    private func countImages() {
        let fileManager = FileManager.default
        let imageExtensions = ["png", "jpg", "jpeg", "bmp", "tiff", "tif"]
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: inputFolder)
            imageCount = files.filter { file in
                let ext = (file as NSString).pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }.count
            
            // Analyze dimensions
            analysisResult = ffmpeg.analyzeImageDimensions(in: inputFolder)
        } catch {
            imageCount = 0
            analysisResult = nil
        }
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "output.mp4"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startImageSequence() {
        let fps = Int(frameRate) ?? 24
        let codec = codecs[selectedCodec].1
        
        let targetW = useCustomDimensions && !customWidth.isEmpty ? Int(customWidth) : nil
        let targetH = useCustomDimensions && !customHeight.isEmpty ? Int(customHeight) : nil
        
        ffmpeg.imageSequenceToVideo(
            inputFolder: inputFolder,
            outputPath: outputPath,
            frameRate: fps,
            videoCodec: codec,
            autoCorrectDimensions: autoCorrectDimensions,
            targetWidth: targetW,
            targetHeight: targetH
        ) { success, message in
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            showAlert = true
        }
    }
}

// MARK: - Status View

struct StatusView: View {
    @ObservedObject var ffmpeg: FFmpegWrapper
    @State private var showLog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if ffmpeg.isProcessing {
                    ProgressView(value: ffmpeg.progress)
                        .frame(width: 200)
                }
                
                Text(ffmpeg.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(showLog ? "Hide Log" : "Show Log") {
                    showLog.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if showLog {
                ScrollView {
                    Text(ffmpeg.outputLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 150)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
