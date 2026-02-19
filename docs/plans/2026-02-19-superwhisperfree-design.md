# Superwhisperfree Mac App - Design Document

## Overview

Local offline dictation app for macOS. Hold a hotkey to record, transcribe with Parakeet (or Whisper) via Python helper, paste result at cursor. No cloud - everything runs locally.

## App Type

Menu bar app (no dock icon). Primary interaction is the recording overlay that appears on hotkey.

## User Flow

1. **First launch** → Onboarding (welcome → feature tour → setup → test recording → done)
2. **App minimizes** to menu bar
3. **Hold hotkey** → Overlay appears near cursor → Record → Release → Transcribe → Paste
4. **Click menu bar** → Open Dashboard for analytics/settings

## Architecture

### Swift App (AppKit)

| Component | Responsibility |
|-----------|----------------|
| `AppDelegate` | App lifecycle, menu bar setup |
| `MenuBarController` | Menu bar icon and dropdown menu |
| `RecordingOverlay` | Floating panel near cursor during recording |
| `DashboardWindow` | Settings and analytics window |
| `OnboardingWindow` | First-launch experience |
| `AudioRecorder` | AVFoundation recording to 16kHz mono WAV |
| `HotkeyManager` | Global hotkey via Carbon API |
| `PasteService` | NSPasteboard + CGEvent for Cmd+V simulation |
| `TranscriptionClient` | UNIX socket client to Python helper |
| `SettingsManager` | Read/write settings.json |
| `AnalyticsManager` | Track usage, calculate time saved |

### Python Transcription System

| File | Responsibility |
|------|----------------|
| `transcribe_helper.py` | Socket server, loads Parakeet, transcribes audio |
| `setup_ui.py` | Tkinter preferences UI (model, hotkey, settings) |
| `model_downloader.py` | Download Parakeet/Whisper models |

### IPC Protocol

UNIX socket at `~/Library/Application Support/Superwhisperfree/transcribe.sock`

- Request: `TRANSCRIBE:/path/to/audio.wav`
- Response: `TEXT:transcribed text` or `ERROR:message`

## Recording Overlay

- `NSPanel` with floating level, appears near cursor
- ~200×80pt, rounded corners, minimal black style
- States: Recording (waveform) → Transcribing (spinner) → Fade out + paste

## Dashboard Window

**Analytics Section:**
- Minutes saved (large display)
- Words dictated (total)
- Your typing WPM (from test)
- Speaking WPM (calculated)
- Line graph: daily usage and time saved

**WPM Typing Test:**
- 60-second timed test
- Shows paragraph to type
- Calculates and stores WPM

**Settings Section:**
- Model selection (Parakeet default, Whisper options)
- UI color/animation preferences
- Hotkey configuration
- Start on login toggle
- Download/update model button

**Time Saved Calculation:**
- Benchmark: 45 WPM (average typing)
- Formula: `minutes_saved = words_dictated × (1/45 - 1/speaking_wpm)`

## Onboarding Flow

1. **Welcome** - Logo, tagline, "Get Started"
2. **Feature Tour** (3-4 animated slides):
   - Hold to Record
   - Instant Transcription
   - Paste Anywhere
   - Track Productivity
3. **Setup** - Accessibility permission, hotkey config, model download
4. **Test Recording** - Try it live in onboarding
5. **Done** - Minimize to menu bar

## Design System (SuperwhisperUI)

| Token | Value |
|-------|-------|
| `background` | `#0A0A0A` |
| `surface` | `#141414` |
| `surfaceHover` | `#1A1A1A` |
| `text` | `#FFFFFF` |
| `textSecondary` | `#888888` |
| `accent` | `#FFFFFF` |
| `error` | `#FF4444` |
| `success` | `#44FF44` |
| `cornerRadius` | 12pt (windows), 8pt (buttons) |
| `fontHeading` | Montserrat SemiBold |
| `fontBody` | SF Pro / Montserrat Regular |

## Data Storage

Location: `~/Library/Application Support/Superwhisperfree/`

**settings.json:**
```json
{
  "model_type": "parakeet",
  "model_size": "default",
  "hotkey": {"modifiers": ["cmd"], "key": "rightAlt"},
  "start_on_login": false,
  "ui_theme": "dark"
}
```

**analytics.json:**
```json
{
  "typing_wpm": 65,
  "daily_stats": [
    {"date": "2026-02-19", "words": 1250, "recordings": 23, "total_duration_sec": 180}
  ]
}
```

## Project Structure

```
superwhisperfreev2/
├── Superwhisperfree/
│   ├── Superwhisperfree.xcodeproj
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── AppDelegate.swift
│   │   │   └── MenuBarController.swift
│   │   ├── Windows/
│   │   │   ├── RecordingOverlay.swift
│   │   │   ├── DashboardWindow.swift
│   │   │   └── OnboardingWindow.swift
│   │   ├── Views/
│   │   │   ├── Onboarding/
│   │   │   ├── Dashboard/
│   │   │   └── Components/
│   │   ├── Services/
│   │   │   ├── AudioRecorder.swift
│   │   │   ├── HotkeyManager.swift
│   │   │   ├── TranscriptionClient.swift
│   │   │   ├── PasteService.swift
│   │   │   ├── SettingsManager.swift
│   │   │   └── AnalyticsManager.swift
│   │   └── DesignSystem/
│   │       └── SuperwhisperUI/
│   └── Resources/
│       ├── Fonts/
│       ├── Assets.xcassets
│       └── Info.plist
├── python/
│   ├── transcribe_helper.py
│   ├── setup_ui.py
│   ├── model_downloader.py
│   └── requirements.txt
├── scripts/
│   ├── dev-build.sh
│   └── build-release.sh (placeholder)
└── docs/
    └── plans/
```

## Build & Distribution

- Dev builds: unsigned, run locally
- Release: placeholder scripts for future Developer ID signing + notarization
- LSUIElement = YES (no dock icon)

## Permissions Required

- Accessibility (global hotkey, paste simulation)
- Microphone (audio recording)
