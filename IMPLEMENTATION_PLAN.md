# Implementation Plan: Video Scaling & Multi-Resolution Merge

## Overview
Add video dimension detection and scaling capabilities to the Convert and Merge tabs, similar to the image sequence feature.

---

## Phase 1: Video Dimension Detection (Completed)

### New Function: `getVideoDimensions()`
**Location:** `FFmpegWrapper.swift`

**Purpose:** Extract video metadata using FFprobe (part of FFmpeg)

**Implementation:**
```swift
struct VideoDimensionInfo {
    let width: Int
    let height: Int
    let hasOddDimension: Bool
    let duration: Double?
    let frameRate: Double?
    let codec: String?
}

func getVideoDimensions(from videoPath: String) -> VideoDimensionInfo?
```

**Method:**
- Use `ffprobe` command with JSON output
- Parse: width, height, duration, frame rate, codec
- Check for odd dimensions
- Return structured info

**FFprobe Command:**
```bash
ffprobe -v quiet -print_format json -show_streams "input.mp4"
```

---

## Phase 2: Convert Tab Enhancements (Completed)

### UI Changes
Add new GroupBox: **"Resize/Scale Options"**

**Controls:**
1. Toggle: "Resize video" (default: OFF)
2. When enabled:
   - Width field (with presets)
   - Height field (with presets)
   - Aspect ratio lock toggle
   - Scale quality dropdown: Lanczos, Bicubic, Bilinear, Fast Bilinear
   - Preset buttons: 1920×1080, 1280×720, 854×480, 3840×2160

**Display:**
- Show detected input dimensions
- Show warning if odd dimensions detected
- Preview output dimensions

### Backend Changes
**Update:** `convertFormat()` function

**New Parameters:**
- `scaleWidth: Int?`
- `scaleHeight: Int?`
- `scaleFilter: String`
- `autoCorrectOdd: Bool`

**FFmpeg Filter Logic:**
```
-vf "scale=W:H:flags=lanczos"
```

**Smart Scaling:**
- If only width: `scale=1920:-2` (auto height, even)
- If only height: `scale=-2:1080` (auto width, even)
- If both: `scale=1920:1080` (exact)
- If auto-correct only: `scale=\'trunc(iw/2)*2\':\'trunc(ih/2)*2\'`

---

## Phase 3: Merge Tab Enhancements (Completed)

### Challenge
FFmpeg concat demuxer requires **identical** codecs, resolutions, and frame rates.

### Solution Approach
**Two-stage process:**

#### Stage 1: Analysis
1. Scan all input videos
2. Detect dimensions, codecs, frame rates
3. Find most common resolution
4. Identify mismatches

#### Stage 2: Normalization Options
**Option A: Re-encode to common format (slower, compatible)**
- Scale all videos to target resolution
- Re-encode with same codec
- Use concat demuxer

**Option B: Direct concat (faster, requires matching)**
- Only if all videos match
- Use copy codec

### UI Changes
Add new GroupBox: **"Resolution Handling"**

**Display:**
- List all video dimensions
- Show warnings for mismatches
- Highlight most common resolution

**Controls:**
1. Radio buttons:
   - "Auto-detect best resolution" (default)
   - "Use custom resolution"
   - "Keep original (may fail if mismatched)"

2. If custom:
   - Width/Height fields
   - Preset buttons

3. Toggle: "Re-encode for compatibility" (default: ON if mismatched)

4. Scale quality dropdown (if re-encoding)

### Backend Changes
**New Function:** `analyzeVideoFiles()`
```swift
struct VideoAnalysisResult {
    let files: [String: VideoDimensionInfo]
    let mostCommonResolution: (width: Int, height: Int)
    let hasMixedResolutions: Bool
    let hasMixedCodecs: Bool
    let hasMixedFrameRates: Bool
    let needsReencoding: Bool
}
```

**Update:** `mergeFiles()` function

**New Parameters:**
- `normalizeResolution: Bool`
- `targetWidth: Int?`
- `targetHeight: Int?`
- `scaleFilter: String`

**FFmpeg Strategy:**

**If normalization needed:**
```bash
# Create normalized temp files
ffmpeg -i input1.mp4 -vf scale=1920:1080 -c:v libx264 temp1.mp4
ffmpeg -i input2.mp4 -vf scale=1920:1080 -c:v libx264 temp2.mp4

# Then concat
ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4
```

**If all match:**
```bash
# Direct concat (existing behavior)
ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4
```

---

## Phase 4: Interactive Cut/Trim Tab Overhaul (Completed)

### Goal
Merge Trim and Cut functionality into a single, interactive tab with a video preview and timecode marking system.

