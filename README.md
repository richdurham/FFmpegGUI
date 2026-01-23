# FFmpeg GUI for macOS

A native macOS application that provides a graphical user interface for common FFmpeg operations. Built with Swift and SwiftUI.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### 1. Video/Audio Format Conversion
- Convert between popular video formats (MP4, MOV, AVI, MKV, WebM, etc.)
- Convert between audio formats (MP3, AAC, WAV, FLAC, etc.)
- Choose video codec (H.264, H.265/HEVC, VP9, ProRes)
- Choose audio codec (AAC, MP3, Opus, FLAC)
- Optional bitrate control for video and audio

### 2. Video Trimming
- Cut videos by specifying start and end times
- Supports time formats: `HH:MM:SS` or seconds
- Fast trimming using stream copy (no re-encoding)

### 3. File Merging
- Merge multiple video or audio files into one
- Drag and drop reordering
- Supports concatenation of compatible files

### 4. Image Sequence to Video
- Convert a folder of images (PNG, JPG, JPEG, BMP, TIFF) to video
- Adjustable frame rate (24, 30, 60 fps presets)
- Multiple codec options for output quality
- Automatic image sorting and numbering

## Requirements

- **macOS 13.0 (Ventura)** or later
- **FFmpeg** installed on your system

### Installing FFmpeg

The easiest way to install FFmpeg on macOS is via [Homebrew](https://brew.sh/):

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install FFmpeg
brew install ffmpeg
```

The app automatically detects FFmpeg in common installation locations:
- `/opt/homebrew/bin/ffmpeg` (Apple Silicon Homebrew)
- `/usr/local/bin/ffmpeg` (Intel Homebrew)
- `/usr/bin/ffmpeg` (System)
- `/opt/local/bin/ffmpeg` (MacPorts)

## Installation

### Option 1: Build from Source (Recommended)

1. Clone or download this repository
2. Open `FFmpegGUI.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities (or disable signing for local use)
4. Build and run (⌘R)

### Option 2: Build via Command Line

```bash
cd FFmpegGUI
xcodebuild -project FFmpegGUI.xcodeproj -scheme FFmpegGUI -configuration Release build
```

## Usage

### Converting Files

1. Click the **Convert** tab
2. Click **Browse** to select your input file
3. Choose output format, video codec, and audio codec
4. Optionally set bitrate values
5. Click **Browse** to choose output location
6. Click **Convert**

### Trimming Videos

1. Click the **Trim** tab
2. Select your input video file
3. Enter start time (e.g., `00:01:30` or `90`)
4. Enter end time (e.g., `00:05:00` or `300`)
5. Choose output location
6. Click **Trim Video**

### Merging Files

1. Click the **Merge** tab
2. Click **Add Files** to select files to merge
3. Reorder files by dragging if needed
4. Choose output location
5. Click **Merge Files**

> **Note:** For best results, files should have the same codec and resolution.

### Creating Video from Images

1. Click the **Images → Video** tab
2. Click **Browse** to select a folder containing images
3. Set the desired frame rate
4. Choose a video codec
5. Select output location
6. Click **Create Video**

> **Tip:** Images are sorted alphabetically. Name your files with leading zeros (e.g., `img001.png`, `img002.png`) for correct ordering.

## Project Structure

```
FFmpegGUI/
├── FFmpegGUI.xcodeproj/     # Xcode project file
├── FFmpegGUI/
│   ├── FFmpegGUIApp.swift   # App entry point
│   ├── ContentView.swift    # Main UI with all tabs
│   ├── FFmpegWrapper.swift  # FFmpeg command execution
│   ├── FFmpegGUI.entitlements
│   └── Assets.xcassets/     # App icons and colors
└── README.md
```

## Troubleshooting

### "FFmpeg not found"
- Ensure FFmpeg is installed (`brew install ffmpeg`)
- Check that FFmpeg is in one of the expected paths
- Try running `which ffmpeg` in Terminal to verify installation

### Conversion fails
- Check the log output (click "Show Log")
- Ensure input file is not corrupted
- Try using "Copy" codec option to avoid re-encoding issues

### Merge produces unexpected results
- Ensure all files have the same codec, resolution, and frame rate
- For different formats, convert files to the same format first

## License

MIT License - Feel free to modify and distribute.

## Credits

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Powered by [FFmpeg](https://ffmpeg.org/)
