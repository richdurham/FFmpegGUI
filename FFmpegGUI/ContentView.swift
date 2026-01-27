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
                TabButton(title: "Cut/Trim", icon: "scissors", isSelected: selectedTab == 1) {
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
                        CutTrimView(ffmpeg: ffmpeg, showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
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
    @State private var videoInfo: FFmpegWrapper.VideoDimensionInfo? = nil
    @State private var selectedVideoCodec = 0
    @State private var selectedAudioCodec = 0
    @State private var videoBitrate = ""
    @State private var audioBitrate = ""
    @State private var selectedOutputFormat = "mp4"
    
    // Scaling States
    @State private var resizeVideo = false
    @State private var scaleWidth = ""
    @State private var scaleHeight = ""
    @State private var selectedScaleFilter = 0
    @State private var lockAspectRatio = true
    
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
            
            // Input Video Info Display
            if let info = videoInfo {
                HStack {
                    Text("Input Dimensions:").fontWeight(.bold)
                    Text("\(info.resolutionString) (\(info.codec ?? "N/A"), \(String(format: "%.2f", info.frameRate ?? 0)) fps)")
                    if info.hasOddDimension {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("Odd dimensions detected (may cause issues)").foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .padding(.horizontal)
            }
            
            // Resize/Scale Options (Phase 2 UI)
            if videoInfo != nil {
                GroupBox("Resize/Scale Options") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Resize video", isOn: $resizeVideo)
                        
                        if resizeVideo {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Width:")
                                        .frame(width: 60, alignment: .leading)
                                    TextField("Auto", text: $scaleWidth)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                        .onChange(of: scaleWidth) { newValue in
                                            if lockAspectRatio, let info = videoInfo, let newWidth = Int(newValue), newWidth > 0 {
                                                let newHeight = Int(Double(newWidth) / info.aspectRatio)
                                                scaleHeight = String(newHeight)
                                            }
                                        }
                                    Text("px")
                                    
                                    Spacer().frame(width: 20)
                                    
                                    Text("Height:")
                                        .frame(width: 60, alignment: .leading)
                                    TextField("Auto", text: $scaleHeight)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                        .onChange(of: scaleHeight) { newValue in
                                            if lockAspectRatio, let info = videoInfo, let newHeight = Int(newValue), newHeight > 0 {
                                                let newWidth = Int(Double(newHeight) * info.aspectRatio)
                                                scaleWidth = String(newWidth)
                                            }
                                        }
                                    Text("px")
                                    
                                    Toggle("Lock Aspect Ratio", isOn: $lockAspectRatio)
                                        .frame(width: 150)
                                }
                                
                                HStack {
                                    Text("Scale Quality:")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $selectedScaleFilter) {
                                        ForEach(0..<SupportedFormats.scaleFilters.count, id: \.self) { index in
                                            Text(SupportedFormats.scaleFilters[index].0).tag(index)
                                        }
                                    }
                                    .frame(width: 200)
                                    
                                    Spacer()
                                    
                                    // Presets
                                    Group {
                                        Button("1080p") { scaleWidth = "1920"; scaleHeight = "1080" }
                                        Button("720p") { scaleWidth = "1280"; scaleHeight = "720" }
                                        Button("480p") { scaleWidth = "854"; scaleHeight = "480" }
                                        Button("4K") { scaleWidth = "3840"; scaleHeight = "2160" }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
            
            // Codec Settings
            GroupBox("Codec Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Video Codec:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $selectedVideoCodec) {
                            ForEach(0..<SupportedFormats.videoCodecs.count, id: \.self) { index in
                                Text(SupportedFormats.videoCodecs[index].0).tag(index)
                            }
                        }
                        .frame(width: 200)
                        
                        Text("Bitrate:")
                            .frame(width: 60, alignment: .leading)
                        TextField("Optional", text: $videoBitrate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("e.g., 5M, 5000k")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        
                        Text("Bitrate:")
                            .frame(width: 60, alignment: .leading)
                        TextField("Optional", text: $audioBitrate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("e.g., 192k, 320k")
                            .font(.caption)
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
                    
                    Picker("", selection: $selectedOutputFormat) {
                        ForEach(outputFormats, id: \.self) { format in
                            Text(".\(format)").tag(format)
                        }
                    }
                    .frame(width: 80)
                    
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
            
            // Get video info
            videoInfo = ffmpeg.getVideoDimensions(from: inputPath)
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
        let scaleFilter = SupportedFormats.scaleFilters[selectedScaleFilter].1
        
        var w: Int? = nil
        var h: Int? = nil
        
        if resizeVideo {
            w = Int(scaleWidth)
            h = Int(scaleHeight)
        }
        
        ffmpeg.convertFormat(
            inputPath: inputPath,
            outputPath: outputPath,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            videoBitrate: videoBitrate,
            audioBitrate: audioBitrate,
            scaleWidth: w,
            scaleHeight: h,
            scaleFilter: scaleFilter,
            autoCorrectOdd: videoInfo?.hasOddDimension ?? false
        ) { success, message in
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            showAlert = true
        }
    }
}

// MARK: - Cut/Trim View

struct CutTrimView: View {
    @ObservedObject var ffmpeg: FFmpegWrapper
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var inputPath = ""
    @State private var outputPath = ""
    @State private var videoInfo: FFmpegWrapper.VideoDimensionInfo? = nil
    @State private var proxyVideoPath: String? = nil
    
    // Trim States
    @State private var trimStartTime = ""
    @State private var trimEndTime = ""
    
    // Cut States
    @State private var segments: [FFmpegWrapper.CutSegment] = []
    @State private var exportSegmentsSeparately = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Interactive Cut & Trim")
                .font(.headline)
            
            // Input File
            GroupBox("Input File") {
                HStack {
                    TextField("Select input file...", text: $inputPath)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: inputPath) { newValue in
                            if !newValue.isEmpty {
                                loadVideoInfoAndProxy(path: newValue)
                            } else {
                                videoInfo = nil
                                proxyVideoPath = nil
                            }
                        }
                    
                    Button("Browse...") {
                        selectInputFile()
                    }
                }
                .padding(8)
            }
            
            // Video Preview and Controls (Phase 4.2)
            if let info = videoInfo {
                VStack(alignment: .leading, spacing: 10) {
                    // Video Player Placeholder
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .aspectRatio(info.aspectRatio, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                        
                        Text("Video Preview Placeholder")
                            .foregroundColor(.white)
                    }
                    
                    // Video Info Caption
                    Text("Input: \(info.resolutionString) (\(info.codec ?? "N/A"), \(String(format: "%.2f", info.frameRate ?? 0)) fps) - Duration: \(info.duration ?? 0, specifier: "%.2f")s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Playback Controls and Progress Bar Placeholder
                    HStack {
                        Button("Play") {}
                        Button("Pause") {}
                        Button("Trim Mark") {}
                        Button("Cut Mark") {}
                        
                        Spacer()
                        
                        Text("00:00:00 / \(info.duration ?? 0, specifier: "%.2f")s")
                    }
                    
                    // Progress Bar Placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 10)
                        .cornerRadius(5)
                }
                .padding(.horizontal)
            }
            
            // Trim and Cut Sections (Phase 4.3)
            HStack(alignment: .top, spacing: 20) {
                // Trim Section
                GroupBox("Trim (Keep a single segment)") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Defines the final start and end of the video.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Start Time:")
                                .frame(width: 80, alignment: .leading)
                            TextField("00:00:00", text: $trimStartTime)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("End Time:")
                                .frame(width: 80, alignment: .leading)
                            TextField("End of file", text: $trimEndTime)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(8)
                }
                
                // Cut Section
                GroupBox("Cut Segments (Remove or Export multiple parts)") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Segments to Keep:")
                                .fontWeight(.bold)
                            Spacer()
                            Button("Add Segment") {
                                segments.append(FFmpegWrapper.CutSegment(id: UUID(), start: "", end: ""))
                            }
                        }
                        
                        List {
                            ForEach($segments) { $segment in
                                HStack {
                                    TextField("Start", text: $segment.start)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Text("-")
                                    TextField("End", text: $segment.end)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    
                                    Spacer()
                                    
                                    Toggle("Export", isOn: $exportSegmentsSeparately) // Placeholder for individual segment export toggle
                                        .labelsHidden()
                                    
                                    Button {
                                        segments.removeAll { $0.id == segment.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(minHeight: 100, maxHeight: 200)
                        .border(Color.gray.opacity(0.3))
                        
                        Toggle("Export each segment as a separate file", isOn: $exportSegmentsSeparately)
                            .font(.caption)
                            .help("If enabled, each segment will be saved to a separate file instead of being merged.")
                    }
                    .padding(8)
                }
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
            
            // Process Button
            HStack {
                Spacer()
                Button("Process Cut/Trim") {
                    startProcess()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputPath.isEmpty || outputPath.isEmpty || ffmpeg.isProcessing)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadVideoInfoAndProxy(path: String) {
        // 1. Get Video Info
        videoInfo = ffmpeg.getVideoDimensions(from: path)
        
        // 2. Generate Proxy Video (Async)
        let tempDir = FileManager.default.temporaryDirectory
        let proxyPath = tempDir.appendingPathComponent("proxy_\(UUID().uuidString).mp4").path
        
        ffmpeg.generateProxyVideo(inputPath: path, outputPath: proxyPath) { success, message in
            if success {
                proxyVideoPath = proxyPath
            } else {
                // Handle error, maybe just show a static image
                print("Failed to generate proxy video: \(message)")
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
            let outputURL = inputURL.deletingPathExtension().appendingPathExtension("cut_trim.\(inputURL.pathExtension)")
            outputPath = outputURL.path
        }
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        let inputURL = URL(fileURLWithPath: inputPath)
        let ext = inputURL.pathExtension
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .movie]
        panel.nameFieldStringValue = "cut_trim.\(ext)"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startProcess() {
        // Basic validation: must have input path and output path
        guard !inputPath.isEmpty && !outputPath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select both an input file and an output location."
            showAlert = true
            return
        }
        
        // Check if both trim and cut segments are being used
        let isTrimOnly = !trimStartTime.isEmpty || !trimEndTime.isEmpty
        let isMultiCut = !segments.isEmpty
        
        if isTrimOnly && isMultiCut {
            alertTitle = "Error"
            alertMessage = "Cannot perform both single Trim and Multi-Segment Cut simultaneously. Please use one or the other."
            showAlert = true
            return
        }
        
        // Check if any operation is selected
        if !isTrimOnly && !isMultiCut {
            alertTitle = "Error"
            alertMessage = "Please specify either a single Trim range or at least one Cut Segment."
            showAlert = true
            return
        }
        
        ffmpeg.processCutTrim(
            inputPath: inputPath,
            outputPath: outputPath,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            segments: segments,
            exportSegmentsSeparately: exportSegmentsSeparately
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
    @State private var analysisResult: FFmpegWrapper.VideoAnalysisResult? = nil
    @State private var useReencode = false
    @State private var selectedVideoCodec = 0
    @State private var selectedAudioCodec = 0
    @State private var videoBitrate = ""
    @State private var audioBitrate = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Merge Video/Audio Files")
                .font(.headline)
            
            // Input Files
            GroupBox("Input Files (Order Matters)") {
                VStack(alignment: .leading, spacing: 8) {
                    List {
                        ForEach(inputFiles.indices, id: \.self) { index in
                            HStack {
                                Text(URL(fileURLWithPath: inputFiles[index]).lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    removeFile(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove(perform: moveFiles)
                    }
                    .frame(minHeight: 150)
                    .border(Color.gray.opacity(0.3))
                    
                    HStack {
                        Button("Add Files...") {
                            addFiles()
                        }
                        
                        Button("Clear All") {
                            inputFiles.removeAll()
                            analysisResult = nil
                            useReencode = false
                        }
                        .disabled(inputFiles.isEmpty)
                        
                        Spacer()
                        
                        Text("\(inputFiles.count) file(s)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
            
            // Analysis and Re-encode Options
            if let analysis = analysisResult, inputFiles.count > 1 {
                GroupBox("Merge Analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Most Common Resolution:").fontWeight(.bold)
                            Text("\(analysis.mostCommonResolution.width)x\(analysis.mostCommonResolution.height)")
                        }
                        .font(.caption)
                        
                        if let warning = analysis.warningMessage {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                Text(warning)
                                    .foregroundColor(.orange)
                            }
                            .font(.caption)
                        }
                        
                        Divider()
                        
                        Toggle("Re-encode to ensure compatibility", isOn: $useReencode)
                            .onChange(of: analysis.needsReencoding) { needsReencode in
                                // Automatically suggest re-encode if needed
                                if needsReencode {
                                    useReencode = true
                                }
                            }
                        
                        if useReencode {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Video Codec:")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $selectedVideoCodec) {
                                        ForEach(0..<SupportedFormats.videoCodecs.count, id: \.self) { index in
                                            Text(SupportedFormats.videoCodecs[index].0).tag(index)
                                        }
                                    }
                                    .frame(width: 200)
                                    
                                    Text("Bitrate:")
                                        .frame(width: 60, alignment: .leading)
                                    TextField("Optional", text: $videoBitrate)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    Text("e.g., 5M, 5000k")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
                                    
                                    Text("Bitrate:")
                                        .frame(width: 60, alignment: .leading)
                                    TextField("Optional", text: $audioBitrate)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    Text("e.g., 192k, 320k")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
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
            let newPaths = panel.urls.map { $0.path }
            inputFiles.append(contentsOf: newPaths)
            
            // Re-analyze files
            analysisResult = ffmpeg.analyzeVideoFiles(paths: inputFiles)
            
            // Auto-generate output path if empty
            if outputPath.isEmpty, let firstURL = panel.urls.first {
                let outputURL = firstURL.deletingLastPathComponent().appendingPathComponent("merged.\(firstURL.pathExtension)")
                outputPath = outputURL.path
            }
        }
    }
    
    private func removeFile(at index: Int) {
        inputFiles.remove(at: index)
        analysisResult = ffmpeg.analyzeVideoFiles(paths: inputFiles)
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        inputFiles.move(fromOffsets: source, toOffset: destination)
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "mp4") ?? .movie]
        panel.nameFieldStringValue = "merged.mp4"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startMerge() {
        let videoCodec = SupportedFormats.videoCodecs[selectedVideoCodec].1
        let audioCodec = SupportedFormats.audioCodecs[selectedAudioCodec].1
        
        // Use most common resolution as target if re-encoding is on
        var targetRes: (width: Int, height: Int)? = nil
        if useReencode, let analysis = analysisResult {
            targetRes = analysis.mostCommonResolution
        }
        
        ffmpeg.mergeFiles(
            inputPaths: inputFiles,
            outputPath: outputPath,
            useReencode: useReencode,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            videoBitrate: videoBitrate,
            audioBitrate: audioBitrate,
            targetResolution: targetRes
        ) { success, message in
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
                        Text("Video Codec:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $selectedCodec) {
                            ForEach(0..<codecs.count, id: \.self) { index in
                                Text(codecs[index].0).tag(index)
                            }
                        }
                        .frame(width: 200)
                    }
                    
                    HStack {
                        Text("Pixel Format:")
                            .frame(width: 100, alignment: .leading)
                        Text("yuv420p (Recommended)")
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
            
            // Convert Button
            HStack {
                Spacer()
                Button("Convert") {
                    startConversion()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputFolder.isEmpty || outputPath.isEmpty || ffmpeg.isProcessing)
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
            // Auto-generate output path
            let inputURL = URL(fileURLWithPath: inputFolder)
            let outputURL = inputURL.deletingLastPathComponent().appendingPathComponent("\(inputURL.lastPathComponent).mp4")
            outputPath = outputURL.path
            
            // Analyze dimensions
            if let analysis = ffmpeg.analyzeImageDimensions(in: inputFolder) {
                analysisResult = analysis
                imageCount = analysis.totalImages
            } else {
                analysisResult = nil
                imageCount = 0
            }
        }
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "mp4") ?? .movie]
        panel.nameFieldStringValue = "output.mp4"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startConversion() {
        let codec = codecs[selectedCodec].1
        
        // Input validation
        guard let fr = Int(frameRate), fr > 0 else {
            alertTitle = "Error"
            alertMessage = "Invalid frame rate."
            showAlert = true
            return
        }
        
        var targetWidth: Int? = nil
        var targetHeight: Int? = nil
        
        if useCustomDimensions {
            targetWidth = Int(customWidth)
            targetHeight = Int(customHeight)
        }
        
        ffmpeg.imageSequenceToVideo(
            inputFolder: inputFolder,
            outputPath: outputPath,
            frameRate: fr,
            videoCodec: codec,
            autoCorrectDimensions: autoCorrectDimensions,
            targetWidth: targetWidth,
            targetHeight: targetHeight
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Status:")
                    .fontWeight(.bold)
                Text(ffmpeg.statusMessage)
                
                Spacer()
                
                if ffmpeg.isProcessing {
                    ProgressView(value: ffmpeg.progress)
                        .frame(width: 150)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Text("Log:")
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView {
                Text(ffmpeg.outputLog)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 100)
            .background(Color.black.opacity(0.05))
            .cornerRadius(4)
            .padding([.horizontal, .bottom])
        }
    }
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
