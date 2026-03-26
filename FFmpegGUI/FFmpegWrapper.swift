//
//  FFmpegWrapper.swift
//  FFmpegGUI
//
//  Core FFmpeg command execution wrapper
//

import Foundation
import AppKit
enum FFprobeError: Error, LocalizedError {
    case executionFailed(Error)
    case jsonDecodingFailed(Error)
    case noVideoStreamFound
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .executionFailed(let error):
            return "FFprobe execution failed: \(error.localizedDescription)"
        case .jsonDecodingFailed(let error):
            return "Failed to decode FFprobe output: \(error.localizedDescription)"
        case .noVideoStreamFound:
            return "No valid video stream was found in the file."
        case .invalidOutput:
            return "FFprobe returned invalid or unreadable data."
        }
    }
}


/// Manages FFmpeg command execution and provides methods for common operations
class FFmpegWrapper: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var outputLog = ""
    
    private var currentProcess: Process?

    private static let possibleFFmpegPaths = [
        "/opt/homebrew/bin/ffmpeg",  // Apple Silicon Homebrew
        "/usr/local/bin/ffmpeg",      // Intel Homebrew
        "/usr/bin/ffmpeg",            // System installation
        "/opt/local/bin/ffmpeg"       // MacPorts
    ]
    
    /// Path to FFmpeg binary - checks common installation locations
    lazy var ffmpegPath: String = {
        for path in Self.possibleFFmpegPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Default to hoping it's in PATH
        return "ffmpeg"
    }()
    
    /// Path to FFprobe binary
    var ffprobePath: String {
        ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
    }
    
    /// Check if FFmpeg is installed
    func isFFmpegInstalled() -> Bool {
        // Check if we can find FFmpeg in any of the common locations
        for path in Self.possibleFFmpegPaths {
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
    
    func parseFrameRate(_ string: String?) -> Double? {
        guard let string = string else { return nil }
        let parts = string.components(separatedBy: "/")
        if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
            return num / den
        }
        return Double(string)
    }
    
    private func parseFFprobeOutput(_ data: Data) throws -> VideoDimensionInfo {
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(FFprobeResult.self, from: data)
            
            // Find the first video stream
            guard let videoStream = result.streams?.first(where: { $0.width != nil && $0.height != nil }) else {
                throw FFprobeError.noVideoStreamFound
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
            throw FFprobeError.jsonDecodingFailed(error)
        }
    }
    
    func getVideoDimensions(from videoPath: String) throws -> VideoDimensionInfo {
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
            
            return try parseFFprobeOutput(data)
        } catch {
            throw FFprobeError.executionFailed(error)
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
            if let info = try? getVideoDimensions(from: path) {
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
        guard let mostCommonEntry = resolutions.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let parts = mostCommonEntry.key.components(separatedBy: "x")
        guard parts.count == 2,
              let mostCommonWidth = Int(parts[0]),
              let mostCommonHeight = Int(parts[1]) else {
            return nil
        }
        
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
                // Just correct odd dimensions
                scaleComponent = "scale='trunc(iw/2)*2':'trunc(ih/2)*2':flags=\(filter)"
            }
            
            if let sc = scaleComponent {
                videoFilters.append(sc)
            }
        }
        
        if !videoFilters.isEmpty {
            arguments += ["-vf", videoFilters.joined(separator: ",")]
        }
        
        // 2. Codec and Bitrate
        if let vc = videoCodec {
            arguments += ["-c:v", vc]
        }
        
        if let ac = audioCodec {
            arguments += ["-c:a", ac]
        }
        
        if let vb = videoBitrate, !vb.isEmpty {
            arguments += ["-b:v", vb]
        }
        
        if let ab = audioBitrate, !ab.isEmpty {
            arguments += ["-b:a", ab]
        }
        
        // 3. Output path
        arguments.append(outputPath)
        
        runFFmpeg(arguments: arguments, completion: completion)
    }
    
    // MARK: - Merge Files
    
    /// Merge multiple video files into one
    func mergeFiles(
        inputPaths: [String],
        outputPath: String,
        useReencode: Bool = false,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        videoBitrate: String? = nil,
        audioBitrate: String? = nil,
        targetResolution: (width: Int, height: Int)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard !inputPaths.isEmpty else {
            completion(false, "No input files selected.")
            return
        }
        
        if !useReencode {
            // Fast merge using concat demuxer (requires identical formats)
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let listFileURL = tempDir.appendingPathComponent("merge_list_\(UUID().uuidString).txt")
            
            let listContent = inputPaths.isEmpty ? "" : inputPaths.map { "file '\(escapePathForConcat($0))'" }.joined(separator: "\n") + "\n"
            
            do {
                try listContent.write(to: listFileURL, atomically: true, encoding: .utf8)
                
                let arguments = [
                    "-f", "concat",
                    "-safe", "0",
                    "-i", listFileURL.path,
                    "-c", "copy",
                    "-y",
                    outputPath
                ]
                
                runFFmpeg(arguments: arguments) { success, message in
                    // Clean up temp file
                    try? fileManager.removeItem(at: listFileURL)
                    completion(success, message)
                }
            } catch {
                completion(false, "Error creating temporary file: \(error.localizedDescription)")
            }
            
        } else {
            // Smart merge using filter_complex (handles mixed formats)
            var arguments = ["-y"]
            var filterComplex: [String] = []
            var mapOutputs: [String] = []
            
            // 1. Input files
            for path in inputPaths {
                arguments += ["-i", path]
            }
            
            // 2. Filter complex for scaling and concat
            for (index, path) in inputPaths.enumerated() {
                // Get info for the current file
                guard (try? getVideoDimensions(from: path)) != nil,
                      let targetRes = targetResolution else {
                    completion(false, "Could not get video dimensions for all files or target resolution is missing.")
                    return
                }
                
                let w = targetRes.width
                let h = targetRes.height
                
                // Scale and pad filter
                // [v_in]scale=w:h:force_original_aspect_ratio=decrease,pad=w:h:(w-iw)/2:(h-ih)/2,setsar=1[v_out]
                let scaleFilter = "scale=\(w):\(h):force_original_aspect_ratio=decrease"
                let padFilter = "pad=\(w):\(h):(ow-iw)/2:(oh-ih)/2"
                let setsarFilter = "setsar=1" // Set sample aspect ratio to 1:1
                
                // Video stream filter
                filterComplex.append("[\(index):v] \(scaleFilter), \(padFilter), \(setsarFilter) [v\(index)];")
                
                // Audio stream filter (no-op, just to label)
                filterComplex.append("[\(index):a] aresample=async=1 [a\(index)];")
                
                mapOutputs.append("[v\(index)][a\(index)]")
            }
            
            // 3. Concat filter
            let n = inputPaths.count
            filterComplex.append(mapOutputs.joined() + "concat=n=\(n):v=1:a=1[v_out][a_out]")
            
            arguments += ["-filter_complex", filterComplex.joined()]
            
            // 4. Output settings
            arguments += ["-map", "[v_out]", "-map", "[a_out]"]
            
            if let vc = videoCodec, vc != "copy" {
                arguments += ["-c:v", vc]
            } else {
                arguments += ["-c:v", "libx264"] // Default video codec for re-encode
            }
            
            if let ac = audioCodec, ac != "copy" {
                arguments += ["-c:a", ac]
            } else {
                arguments += ["-c:a", "aac"] // Default audio codec for re-encode
            }
            
            if let vb = videoBitrate, !vb.isEmpty {
                arguments += ["-b:v", vb]
            }
            
            if let ab = audioBitrate, !ab.isEmpty {
                arguments += ["-b:a", ab]
            }
            
            arguments += ["-pix_fmt", "yuv420p"] // Recommended pixel format
            
            // 5. Output path
            arguments += [outputPath]
            
            runFFmpeg(arguments: arguments, completion: completion)
        }
    }
    
    // MARK: - Video Preview Generation
    
    /// Generates a low-resolution proxy video for scrubbing in the UI
    func generateProxyVideo(
        inputPath: String,
        outputPath: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        let arguments = [
            "-i", inputPath,
            "-vf", "scale=320:-2", // Scale to 320px width for high performance
            "-c:v", "libx264",
            "-crf", "32", // High compression, low quality
            "-preset", "ultrafast", // Fastest possible encoding
            "-c:a", "aac",
            "-b:a", "64k",
            "-y",
            outputPath
        ]
        
        runFFmpeg(arguments: arguments, completion: completion)
    }
    
    /// Generates a single thumbnail at a specific timecode
    func generateThumbnail(
        inputPath: String,
        outputPath: String,
        timecode: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard FFmpegWrapper.isValidTimecode(timecode) else {
            completion(false, "Invalid timecode format: \(timecode)")
            return
        }

        let arguments = [
            "-ss", timecode.trimmingCharacters(in: .whitespacesAndNewlines),
            "-i", inputPath,
            "-vframes", "1",
            "-q:v", "2",
            "-y",
            outputPath
        ]
        
        runFFmpeg(arguments: arguments, completion: completion)
    }
    
    // MARK: - Multi-Segment Cut
    
    struct CutSegment: Identifiable {
        let id: UUID
        var start: String
        var end: String
    }
    
    /// Helper to convert HH:MM:SS.ms to seconds (Double)
    private func timeStringToSeconds(_ timeString: String) -> Double? {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Basic validation before parsing
        guard FFmpegWrapper.isValidTimecode(trimmed) else { return nil }

        let components = trimmed.split(separator: ":").map { String($0) }
        var seconds: Double = 0
        
        if components.count == 3, let h = Double(components[0]), let m = Double(components[1]), let s = Double(components[2]) {
            seconds = h * 3600 + m * 60 + s
        } else if components.count == 2, let m = Double(components[0]), let s = Double(components[1]) {
            seconds = m * 60 + s
        } else if components.count == 1 {
            // Handle cases with units (s, ms, us) if present, though Double() might fail on them
            let sString = String(components[0])
            if sString.hasSuffix("ms") {
                if let val = Double(sString.dropLast(2)) { return val / 1000.0 }
            } else if sString.hasSuffix("us") {
                if let val = Double(sString.dropLast(2)) { return val / 1000000.0 }
            } else if sString.hasSuffix("s") {
                if let val = Double(sString.dropLast(1)) { return val }
            } else if let s = Double(sString) {
                seconds = s
            } else {
                return nil
            }
        } else {
            return nil
        }
        return seconds
    }
    
    /// Unified function to handle both single trim and multi-segment cut
    func processCutTrim(
        inputPath: String,
        outputPath: String,
        trimStartTime: String,
        trimEndTime: String,
        segments: [CutSegment],
        exportSegmentsSeparately: Bool,
        completion: @escaping (Bool, String) -> Void
    ) {
        // 0. Validate timecode inputs
        if !trimStartTime.isEmpty && !FFmpegWrapper.isValidTimecode(trimStartTime) {
            completion(false, "Invalid start time format: \(trimStartTime)")
            return
        }
        if !trimEndTime.isEmpty && !FFmpegWrapper.isValidTimecode(trimEndTime) {
            completion(false, "Invalid end time format: \(trimEndTime)")
            return
        }

        // 1. Determine if we are doing a single trim or multi-segment cut
        let isTrimOnly = !trimStartTime.isEmpty || !trimEndTime.isEmpty
        let isMultiCut = !segments.isEmpty
        
        if isTrimOnly {
            // Single Trim: Use fast stream copy if possible
            var arguments = ["-i", inputPath]
            
            if !trimStartTime.isEmpty {
                arguments.insert(contentsOf: ["-ss", trimStartTime.trimmingCharacters(in: .whitespacesAndNewlines)], at: 0)
            }
            
            if !trimEndTime.isEmpty {
                arguments += ["-to", trimEndTime.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
            
            arguments += ["-c", "copy", "-y", outputPath]
            
            runFFmpeg(arguments: arguments, completion: completion)
            
        } else if isMultiCut {
            // Multi-Segment Cut
            let validSegments = segments.compactMap { segment -> (start: Double, end: Double)? in
                guard let start = timeStringToSeconds(segment.start),
                      let end = timeStringToSeconds(segment.end),
                      end > start else { return nil }
                return (start, end)
            }
            
            guard !validSegments.isEmpty else {
                completion(false, "No valid segments defined. Ensure end time is greater than start time.")
                return
            }
            
            if exportSegmentsSeparately {
                // Export each segment as a separate file
                processSegmentSequentially(
                    inputPath: inputPath,
                    baseOutputPath: outputPath,
                    segments: validSegments,
                    currentIndex: 0,
                    completion: completion
                )
            } else {
                // Merge segments into a single file using filter_complex
                var filterComplex = ""
                var videoOutputs = ""
                var audioOutputs = ""
                
                for (index, segment) in validSegments.enumerated() {
                    let start = segment.start
                    let end = segment.end
                    
                    // Select video and audio segments
                    filterComplex += "[0:v]trim=start=\(start):end=\(end),setpts=PTS-STARTPTS[v\(index)];"
                    filterComplex += "[0:a]atrim=start=\(start):end=\(end),asetpts=PTS-STARTPTS[a\(index)];"
                    
                    videoOutputs += "[v\(index)]"
                    audioOutputs += "[a\(index)]"
                }
                
                // Concat segments
                let n = validSegments.count
                filterComplex += "\(videoOutputs)\(audioOutputs)concat=n=\(n):v=1:a=1[v_out][a_out]"
                
                let arguments = [
                    "-i", inputPath,
                    "-filter_complex", filterComplex,
                    "-map", "[v_out]",
                    "-map", "[a_out]",
                    "-c:v", "libx264", // Re-encoding is required for complex filtering
                    "-c:a", "aac",
                    "-y",
                    outputPath
                ]
                
                runFFmpeg(arguments: arguments, completion: completion)
            }
        } else {
            completion(false, "No trim or cut operation specified.")
        }
    }
    
    // MARK: - Image Sequence to Video
    
    struct ImageDimensionInfo: Codable { // Changed to Codable for potential future use with ffprobe
        let width: Int
        let height: Int
        let count: Int
        let hasOddDimension: Bool
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
    func analyzeImageDimensions(in folderPath: String) async -> ImageAnalysisResult? {
        await Task.detached(priority: .userInitiated) {
            let imageExtensions = Set(SupportedFormats.imageFormats)
            let folderURL = URL(fileURLWithPath: folderPath)

            let fileManager = FileManager.default

            // Using enumerator for better performance on large directories
            guard let enumerator = fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else {
                return nil
            }

            var imageFiles: [URL] = []
            // Collect all URLs from the enumerator synchronously before iterating
            let enumeratedURLs: [URL] = enumerator.compactMap { $0 as? URL }

            for fileURL in enumeratedURLs {
                let ext = fileURL.pathExtension.lowercased()
                if imageExtensions.contains(ext) {
                    imageFiles.append(fileURL)
                }
            }

            if imageFiles.isEmpty { return nil }

            // Count dimensions
            var dimensionCounts: [String: (width: Int, height: Int, count: Int)] = [:]

            // The following loop is still mocking the analysis.
            // For a real implementation, you would use something like `NSImage` or FFprobe
            // to actually get image dimensions. This process is synchronous but can be
            // computationally intensive, so it's good to keep it off the main thread.
            for _ in imageFiles {
                // Mocking image analysis for simulation purposes
                let mockWidth = 1920
                let mockHeight = 1080
                let key = "\(mockWidth)x\(mockHeight)"
                if var existing = dimensionCounts[key] {
                    existing.count += 1
                    dimensionCounts[key] = existing
                } else {
                    dimensionCounts[key] = (mockWidth, mockHeight, 1)
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
        }.value // Await the result of the detached task
    }
    
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
        let fullPatternPath = (inputFolder as NSString).appendingPathComponent(imagePattern)
        
        var arguments = [
            "-framerate", String(frameRate),
            "-pattern_type", "glob",
            "-i", fullPatternPath,
            "-c:v", videoCodec,
            "-pix_fmt", pixelFormat,
            "-y",
            outputPath
        ]
        
        if autoCorrectDimensions {
            var vfArgs: [String] = []
            if let w = targetWidth, let h = targetHeight {
                vfArgs.append("scale=\(w):\(h):flags=\(scaleFilter)")
            } else {
                vfArgs.append("scale='trunc(iw/2)*2':'trunc(ih/2)*2'")
            }
            arguments.insert(contentsOf: ["-vf", vfArgs.joined(separator: ",")], at: arguments.count - 2)
        }
        
        runFFmpeg(arguments: arguments, completion: completion)
    }
    
    // MARK: - Core Process Execution
    
    /// Generic FFmpeg command runner
    func runFFmpeg(arguments: [String], completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0.0
            self.statusMessage = "Processing..."
            self.outputLog = "ffmpeg " + arguments.joined(separator: " ") + "\n\n"
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments
        
        let stdErrPipe = Pipe()
        process.standardError = stdErrPipe
        
        stdErrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.outputLog += output
                    self?.parseProgress(from: output)
                }
            }
        }
        
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isProcessing = false
                stdErrPipe.fileHandleForReading.readabilityHandler = nil
                
                if process.terminationStatus == 0 {
                    self?.progress = 1.0
                    self?.statusMessage = "Completed successfully."
                    completion(true, "Operation completed successfully.")
                } else {
                    self?.statusMessage = "Failed. Check log for details."
                    completion(false, self?.outputLog ?? "An unknown error occurred.")
                }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                self.currentProcess = process
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Failed to start FFmpeg."
                    completion(false, "Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Cancel the currently running FFmpeg process
    func cancel() {
        currentProcess?.terminate()
    }
    
    /// Parse progress from FFmpeg's stderr output
    private func parseProgress(from output: String) {
        // Example output: frame= 123 fps= 30.0 q=28.0 size=   1234kB time=00:00:04.10 bitrate=2468.0kbits/s speed=1.00x
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("frame=") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let timeIndex = components.firstIndex(where: { $0.hasPrefix("time=") }) {
                    let timeString = components[timeIndex].replacingOccurrences(of: "time=", with: "")
                    if let _ = timeStringToSeconds(timeString) {
                        // To calculate progress, we need the total duration.
                        // This requires getting it from ffprobe first and storing it.
                        // For now, we can't accurately calculate progress without total duration.
                        // This is a placeholder for future improvement.
                    }
                }
            }
        }
    }
    
    // MARK: - Segment Sequential Processing
    
    /// Recursively processes segments for separate export
    private func processSegmentSequentially(
        inputPath: String,
        baseOutputPath: String,
        segments: [(start: Double, end: Double)],
        currentIndex: Int,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard currentIndex < segments.count else {
            // Base case: all segments processed
            completion(true, "All \(segments.count) segments exported successfully.")
            return
        }

        let segment = segments[currentIndex]
        let segmentNumber = currentIndex + 1
        
        // Construct output path for this segment
        let baseOutputURL = URL(fileURLWithPath: baseOutputPath)
        let segmentFileName = baseOutputURL.deletingPathExtension().lastPathComponent + "_segment_\(segmentNumber)." + baseOutputURL.pathExtension
        let segmentOutputPath = baseOutputURL.deletingLastPathComponent().appendingPathComponent(segmentFileName).path

        // FFmpeg arguments for single segment trim (fast, copy stream)
        let arguments = [
            "-ss", String(format: "%.3f", segment.start), // Start time
            "-i", inputPath,
            "-to", String(format: "%.3f", segment.end),   // End time
            "-c", "copy",
            "-y",
            segmentOutputPath
        ]
        
        DispatchQueue.main.async {
            self.statusMessage = "Processing segment \(segmentNumber) of \(segments.count)..."
        }

        self.runFFmpeg(arguments: arguments) { [weak self] success, message in
            if success {
                // Recurse to the next segment
                self?.processSegmentSequentially(
                    inputPath: inputPath,
                    baseOutputPath: baseOutputPath,
                    segments: segments,
                    currentIndex: currentIndex + 1,
                    completion: completion
                )
            } else {
                // Failure: stop and report
                completion(false, "Failed to export segment \(segmentNumber): \(message)")
            }
        }
    }

    /// Escapes single quotes and backslashes for FFmpeg's concat demuxer file list
    private func escapePathForConcat(_ path: String) -> String {
        return path.replacingOccurrences(of: "\\", with: "\\\\")
                   .replacingOccurrences(of: "'", with: "\\'")
                   .replacingOccurrences(of: "\n", with: "")
    }

    /// Validates if a bitrate string is in a format FFmpeg understands (e.g., "500k", "2M", "1000000")
    static func isValidBitrate(_ bitrate: String) -> Bool {
        let trimmed = bitrate.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let pattern = "^[0-9]+(\\.[0-9]+)?[kKmMgG]?$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    /// Validates if a timecode string is in a format FFmpeg understands (e.g., "00:01:30", "90.5", "1:20")
    static func isValidTimecode(_ timecode: String) -> Bool {
        let trimmed = timecode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        // Regex for [[HH:]MM:]SS[.m...] OR S+[.m...][s|ms|us]
        let pattern = "^-?(([0-9]+:)?([0-5]?[0-9]:)?[0-5]?[0-9](\\.[0-9]+)?|([0-9]+)(\\.[0-9]+)?(s|ms|us)?)$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
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
        ("Bilinear (Medium)", "bicubic"),
        ("Fast Bilinear (Fastest)", "fast_bilinear")
    ]
}

