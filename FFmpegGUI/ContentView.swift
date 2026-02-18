//
//  ContentView.swift
//  FFmpegGUI
//
//  Main UI with tabs for all FFmpeg operations
//

import SwiftUI
import UniformTypeIdentifiers
import AVKit

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
                                }
                                
                                HStack {
                                    Button("1080p") { setScalePreset(width: 1920, height: 1080) }
                                    Button("720p") { setScalePreset(width: 1280, height: 720) }
                                    Button("480p") { setScalePreset(width: 854, height: 480) }
                                    Button("4K") { setScalePreset(width: 3840, height: 2160) }
                                }
                            }
                            .padding(.leading, 20)
                        }
                    }
                    .padding(8)
                }
            }
            
            // Video Codec
            GroupBox("Video Codec") {
                HStack {
                    Picker("Codec:", selection: $selectedVideoCodec) {
                        ForEach(0..<SupportedFormats.videoCodecs.count, id: \.self) { index in
                            Text(SupportedFormats.videoCodecs[index].0).tag(index)
                        }
                    }
                    .frame(width: 200)
                    
                    TextField("Bitrate (e.g., 2M, 500k)", text: $videoBitrate)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
                .padding(8)
            }
            
            // Audio Codec
            GroupBox("Audio Codec") {
                HStack {
                    Picker("Codec:", selection: $selectedAudioCodec) {
                        ForEach(0..<SupportedFormats.audioCodecs.count, id: \.self) { index in
                            Text(SupportedFormats.audioCodecs[index].0).tag(index)
                        }
                    }
                    .frame(width: 200)
                    
                    TextField("Bitrate (e.g., 128k, 256k)", text: $audioBitrate)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
                .padding(8)
            }
            
            // Output Format
            GroupBox("Output Format") {
                Picker("Format:", selection: $selectedOutputFormat) {
                    ForEach(outputFormats, id: \.self) { format in
                        Text(format.uppercased()).tag(format)
                    }
                }
                .frame(width: 150)
                .padding(8)
            }
            
            // Output File
            GroupBox("Output File") {
                HStack {
                    TextField("Select output location...", text: $inputPath)
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
                Button("Convert") {
                    startProcess()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputPath.isEmpty || outputPath.isEmpty || ffmpeg.isProcessing)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func setScalePreset(width: Int, height: Int) {
        scaleWidth = String(width)
        scaleHeight = String(height)
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
            
            // Get video info for scaling
            videoInfo = ffmpeg.getVideoDimensions(from: inputPath)
        }
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        let inputURL = URL(fileURLWithPath: inputPath)
        let ext = selectedOutputFormat
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .movie]
        panel.nameFieldStringValue = inputURL.deletingPathExtension().lastPathComponent + "." + ext
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startProcess() {
        guard !inputPath.isEmpty && !outputPath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select both an input file and an output location."
            showAlert = true
            return
        }
        
        ffmpeg.convertFormat(
            inputPath: inputPath,
            outputPath: outputPath,
            videoCodec: SupportedFormats.videoCodecs[selectedVideoCodec].1,
            audioCodec: SupportedFormats.audioCodecs[selectedAudioCodec].1,
            videoBitrate: videoBitrate.isEmpty ? nil : videoBitrate,
            audioBitrate: audioBitrate.isEmpty ? nil : audioBitrate,
            scaleWidth: resizeVideo ? Int(scaleWidth) : nil,
            scaleHeight: resizeVideo ? Int(scaleHeight) : nil,
            scaleFilter: SupportedFormats.scaleFilters[selectedScaleFilter].1,
            autoCorrectOdd: true // Always auto-correct odd dimensions for safety
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
    @State private var player: AVPlayer? = nil
    @State private var currentTime: Double = 0.0
    @State private var duration: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var playerObserver: Any? = nil
    
    @State private var trimStartTime = ""
    @State private var trimEndTime = ""
    @State private var segments: [FFmpegWrapper.CutSegment] = []
    @State private var exportSegmentsSeparately = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cut/Trim Video")
                .font(.headline)
            
            // Input File
            GroupBox("Input File") {
                HStack {
                    TextField("Select input video...", text: $inputPath)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: inputPath) { newPath in
                            if !newPath.isEmpty {
                                loadVideoInfoAndProxy(path: newPath)
                            } else {
                                videoInfo = nil
                                proxyVideoPath = nil
                                player = nil
                                currentTime = 0.0
                                duration = 0.0
                                cleanupPlayer()
                            }
                        }
                    
                    Button("Browse...") {
                        selectInputFile()
                    }
                }
                .padding(8)
            }
            
            // Video Preview and Controls
            if let info = videoInfo, let proxyPath = proxyVideoPath {
                VStack {
                    VideoPlayer(player: player)
                        .frame(maxWidth: 640, maxHeight: 360)
                        .border(Color.gray)
                        .onAppear { setupPlayer(proxyPath: proxyPath) }
                        .onDisappear { cleanupPlayer() }
                    
                    // Playback Controls
                    HStack {
                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        
                        Slider(value: $currentTime, in: 0...max(0.1, duration)) {
                            Text("Time")
                        } onEditingChanged: { editing in
                            if !editing {
                                player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                            }
                        }
                        
                        Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                            .font(.caption)
                            .frame(width: 120, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    
                    // Marking Buttons
                    HStack {
                        Button("Set Start") {
                            trimStartTime = formatTime(currentTime)
                        }
                        Button("Set End") {
                            trimEndTime = formatTime(currentTime)
                        }
                        Button("Add Segment") {
                            segments.append(FFmpegWrapper.CutSegment(id: UUID(), start: formatTime(currentTime), end: ""))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            
            // Trim and Cut Sections
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
        videoInfo = ffmpeg.getVideoDimensions(from: path)
        
        let tempDir = FileManager.default.temporaryDirectory
        let proxyPath = tempDir.appendingPathComponent("proxy_\(UUID().uuidString).mp4").path
        
        ffmpeg.generateProxyVideo(inputPath: path, outputPath: proxyPath) { success, message in
            if success {
                DispatchQueue.main.async {
                    self.proxyVideoPath = proxyPath
                    self.setupPlayer(proxyPath: proxyPath)
                }
            } else {
                print("Failed to generate proxy video: \(message)")
            }
        }
    }
    
    private func setupPlayer(proxyPath: String) {
        cleanupPlayer()
        
        let url = URL(fileURLWithPath: proxyPath)
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        playerObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // Get duration
        let asset = AVURLAsset(url: url)
        Task {
            if let duration = try? await asset.load(.duration) {
                DispatchQueue.main.async {
                    self.duration = duration.seconds
                }
            }
        }
    }
    
    private func cleanupPlayer() {
        if let observer = playerObserver {
            player?.removeTimeObserver(observer)
            playerObserver = nil
        }
        player?.pause()
        player = nil
        if let proxyPath = proxyVideoPath {
            try? FileManager.default.removeItem(atPath: proxyPath)
            proxyVideoPath = nil
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
    }
    
    private func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            inputPath = url.path
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
        guard !inputPath.isEmpty && !outputPath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select both an input file and an output location."
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
    
    @State private var inputPaths: [String] = []
    @State private var outputPath = ""
    @State private var analysisResult: FFmpegWrapper.VideoAnalysisResult? = nil
    @State private var useReencode = false
    @State private var selectedVideoCodec = 0
    @State private var selectedAudioCodec = 0
    @State private var videoBitrate = ""
    @State private var audioBitrate = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Merge Videos")
                .font(.headline)
            
            GroupBox("Input Files") {
                VStack(alignment: .leading, spacing: 8) {
                    List {
                        ForEach(inputPaths, id: \.self) { path in
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                        }
                        .onDelete(perform: removeFiles)
                    }
                    .frame(minHeight: 100, maxHeight: 200)
                    .border(Color.gray.opacity(0.3))
                    
                    HStack {
                        Button("Add Files...") {
                            selectInputFiles()
                        }
                        Button("Clear All") {
                            inputPaths.removeAll()
                            analysisResult = nil
                        }
                        Spacer()
                    }
                }
                .padding(8)
            }
            
            if let result = analysisResult {
                GroupBox("Merge Analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Most Common Resolution:").fontWeight(.bold)
                            Text("\(result.mostCommonResolution.width)x\(result.mostCommonResolution.height)")
                        }
                        
                        if let warning = result.warningMessage {
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                Text(warning).foregroundColor(.orange)
                            }
                        }
                        
                        Toggle("Re-encode for compatibility", isOn: $useReencode)
                            .disabled(!result.needsReencoding)
                        
                        if useReencode {
                            HStack {
                                Picker("Video Codec:", selection: $selectedVideoCodec) {
                                    ForEach(0..<SupportedFormats.videoCodecs.count, id: \.self) { index in
                                        Text(SupportedFormats.videoCodecs[index].0).tag(index)
                                    }
                                }
                                .frame(width: 200)
                                
                                TextField("Bitrate (e.g., 2M)", text: $videoBitrate)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                            }
                            
                            HStack {
                                Picker("Audio Codec:", selection: $selectedAudioCodec) {
                                    ForEach(0..<SupportedFormats.audioCodecs.count, id: \.self) { index in
                                        Text(SupportedFormats.audioCodecs[index].0).tag(index)
                                    }
                                }
                                .frame(width: 200)
                                
                                TextField("Bitrate (e.g., 128k)", text: $audioBitrate)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                            }
                        }
                    }
                    .padding(8)
                }
            }
            
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
            
            HStack {
                Spacer()
                Button("Merge Videos") {
                    startProcess()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputPaths.isEmpty || outputPath.isEmpty || ffmpeg.isProcessing)
            }
        }
        .onChange(of: inputPaths) { newPaths in
            if !newPaths.isEmpty {
                analysisResult = ffmpeg.analyzeVideoFiles(paths: newPaths)
                useReencode = analysisResult?.needsReencoding ?? false
            } else {
                analysisResult = nil
            }
        }
    }
    
    private func selectInputFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            inputPaths.append(contentsOf: panel.urls.map { $0.path })
            if outputPath.isEmpty, let firstPath = inputPaths.first {
                let inputURL = URL(fileURLWithPath: firstPath)
                let outputURL = inputURL.deletingPathExtension().appendingPathExtension("merged.\(inputURL.pathExtension)")
                outputPath = outputURL.path
            }
        }
    }
    
    private func removeFiles(at offsets: IndexSet) {
        inputPaths.remove(atOffsets: offsets)
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.movie]
        if !inputPaths.isEmpty, let firstPath = inputPaths.first {
            let inputURL = URL(fileURLWithPath: firstPath)
            panel.nameFieldStringValue = inputURL.deletingPathExtension().lastPathComponent + ".merged.\(inputURL.pathExtension)"
        }
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startProcess() {
        guard !inputPaths.isEmpty && !outputPath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select input files and an output location."
            showAlert = true
            return
        }
        
        ffmpeg.mergeFiles(
            inputPaths: inputPaths,
            outputPath: outputPath,
            useReencode: useReencode,
            videoCodec: useReencode ? SupportedFormats.videoCodecs[selectedVideoCodec].1 : nil,
            audioCodec: useReencode ? SupportedFormats.audioCodecs[selectedAudioCodec].1 : nil,
            videoBitrate: useReencode && !videoBitrate.isEmpty ? videoBitrate : nil,
            audioBitrate: useReencode && !audioBitrate.isEmpty ? audioBitrate : nil,
            targetResolution: analysisResult?.mostCommonResolution
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
    
    @State private var inputFolderPath = ""
    @State private var outputPath = ""
    @State private var frameRate = "24"
    @State private var imagePattern = "*.png"
    @State private var selectedVideoCodec = 0
    @State private var selectedPixelFormat = 0
    
    @State private var analysisResult: FFmpegWrapper.ImageAnalysisResult? = nil
    @State private var autoCorrectDimensions = true
    @State private var targetWidth = ""
    @State private var targetHeight = ""
    @State private var selectedScaleFilter = 0
    
    let pixelFormats = [
        ("yuv420p (Most Compatible)", "yuv420p"),
        ("yuva420p (Alpha Channel)", "yuva420p"),
        ("rgb24", "rgb24")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Image Sequence to Video")
                .font(.headline)
            
            GroupBox("Input Folder") {
                HStack {
                    TextField("Select folder containing image sequence...", text: $inputFolderPath)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: inputFolderPath) { newPath in
                            Task {
                                if !newPath.isEmpty {
                                    let result = await ffmpeg.analyzeImageDimensions(in: newPath)
                                    await MainActor.run {
                                        self.analysisResult = result
                                        if let result = result {
                                            self.autoCorrectDimensions = result.needsCorrection
                                            self.targetWidth = String(result.mostCommonDimension.width)
                                            self.targetHeight = String(result.mostCommonDimension.height)
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        self.analysisResult = nil
                                    }
                                }
                            }
                        }
                    
                    Button("Browse...") {
                        selectInputFolder()
                    }
                }
                .padding(8)
            }
            
            if let result = analysisResult {
                GroupBox("Image Sequence Analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Total Images:").fontWeight(.bold)
                            Text("\(result.totalImages)")
                        }
                        HStack {
                            Text("Most Common Dimension:").fontWeight(.bold)
                            Text("\(result.mostCommonDimension.width)x\(result.mostCommonDimension.height)")
                        }
                        
                        if let warning = result.warningMessage {
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                Text(warning).foregroundColor(.orange)
                            }
                        }
                        
                        Toggle("Auto-correct dimensions", isOn: $autoCorrectDimensions)
                            .disabled(!result.needsCorrection)
                        
                        if autoCorrectDimensions {
                            HStack {
                                Text("Target Width:")
                                TextField("\(result.mostCommonDimension.width)", text: $targetWidth)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("Target Height:")
                                TextField("\(result.mostCommonDimension.height)", text: $targetHeight)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                
                                Text("Scale Quality:")
                                Picker("", selection: $selectedScaleFilter) {
                                    ForEach(0..<SupportedFormats.scaleFilters.count, id: \.self) { index in
                                        Text(SupportedFormats.scaleFilters[index].0).tag(index)
                                    }
                                }
                                .frame(width: 150)
                            }
                        }
                    }
                    .padding(8)
                }
            }
            
            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Frame Rate:")
                            .frame(width: 100, alignment: .leading)
                        TextField("24", text: $frameRate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("fps")
                    }
                    
                    HStack {
                        Text("Image Pattern:")
                            .frame(width: 100, alignment: .leading)
                        TextField("*.png", text: $imagePattern)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                    }
                    
                    HStack {
                        Picker("Video Codec:", selection: $selectedVideoCodec) {
                            ForEach(0..<SupportedFormats.videoCodecs.count, id: \.self) { index in
                                Text(SupportedFormats.videoCodecs[index].0).tag(index)
                            }
                        }
                        .frame(width: 200)
                        
                        Picker("Pixel Format:", selection: $selectedPixelFormat) {
                            ForEach(0..<pixelFormats.count, id: \.self) { index in
                                Text(pixelFormats[index].0).tag(index)
                            }
                        }
                        .frame(width: 200)
                    }
                }
                .padding(8)
            }
            
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
            
            HStack {
                Spacer()
                Button("Create Video") {
                    startProcess()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputFolderPath.isEmpty || outputPath.isEmpty || ffmpeg.isProcessing)
            }
        }
    }
    
    private func selectInputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            inputFolderPath = url.path
            let outputURL = url.appendingPathComponent("output.mp4")
            outputPath = outputURL.path
        }
    }
    
    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.movie]
        if !inputFolderPath.isEmpty {
            let inputURL = URL(fileURLWithPath: inputFolderPath)
            panel.nameFieldStringValue = inputURL.lastPathComponent + ".mp4"
        }
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startProcess() {
        guard !inputFolderPath.isEmpty && !outputPath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select an input folder and an output location."
            showAlert = true
            return
        }
        guard let fr = Int(frameRate), fr > 0 else {
            alertTitle = "Error"
            alertMessage = "Frame rate must be a positive integer."
            showAlert = true
            return
        }
        ffmpeg.imageSequenceToVideo(
            inputFolder: inputFolderPath,
            outputPath: outputPath,
            frameRate: fr,
            imagePattern: imagePattern,
            videoCodec: SupportedFormats.videoCodecs[selectedVideoCodec].1,
            pixelFormat: pixelFormats[selectedPixelFormat].1,
            autoCorrectDimensions: autoCorrectDimensions,
            targetWidth: Int(targetWidth),
            targetHeight: Int(targetHeight),
            scaleFilter: SupportedFormats.scaleFilters[selectedScaleFilter].1
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
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: ffmpeg.progress)
                .progressViewStyle(.linear)
                .opacity(ffmpeg.isProcessing ? 1 : 0)
            
            Text(ffmpeg.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(ffmpeg.outputLog)
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
            }
            .frame(height: 100)
        }
        .padding()
    }
}