### UI Changes
- **Tab Icon:** Keep the Scissors icon.
- **Video Preview Area:**
    - Responsive video player showing the selected input file.
    - Text caption indicating current dimensions.
- **Control Bar:**
    - Buttons: **Play**, **Pause**, **Set Start**, **Set End**, **Add Segment**.
- **Progress Bar:**
    - Interactive scrubber with visual markers for Trim (yellow) and Cut (blue).
    - Displays current timecode.
- **Trim Section:**
    - Single Start/End timecode entry fields.
    - Caution icon/tooltip for flipped timecodes.
- **Cut Section:**
    - Dynamic list of Cut Segments (Start/End timecode pairs).
    - Checkbox next to each segment: "Export as separate file."

### Backend Changes
- **Video Preview Generation:** Implemented a mechanism to generate a low-resolution, scrubbable proxy video (e.g., a series of thumbnails or a short, low-bitrate proxy video).
- **Timecode Logic:**
    - Implemented logic for **Set Start** and **Set End** buttons: Updates Trim Start/End fields with current playback time.
    - Implemented logic for **Add Segment** button: Adds a new segment to the Cut Segments list with the current playback time.
- **Processing Logic (Unified `processCutTrim`):**
    1.  **Apply Trim:** Uses `-ss` and `-to` to trim the video first, creating a temporary trimmed file (if only trim is used).
    2.  **Apply Cuts:** Uses the temporary trimmed file as the input for the multi-segment cut logic.
    3.  **Timecode Shifting:** The Cut Segments are calculated relative to the start of the *trimmed* video.
    4.  **Segment Export:** If "Export as separate file" is checked for a segment, runs a separate FFmpeg command for that segment using the original file and the original timecodes.

### FFmpeg Strategy
- **Trim Only:** `ffmpeg -ss [start] -to [end] -i [input] -c copy [output]`
- **Cut Only:** `ffmpeg -i [input] -filter_complex "[video_select_filter][audio_select_filter]concat..." [output]`
- **Trim then Cut:**
    1. `ffmpeg -ss [trim_start] -to [trim_end] -i [input] -c copy [temp_trimmed]`
    2. `ffmpeg -i [temp_trimmed] -filter_complex "[cut_select_filter_relative_to_trim]concat..." [output]`

---

## Phase 5: Extract Audio & Batch Processing

### Overview
Implement a dedicated tab for extracting audio from one or more video files, allowing the user to select the output format, codec, and bitrate. This phase will introduce batch processing capabilities.

### UI Changes
Create a new tab and view: **"Extract Audio View"**

**Controls:**
1.  **Input Files:** Button to select multiple video files (batch processing).
2.  **Output Folder:** Button to select the destination directory.
3.  **Output Settings GroupBox:**
    *   **Format Picker:** Dropdown for output container (e.g., `mp3`, `m4a`, `flac`, `wav`).
    *   **Codec Picker:** Dropdown for audio codec (e.g., AAC, MP3, FLAC, Copy).
    *   **Bitrate Field:** Text field for custom bitrate (e.g., `192k`, `320k`).
4.  **Extract Button:** Triggers the batch operation.

**Display:**
-   List of selected input files.
-   Status display for batch progress (e.g., "Processing 3 of 10 files...").

### Backend Changes
**New Function:** `extractAudio(inputPaths: outputFolder: codec: bitrate: format: completion:)` in `FFmpegWrapper.swift`

**Logic:**
1.  Iterate through the `inputPaths` array.
2.  For each input file, construct the output file path using the `outputFolder` and the selected `format`.
3.  Construct the FFmpeg command for audio extraction.

**FFmpeg Command:**
```bash
# Example for extracting AAC audio
ffmpeg -i "input.mp4" -vn -c:a aac -b:a 192k -y "output_folder/input.m4a"
# -vn: disable video recording
# -c:a: set audio codec
# -b:a: set audio bitrate
```

**Batch Progress:**
-   Update the `statusMessage` and `progress` variables in `FFmpegWrapper` to reflect the overall batch progress (e.g., `progress = (currentFileIndex + 1) / totalFiles`).

### Implementation Order
1.  **FFmpegWrapper:** Add `extractAudio()` function.
2.  **ContentView:** Add the new "Extract Audio" tab and `ExtractAudioView`.
3.  **ExtractAudioView:** Implement UI controls and logic to call `extractAudio()`.
4.  **FFmpegWrapper:** Update `runFFmpeg` to better handle batch progress reporting.
5.  **Testing:** Test with various input formats and output settings.
6.  **Documentation:** Update README with the new feature.
