# Implementation Plan: Video Scaling & Multi-Resolution Merge

## Overview
Add video dimension detection and scaling capabilities to the Convert and Merge tabs, similar to the image sequence feature.

---

## Phase 1: Video Dimension Detection

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

## Phase 2: Convert Tab Enhancements

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
- If auto-correct only: `scale='if(mod(iw,2),iw+1,iw)':'if(mod(ih,2),ih+1,ih)'`

---

## Phase 3: Merge Tab Enhancements

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

## Phase 4: Shared Components

### Reusable UI Components
Create: `DimensionControlsView`
- Width/Height fields
- Preset buttons
- Scale quality picker
- Aspect ratio lock

### Reusable Functions
- `makeEvenDimension(_ value: Int) -> Int`
- `calculateAspectRatioHeight(width: Int, aspectRatio: Double) -> Int`
- `calculateAspectRatioWidth(height: Int, aspectRatio: Double) -> Int`

---

## Implementation Order

1. ✅ **FFmpegWrapper:** Add `getVideoDimensions()` using ffprobe
2. ✅ **FFmpegWrapper:** Add `analyzeVideoFiles()` for batch analysis
3. ✅ **Convert Tab:** Add dimension display and scaling controls
4. ✅ **Convert Tab:** Update `convertFormat()` with scaling parameters
5. ✅ **Merge Tab:** Add video analysis on file selection
6. ✅ **Merge Tab:** Add resolution handling UI
7. ✅ **Merge Tab:** Update `mergeFiles()` with normalization logic
8. ✅ **Testing:** Test with various resolutions and codecs
9. ✅ **Documentation:** Update README with new features

---

## Edge Cases to Handle

1. **Odd dimensions:** Auto-correct or warn user
2. **Extreme aspect ratios:** Validate reasonable ranges
3. **Very large files:** Show progress during normalization
4. **Codec incompatibility:** Force re-encode if needed
5. **Frame rate mismatch:** Option to normalize FPS
6. **Audio track handling:** Preserve audio during scaling

---

## User Experience Flow

### Convert Tab
1. User selects input video
2. App displays: "Input: 1920×1080 (H.264, 30fps)"
3. User enables "Resize video"
4. User selects preset "1280×720" or enters custom
5. App shows: "Output will be: 1280×720"
6. User clicks Convert
7. FFmpeg applies scale filter during conversion

### Merge Tab
1. User adds multiple videos
2. App analyzes: "3 videos: 1920×1080 (2), 1280×720 (1)"
3. App shows warning: "⚠️ Mixed resolutions detected"
4. App suggests: "Auto-detect best resolution: 1920×1080"
5. User can accept or customize
6. User clicks Merge
7. If needed, app normalizes videos then merges
8. Progress shows: "Normalizing video 1/3..." then "Merging..."

---

## Technical Notes

### FFprobe JSON Parsing
```json
{
  "streams": [{
    "codec_name": "h264",
    "width": 1920,
    "height": 1080,
    "r_frame_rate": "30/1",
    "duration": "120.5"
  }]
}
```

### Scale Filter Quality Options
- `lanczos` - Highest quality (default)
- `bicubic` - Good quality, faster
- `bilinear` - Medium quality
- `fast_bilinear` - Fastest, lower quality
- `neighbor` - Nearest neighbor (pixel art)

### Performance Considerations
- Normalization is CPU-intensive
- Show progress bar for long operations
- Consider temp file cleanup on cancel
- Warn user about disk space for temp files

---

## Success Criteria

✅ Convert tab can resize videos with quality options
✅ Merge tab detects resolution mismatches
✅ Merge tab can normalize videos to common resolution
✅ Odd dimensions are automatically corrected
✅ User is informed of what will happen before processing
✅ Progress is shown during normalization
✅ Temp files are cleaned up properly

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

---
