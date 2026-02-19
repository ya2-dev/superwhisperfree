# Superwhisperfree

A free, open-source macOS dictation app with local offline transcription. Hold a hotkey to record, release to transcribe and paste.

## Features

- **Hold-to-Record**: Press and hold your configured hotkey to record, release to transcribe
- **Local Transcription**: All speech-to-text processing happens on your Mac using NVIDIA NeMo
- **Auto-Paste**: Transcribed text is automatically pasted into the active application
- **Privacy First**: No audio leaves your computer, no internet required
- **Lightweight**: Menu bar app that stays out of your way

## Prerequisites

- **macOS 13.0** (Ventura) or later
- **Python 3.10** or later
- **Xcode Command Line Tools**

### Install Prerequisites

```bash
# Install Xcode command line tools
xcode-select --install

# Install Python dependencies
pip3 install nemo_toolkit[asr] torch torchaudio
```

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/superwhisperfreev2.git
   cd superwhisperfreev2
   ```

2. **Build the app**
   ```bash
   ./scripts/dev-build.sh
   ```

3. **Run**
   ```bash
   ./scripts/run-dev.sh
   ```

4. **Grant permissions** when prompted:
   - Microphone access (for recording)
   - Accessibility access (for hotkey detection and text paste)

5. **Use**: Hold the configured hotkey (default: Right Option) to record, release to transcribe

## Build Commands

| Command | Description |
|---------|-------------|
| `./scripts/dev-build.sh` | Build for development (no code signing) |
| `./scripts/run-dev.sh` | Build and run the app |
| `./scripts/build-release.sh` | Instructions for release build |
| `./python/start_helper.sh` | Start transcription helper manually |

## Architecture

```
superwhisperfreev2/
├── Superwhisperfree/
│   └── Sources/
│       ├── App/
│       │   ├── main.swift              # Entry point
│       │   ├── AppDelegate.swift       # App lifecycle
│       │   └── MenuBarController.swift # Menu bar UI
│       ├── Services/
│       │   ├── AudioRecorder.swift     # Audio capture
│       │   ├── HotkeyManager.swift     # Global hotkey handling
│       │   ├── RecordingCoordinator.swift # Orchestrates recording flow
│       │   ├── TranscriptionClient.swift  # Python helper communication
│       │   ├── PasteService.swift      # Text insertion
│       │   └── SettingsManager.swift   # Preferences persistence
│       ├── Windows/
│       │   ├── OnboardingWindow.swift  # First-run setup
│       │   └── RecordingOverlay.swift  # Recording indicator
│       ├── Views/
│       │   └── ...                     # UI components
│       └── DesignSystem/
│           └── DesignTokens.swift      # Colors, typography, spacing
├── python/
│   ├── transcribe_helper.py   # NeMo transcription server
│   ├── setup_ui.py           # Preferences UI (Python/tkinter)
│   ├── model_downloader.py   # Model download utility
│   └── start_helper.sh       # Helper start script
└── scripts/
    ├── dev-build.sh          # Development build
    ├── build-release.sh      # Release build (placeholder)
    └── run-dev.sh           # Build and run
```

### How It Works

1. **HotkeyManager** monitors for the configured hotkey (default: Right Option key)
2. On hotkey press, **RecordingCoordinator** starts **AudioRecorder** to capture audio
3. **RecordingOverlay** appears near the cursor showing recording state
4. On hotkey release, audio is sent to **TranscriptionClient**
5. **TranscriptionClient** communicates with the Python helper via Unix socket
6. The Python helper uses NeMo's Parakeet model for transcription
7. Transcribed text is pasted via **PasteService** using accessibility APIs

### Python Transcription Helper

The helper (`python/transcribe_helper.py`) runs as a background process:
- Listens on a Unix domain socket
- Loads the NeMo Parakeet model (downloads on first use)
- Accepts transcription requests from the Swift app
- Returns transcribed text

## Configuration

Settings are stored in `~/Library/Application Support/Superwhisperfree/`:

- `settings.json` - User preferences
- `transcribe.sock` - Unix socket for helper communication

### Hotkey Configuration

Default hotkey is **Right Option** (⌥). Can be changed to:
- Any modifier + key combination
- Different modifier keys

## Troubleshooting

### "Transcription helper failed to start"
- Ensure Python 3.10+ is installed
- Install NeMo: `pip3 install nemo_toolkit[asr]`
- Check helper manually: `./python/start_helper.sh`

### No text appears after recording
- Grant Accessibility permissions in System Preferences
- Ensure a text field is focused when releasing the hotkey

### Hotkey not working
- Grant Accessibility permissions
- Check if another app is using the same hotkey
- Try a different hotkey combination

## Development

### Requirements

- Xcode 15+ (for swiftc)
- Python 3.10+
- ~4GB disk space for NeMo model

### Building

The development build uses `swiftc` directly without Xcode projects:

```bash
./scripts/dev-build.sh
```

Output: `build/Superwhisperfree`

### Running Tests

```bash
# Test transcription helper
python3 python/test_transcription.py
```

## License

[Add your license here]

## Acknowledgments

- [NVIDIA NeMo](https://github.com/NVIDIA/NeMo) for the Parakeet ASR model
- Inspired by [Superwhisper](https://superwhisper.com)
