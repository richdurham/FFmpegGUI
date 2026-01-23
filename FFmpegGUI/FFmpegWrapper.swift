//
//  FFmpegWrapper.swift
//  FFmpegGUI
//
//  Core FFmpeg command execution wrapper
//

import Foundation
import AppKit

/// Manages FFmpeg command execution and provides methods for common operations
class FFmpegWrapper: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var outputLog = ""
    
    private var currentProcess: Process?
    
    /// Path to FFmpeg binary - checks common installation locations
    var ffmpegPath: String {
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",  // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",      // Intel Homebrew
            "/usr/bin/ffmpeg",            // System installation
            "/opt/local/bin/ffmpeg"       // MacPorts
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Default to hoping it's in PATH
        return "ffmpeg"
    }
    
    /// Path to FFprobe binary
    var ffprobePath: String {
        ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
    }
    
    /// Check if FFmpeg is installed
    func isFFmpegInstalled() -> Bool {
        // Check if we can find FFmpeg in any of the common locations
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",  // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",      // Intel Homebrew
            "/usr/bin/ffmpeg",            // System installation
            "/opt/local/bin/ffmpeg"       // MacPorts
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    /// Get FFmpeg version info
    func getFFmpegVersion() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                return lines.first ?? "Unknown version"
            }
        } catch {
            return "Error getting version"
        }
        
        return "Unknown version"
    }
    
    // MARK: - Video Dimension Analysis
    
    struct VideoDimensionInfo: Codable {
        let width: Int
        let height: Int
        let duration: Double?
        let frameRate: Double?
        let codec: String?
        
        var hasOddDimension: Bool {
            width % 2 != 0 || height % 2 != 0
        }
        
        var aspectRatio: Double {
            Double(width) / Double(height)
        }
        
        var resolutionString: String {
            "\(width)x\(height)"
        }
    }
    
    private struct FFprobeResult: Codable {
        let streams: [FFprobeStream]?
        let format: FFprobeFormat?
    }

    private struct FFprobeStream: Codable {
        let width: Int?
        let height: Int?
        let codec_name: String?
        let r_frame_rate: String?
        let duration: String? // Duration from stream is often more accurate for video streams
    }
    
    private struct FFprobeFormat: Codable {
        let duration: String? // Duration from format is a fallback
    }
    
    private func parseFrameRate(_ string: String?) -> Double? {
        guard let string = string else { return nil }
        let parts = string.components(separatedBy: "/")
        if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
            return num / den
        }
        return Double(string)
    }
    
    private func parseFFprobeOutput(_ data: Data) -> VideoDimensionInfo? {
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(FFprobeResult.self, from: data)
            
            // Find the first video stream
            guard let videoStream = result.streams?.first(where: { $0.width != nil && $0.height != nil }) else {
                return nil
            }
            
            let width = videoStream.width ?? 0
            let height = videoStream.height ?? 0
            let codec = videoStream.codec_name
            
            // Use stream duration if available, otherwise fallback to format duration
            let durationString = videoStream.duration ?? result.format?.duration
            let duration = durationString.flatMap { Double($0) }
            
            let frameRate = parseFrameRate(videoStream.r_frame_rate)
            
            return VideoDimensionInfo(
                width: width,
                height: height,
                duration: duration,
                frameRate: frameRate,
                codec: codec
            )
            
        } catch {
            print("Error decoding FFprobe JSON: \(error)")
            return nil
        }
    }
    
    func getVideoDimensions(from videoPath: String) -> VideoDimensionInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_streams",
            "-show_format",
            videoPath
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            return parseFFprobeOutput(data)
        } catch {
            print("FFprobe execution error: \(error)")
            return nil
        }
    }
    
    // MARK: - Video Analysis for Merging
    
    struct VideoAnalysisResult {
        let files: [String: VideoDimensionInfo]
        let mostCommonResolution: (width: Int, height: Int)
        let hasMixedResolutions: Bool
        let hasMixedCodecs: Bool
        let hasMixedFrameRates: Bool
        let needsReencoding: Bool
        
        var warningMessage: String? {
            var warnings: [String] = []
            
            if hasMixedResolutions {
                warnings.append("Mixed resolutions detected")
            }
            if hasMixedCodecs {
                warnings.append("Mixed codecs detected")
            }
            if hasMixedFrameRates {
                warnings.append("Mixed frame rates detected")
            }
            
            return warnings.isEmpty ? nil : warnings.joined(separator: ". ")
        }
    }
    
    func analyzeVideoFiles(paths: [String]) -> VideoAnalysisResult? {
        var fileInfos: [String: VideoDimensionInfo] = [:]
        var resolutions: [String: Int] = [:]
        var codecs: Set<String> = []
        var frameRates: Set<Double> = []
        
        for path in paths {
            if let info = getVideoDimensions(from: path) {
                fileInfos[path] = info
                
                let resKey = info.resolutionString
                resolutions[resKey, default: 0] += 1
                
                if let codec = info.codec {
                    codecs.insert(codec)
                }
                
                if let fr = info.frameRate {
                    frameRates.insert(fr)
                }
            }
        }
        
        guard !fileInfos.isEmpty else { return nil }
        
        // Find most common resolution
        let mostCommonEntry = resolutions.max { $0.value < $1.value }!
        let parts = mostCommonEntry.key.components(separatedBy: "x")
        let mostCommonWidth = Int(parts[0]) ?? 0
        let mostCommonHeight = Int(parts[1]) ?? 0
        
        let hasMixedResolutions = resolutions.count > 1
        let hasMixedCodecs = codecs.count > 1
        let hasMixedFrameRates = frameRates.count > 1
        
        // Needs re-encoding if resolutions, codecs, or frame rates are mixed
        let needsReencoding = hasMixedResolutions || hasMixedCodecs || hasMixedFrameRates
        
        return VideoAnalysisResult(
            files: fileInfos,
            mostCommonResolution: (width: mostCommonWidth, height: mostCommonHeight),
            hasMixedResolutions: hasMixedResolutions,
            hasMixedCodecs: hasMixedCodecs,
            hasMixedFrameRates: hasMixedFrameRates,
            needsReencoding: needsReencoding
        )
    }
    
    // MARK: - Convert Video/Audio Format
    
    /// Convert a media file to a different format
    func convertFormat(
        inputPath: String,
        outputPath: String,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        videoBitrate: String? = nil,
        audioBitrate: String? = nil,
        scaleWidth: Int? = nil,
        scaleHeight: Int? = nil,
        scaleFilter: String? = nil,
        autoCorrectOdd: Bool = false,
        completion: @escaping (Bool, String) -> Void
    ) {
        var arguments = ["-i", inputPath, "-y"]  // -y to overwrite
        
        var videoFilters: [String] = []
        
        // 1. Scaling Logic
        if scaleWidth != nil || scaleHeight != nil || autoCorrectOdd {
            var scaleComponent: String?
            let filter = scaleFilter ?? SupportedFormats.scaleFilters[0].1 // Default to Lanczos
            
            if let w = scaleWidth, let h = scaleHeight {
                // Both dimensions specified - exact scale
                scaleComponent = "scale=\(w):\(h):flags=\(filter)"
            } else if let w = scaleWidth {
                // Width specified, height auto with even constraint
                scaleComponent = "scale=\(w):-2:flags=\(filter)"
            } else if let h = scaleHeight {
                // Height specified, width auto with even constraint
                scaleComponent = "scale=-2:\(h):flags=\(filter)"
            } else if autoCorrectOdd {
                // Auto-correct: ensure even dimensions while preserving aspect ratio
                scaleComponent = "scale='if(mod(iw,2),iw+1,iw)':'if(mod(ih,2),ih+1,ih)':flags=\(filter)"
            }
            
            if let sc = scaleComponent {
                videoFilters.append(sc)
            }
        }
        
        // Add video filter argument if any filters were applied
        if !videoFilters.isEmpty {
            arguments += ["-vf", videoFilters.joined(separator: ",")]
        }
        
        // 2. Codec and Bitrate Logic
        if let vc = videoCodec, !vc.isEmpty {
            arguments += ["-c:v", vc]
        }
        
        if let ac = audioCodec, !ac.isEmpty {
            arguments += ["-c:a", ac]
        }
        
        if let vb = videoBitrate, !vb.isEmpty {
            arguments += ["-b:v", vb]
        }
        
        if let ab = audioBitrate, !ab.isEmpty {
            arguments += ["-b:a", ab]
        }
        
        arguments.append(outputPath)
        
        runFFmpeg(arguments: arguments, completion: completion)
    }
    
    // MARK: - Trim Video
    
    /// Trim a video file between start and end times
    func trimVideo(
        inputPath: String,
        outputPath: String,
        startTime: String,
        endTime: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        var arguments = ["-i", inputPath]
        
        if !startTime.isEmpty {
            arguments += ["-ss", startTime]
        }
        
        if !endTime.isEmpty {
            arguments += ["-to", endTime]
        }
        
        // Use copy codec for faster trimming without re-encoding
        arguments += ["-c", "copy", "-y", outputPath]
        
        runFFmpeg(arguments: arguments, completion: completion)
    }
    
    // MARK: - Merge Files
    
    /// Merge multiple video/audio files into one
    func mergeFiles(
        inputPaths: [String],
        outputPath: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        // Create a temporary file list for FFmpeg concat
        let tempDir = FileManager.default.temporaryDirectory
        let listFile = tempDir.appendingPathComponent("ffmpeg_concat_list.txt")
        
        var listContent = ""
        for path in inputPaths {
            // Escape single quotes in file paths
            let escapedPath = path.replacingOccurrences(of: "'", with: "'\\''")
            listContent += "file '\(escapedPath)'\n"
        }
        
        do {
            try listContent.write(to: listFile, atomically: true, encoding: .utf8)
        } catch {
            completion(false, "Failed to create file list: \(error.localizedDescription)")
            return
        }
        
        let arguments = [
            "-f", "concat",
            "-safe", "0",
            "-i", listFile.path,
            "-c", "copy",
            "-y",
            outputPath
        ]
        
        runFFmpeg(arguments: arguments) { success, message in
            // Clean up temp file
            try? FileManager.default.removeItem(at: listFile)
            completion(success, message)
        }
    }
    
    // MARK: - Image Dimension Analysis
    
    struct ImageDimensionInfo {
        let width: Int
        let height: Int
        let count: Int
        let hasOddDimension: Bool
        
        var isEven: Bool { !hasOddDimension }
        var aspectRatio: Double { Double(width) / Double(height) }
    }
    
    struct ImageAnalysisResult {
        let mostCommonDimension: ImageDimensionInfo
        let totalImages: Int
        let uniqueDimensions: [ImageDimensionInfo]
        let hasMixedSizes: Bool
        let needsCorrection: Bool
        
        var warningMessage: String? {
            var warnings: [String] = []
            
            if mostCommonDimension.hasOddDimension {
                warnings.append("Most common size (\(mostCommonDimension.width)x\(mostCommonDimension.height)) has odd dimensions")
            }
            
            if hasMixedSizes {
                warnings.append("\(uniqueDimensions.count) different image sizes detected")
            }
            
            return warnings.isEmpty ? nil : warnings.joined(separator: ". ")
        }
    }
    
    /// Analyze image dimensions in a folder
    func analyzeImageDimensions(in folderPath: String) -> ImageAnalysisResult? {
        let fileManager = FileManager.default
        let imageExtensions = SupportedFormats.imageFormats
        
        guard let files = try? fileManager.contentsOfDirectory(atPath: folderPath) else {
            return nil
        }
        
        let imageFiles = files.filter { file in
            let ext = (file as NSString).pathExtension.lowercased()
            return imageExtensions.contains(ext)
        }
        
        if imageFiles.isEmpty { return nil }
        
        // Count dimensions
        var dimensionCounts: [String: (width: Int, height: Int, count: Int)] = [:]
        
        for file in imageFiles {
            let fullPath = (folderPath as NSString).appendingPathComponent(file)
            
            // NOTE: This part uses AppKit/CoreGraphics which is only available on macOS.
            // In a real-world Swift/macOS app, this is the correct way.
            // For the purpose of this simulation, we assume this part works.
            if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: fullPath) as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
               let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                
                let key = "\(width)x\(height)"
                if var existing = dimensionCounts[key] {
                    existing.count += 1
                    dimensionCounts[key] = existing
                } else {
                    dimensionCounts[key] = (width, height, 1)
                }
            }
        }
        
        // Find most common dimension
        guard let mostCommon = dimensionCounts.values.max(by: { $0.count < $1.count }) else {
            return nil
        }
        
        let hasOdd = mostCommon.width % 2 != 0 || mostCommon.height % 2 != 0
        let mostCommonInfo = ImageDimensionInfo(
            width: mostCommon.width,
            height: mostCommon.height,
            count: mostCommon.count,
            hasOddDimension: hasOdd
        )
        
        let allDimensions = dimensionCounts.values.map { dim in
            ImageDimensionInfo(
                width: dim.width,
                height: dim.height,
                count: dim.count,
                hasOddDimension: dim.width % 2 != 0 || dim.height % 2 != 0
            )
        }.sorted { $0.count > $1.count }
        
        let hasMixed = dimensionCounts.count > 1
        let needsCorrection = hasOdd || hasMixed
        
        return ImageAnalysisResult(
            mostCommonDimension: mostCommonInfo,
            totalImages: imageFiles.count,
            uniqueDimensions: allDimensions,
            hasMixedSizes: hasMixed,
            needsCorrection: needsCorrection
        )
    }
    
    // MARK: - Image Sequence to Video
    
    /// Convert a folder of images to a video file
    func imageSequenceToVideo(
        inputFolder: String,
        outputPath: String,
        frameRate: Int = 24,
        imagePattern: String = "*.png",
        videoCodec: String = "libx264",
        pixelFormat: String = "yuv420p",
        autoCorrectDimensions: Bool = true,
        targetWidth: Int? = nil,
        targetHeight: Int? = nil,
        scaleFilter: String = "lanczos",
        completion: @escaping (Bool, String) -> Void
    ) {
        let fileManager = FileManager.default
        let imageExtensions = SupportedFormats.imageFormats
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let files = try fileManager.contentsOfDirectory(atPath: inputFolder)
                
                var imageFiles = files.filter { file in
                    let ext = (file as NSString).pathExtension.lowercased()
                    return imageExtensions.contains(ext)
                }
                
                if imageFiles.isEmpty {
                    completion(false, "No image files found in the selected folder")
                    return
                }
                
                // Sort files naturally (handles both "img1, img2, img10" and "img001, img002" correctly)
                imageFiles.sort { file1, file2 in
                    return file1.compare(file2, options: [.numeric, .caseInsensitive]) == .orderedAscending
                }
                
                // Use concat demuxer with explicit file list for reliable frame ordering
                let tempDir = fileManager.temporaryDirectory
                let listFile = tempDir.appendingPathComponent("ffmpeg_image_list_\(UUID().uuidString).txt")
                
                // Calculate frame duration for concat demuxer
                let frameDuration = 1.0 / Double(frameRate)
                
                // Build the concat file list with duration for each frame
                var listContent = ""
                for file in imageFiles {
                    let fullPath = (inputFolder as NSString).appendingPathComponent(file)
                    // Escape special characters in path
                    let escapedPath = fullPath.replacingOccurrences(of: "'", with: "'\\''")
                    listContent += "file '\(escapedPath)'\n"
                    listContent += "duration \(frameDuration)\n"
                }
                
                // Add the last file again without duration (FFmpeg concat demuxer quirk)
                if let lastFile = imageFiles.last {
                    let fullPath = (inputFolder as NSString).appendingPathComponent(lastFile)
                    let escapedPath = fullPath.replacingOccurrences(of: "'", with: "'\\''")
                    listContent += "file '\(escapedPath)'\n"
                }
                
                try listContent.write(to: listFile, atomically: true, encoding: .utf8)
                
                var arguments = [
                    "-f", "concat",
                    "-safe", "0",
                    "-i", listFile.path
                ]
                
                // Add video filter for dimension correction if needed
                if autoCorrectDimensions || targetWidth != nil || targetHeight != nil {
                    var filterComponents: [String] = []
                    
                    if let w = targetWidth, let h = targetHeight {
                        // Both dimensions specified - scale to exact size with even dimensions
                        let evenW = w % 2 == 0 ? w : w + 1
                        let evenH = h % 2 == 0 ? h : h + 1
                        filterComponents.append("scale=\(evenW):\(evenH):flags=\(scaleFilter)")
                    } else if let w = targetWidth {
                        // Width specified, height auto with even constraint
                        filterComponents.append("scale=\(w):-2:flags=\(scaleFilter)")
                    } else if let h = targetHeight {
                        // Height specified, width auto with even constraint
                        filterComponents.append("scale=-2:\(h):flags=\(scaleFilter)")
                    } else if autoCorrectDimensions {
                        // Auto-correct: ensure even dimensions while preserving aspect ratio
                        filterComponents.append("scale='if(mod(iw,2),iw+1,iw)':'if(mod(ih,2),ih+1,ih)':flags=\(scaleFilter)")
                    }
                    
                    if !filterComponents.isEmpty {
                        arguments += ["-vf", filterComponents.joined(separator: ",")]
                    }
                }
                
                arguments += [
                    "-c:v", videoCodec,
                    "-pix_fmt", pixelFormat,
                    "-vsync", "vfr",
                    "-y",
                    outputPath
                ]
                
                runFFmpeg(arguments: arguments) { success, message in
                    // Clean up temp file
                    try? fileManager.removeItem(at: listFile)
                    completion(success, message)
                }
                
            } catch {
                completion(false, "Error reading folder: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Core FFmpeg Execution
    
    /// Run FFmpeg with the given arguments
    private func runFFmpeg(arguments: [String], completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0.0
            self.statusMessage = "Processing..."
            self.outputLog = "Running: ffmpeg \(arguments.joined(separator: " "))\n\n"
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.ffmpegPath)
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            self.currentProcess = process
            
            // Read stderr for progress (FFmpeg outputs to stderr)
            errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    DispatchQueue.main.async {
                        self?.outputLog += output
                        self?.parseProgress(from: output)
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // Stop reading
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                let success = process.terminationStatus == 0
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.currentProcess = nil
                    
                    if success {
                        self.progress = 1.0
                        self.statusMessage = "Completed successfully!"
                        completion(true, "Operation completed successfully")
                    } else {
                        self.statusMessage = "Failed with exit code \(process.terminationStatus)"
                        completion(false, "FFmpeg exited with code \(process.terminationStatus)")
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.currentProcess = nil
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    /// Parse FFmpeg output to extract progress information
    private func parseProgress(from output: String) {
        // FFmpeg outputs time progress like "time=00:01:23.45"
        if let range = output.range(of: "time=\\d{2}:\\d{2}:\\d{2}", options: .regularExpression) {
            let timeStr = String(output[range]).replacingOccurrences(of: "time=", with: "")
            statusMessage = "Processing: \(timeStr)"
        }
    }
    
    /// Cancel the current operation
    func cancel() {
        currentProcess?.terminate()
        DispatchQueue.main.async {
            self.isProcessing = false
            self.statusMessage = "Cancelled"
            self.currentProcess = nil
        }
    }
}

// MARK: - Supported Formats

struct SupportedFormats {
    static let videoFormats = ["mp4", "mov", "avi", "mkv", "webm", "flv", "wmv", "m4v"]
    static let audioFormats = ["mp3", "aac", "wav", "flac", "ogg", "m4a", "wma"]
    static let imageFormats = ["png", "jpg", "jpeg", "bmp", "tiff", "tif"]
    
    static let videoCodecs = [
        ("H.264 (libx264)", "libx264"),
        ("H.265/HEVC (libx265)", "libx265"),
        ("VP9", "libvpx-vp9"),
        ("ProRes", "prores_ks"),
        ("Copy (no re-encode)", "copy")
    ]
    
    static let audioCodecs = [
        ("AAC", "aac"),
        ("MP3 (libmp3lame)", "libmp3lame"),
        ("Opus", "libopus"),
        ("FLAC", "flac"),
        ("Copy (no re-encode)", "copy")
    ]
    
    static let scaleFilters = [
        ("Lanczos (Highest)", "lanczos"),
        ("Bicubic (Good)", "bicubic"),
        ("Bilinear (Medium)", "bilinear"),
        ("Fast Bilinear (Fastest)", "fast_bilinear")
    ]
}
