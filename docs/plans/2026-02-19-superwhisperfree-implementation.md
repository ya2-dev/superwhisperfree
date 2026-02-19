# Superwhisperfree Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a menu bar dictation app for macOS with local Parakeet/Whisper transcription.

**Architecture:** Swift/AppKit menu bar app communicates with Python transcription helper via UNIX socket. Recording overlay appears on global hotkey, transcribes audio, pastes at cursor.

**Tech Stack:** Swift 5.9+, AppKit, AVFoundation, Carbon (hotkeys), Python 3.10+, faster-whisper, nemo-toolkit (Parakeet), Tkinter

---

## Parallel Workstreams

This plan is organized into **6 independent workstreams** that can be executed in parallel:

| # | Workstream | Dependencies | Estimated Tasks |
|---|------------|--------------|-----------------|
| 1 | Python Transcription System | None | 5 tasks |
| 2 | Swift Project Setup + Core | None | 4 tasks |
| 3 | Swift Recording + Hotkey | Workstream 2 | 5 tasks |
| 4 | Swift Onboarding Flow | Workstream 2 | 5 tasks |
| 5 | Swift Dashboard + Analytics | Workstream 2 | 6 tasks |
| 6 | Integration + Polish | All above | 4 tasks |

**Workstreams 1-5 can run in parallel.** Workstream 6 integrates everything.

---

# Workstream 1: Python Transcription System

### Task 1.1: Project Setup and Dependencies

**Files:**
- Create: `python/requirements.txt`
- Create: `python/__init__.py`

**Step 1: Create requirements.txt**

```txt
faster-whisper>=1.0.0
nemo-toolkit[asr]>=1.22.0
torch>=2.0.0
```

**Step 2: Create empty __init__.py**

```python
# Python transcription package
```

**Step 3: Verify Python environment**

Run: `python3 --version` (should be 3.10+)

---

### Task 1.2: Model Downloader

**Files:**
- Create: `python/model_downloader.py`

**Step 1: Create model_downloader.py**

```python
#!/usr/bin/env python3
"""Download and manage Parakeet/Whisper models."""

import os
import sys
from pathlib import Path

def get_app_support_dir() -> Path:
    """Get the app support directory."""
    return Path.home() / "Library" / "Application Support" / "Superwhisperfree"

def get_models_dir() -> Path:
    """Get the models directory."""
    models_dir = get_app_support_dir() / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    return models_dir

def download_parakeet(progress_callback=None):
    """Download Parakeet TDT 1.1B model."""
    try:
        import nemo.collections.asr as nemo_asr
        
        if progress_callback:
            progress_callback("Downloading Parakeet model...", 0)
        
        model_name = "nvidia/parakeet-tdt-1.1b"
        model = nemo_asr.models.ASRModel.from_pretrained(model_name)
        
        model_path = get_models_dir() / "parakeet-tdt-1.1b"
        model.save_to(str(model_path / "model.nemo"))
        
        if progress_callback:
            progress_callback("Parakeet model downloaded!", 100)
        
        return True
    except Exception as e:
        print(f"Error downloading Parakeet: {e}", file=sys.stderr)
        return False

def download_whisper(model_size="base", progress_callback=None):
    """Download Whisper model via faster-whisper."""
    try:
        from faster_whisper import WhisperModel
        
        if progress_callback:
            progress_callback(f"Downloading Whisper {model_size}...", 0)
        
        model = WhisperModel(model_size, device="cpu", compute_type="int8")
        
        if progress_callback:
            progress_callback(f"Whisper {model_size} ready!", 100)
        
        return True
    except Exception as e:
        print(f"Error downloading Whisper: {e}", file=sys.stderr)
        return False

def is_model_downloaded(model_type="parakeet") -> bool:
    """Check if a model is already downloaded."""
    if model_type == "parakeet":
        model_path = get_models_dir() / "parakeet-tdt-1.1b" / "model.nemo"
        return model_path.exists()
    else:
        from faster_whisper.utils import download_model
        try:
            return True
        except:
            return False

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", choices=["parakeet", "whisper"], default="parakeet")
    parser.add_argument("--size", default="base", help="Whisper model size")
    args = parser.parse_args()
    
    if args.model == "parakeet":
        download_parakeet(lambda msg, pct: print(f"{msg} ({pct}%)"))
    else:
        download_whisper(args.size, lambda msg, pct: print(f"{msg} ({pct}%)"))
```

**Step 2: Test model downloader**

Run: `cd python && python3 model_downloader.py --model parakeet`

---

### Task 1.3: Transcription Helper Socket Server

**Files:**
- Create: `python/transcribe_helper.py`

**Step 1: Create transcribe_helper.py**

```python
#!/usr/bin/env python3
"""Long-lived transcription helper with UNIX socket server."""

import os
import sys
import json
import socket
import threading
from pathlib import Path

class TranscriptionServer:
    def __init__(self):
        self.app_support = Path.home() / "Library" / "Application Support" / "Superwhisperfree"
        self.app_support.mkdir(parents=True, exist_ok=True)
        self.socket_path = self.app_support / "transcribe.sock"
        self.settings_path = self.app_support / "settings.json"
        self.model = None
        self.model_type = None
        
    def load_settings(self) -> dict:
        """Load settings from JSON file."""
        if self.settings_path.exists():
            with open(self.settings_path) as f:
                return json.load(f)
        return {"model_type": "parakeet", "model_size": "base"}
    
    def load_model(self):
        """Load the transcription model based on settings."""
        settings = self.load_settings()
        self.model_type = settings.get("model_type", "parakeet")
        
        print(f"Loading {self.model_type} model...", file=sys.stderr)
        
        if self.model_type == "parakeet":
            import nemo.collections.asr as nemo_asr
            model_path = self.app_support / "models" / "parakeet-tdt-1.1b" / "model.nemo"
            if model_path.exists():
                self.model = nemo_asr.models.ASRModel.restore_from(str(model_path))
            else:
                self.model = nemo_asr.models.ASRModel.from_pretrained("nvidia/parakeet-tdt-1.1b")
        else:
            from faster_whisper import WhisperModel
            model_size = settings.get("model_size", "base")
            self.model = WhisperModel(model_size, device="cpu", compute_type="int8")
        
        print(f"Model loaded!", file=sys.stderr)
    
    def transcribe(self, audio_path: str) -> str:
        """Transcribe an audio file."""
        if self.model is None:
            self.load_model()
        
        if self.model_type == "parakeet":
            result = self.model.transcribe([audio_path])
            return result[0][0] if result else ""
        else:
            segments, _ = self.model.transcribe(audio_path, beam_size=5)
            return " ".join(segment.text for segment in segments).strip()
    
    def handle_client(self, conn):
        """Handle a client connection."""
        try:
            data = conn.recv(4096).decode('utf-8').strip()
            
            if data.startswith("TRANSCRIBE:"):
                audio_path = data[11:]
                if os.path.exists(audio_path):
                    try:
                        text = self.transcribe(audio_path)
                        conn.send(f"TEXT:{text}".encode('utf-8'))
                    except Exception as e:
                        conn.send(f"ERROR:{str(e)}".encode('utf-8'))
                else:
                    conn.send(f"ERROR:File not found: {audio_path}".encode('utf-8'))
            elif data == "PING":
                conn.send(b"PONG")
            elif data == "RELOAD":
                self.model = None
                self.load_model()
                conn.send(b"OK")
            elif data == "QUIT":
                conn.send(b"OK")
                return False
            else:
                conn.send(f"ERROR:Unknown command".encode('utf-8'))
        except Exception as e:
            print(f"Client error: {e}", file=sys.stderr)
        finally:
            conn.close()
        return True
    
    def run(self):
        """Run the socket server."""
        if self.socket_path.exists():
            self.socket_path.unlink()
        
        self.load_model()
        
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(self.socket_path))
        server.listen(5)
        
        print(f"Transcription server listening on {self.socket_path}", file=sys.stderr)
        
        running = True
        while running:
            conn, _ = server.accept()
            running = self.handle_client(conn)
        
        server.close()
        self.socket_path.unlink()

if __name__ == "__main__":
    server = TranscriptionServer()
    server.run()
```

**Step 2: Test server manually**

Run in terminal 1: `python3 python/transcribe_helper.py`
Run in terminal 2: `echo "PING" | nc -U ~/Library/Application\ Support/Superwhisperfree/transcribe.sock`
Expected: `PONG`

---

### Task 1.4: Settings/Preferences UI (Tkinter)

**Files:**
- Create: `python/setup_ui.py`

**Step 1: Create setup_ui.py**

```python
#!/usr/bin/env python3
"""Tkinter-based preferences UI for Superwhisperfree."""

import json
import threading
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path

from model_downloader import download_parakeet, download_whisper, is_model_downloaded, get_app_support_dir

class PreferencesUI:
    def __init__(self):
        self.app_support = get_app_support_dir()
        self.settings_path = self.app_support / "settings.json"
        self.settings = self.load_settings()
        
        self.root = tk.Tk()
        self.root.title("Superwhisperfree Preferences")
        self.root.geometry("400x500")
        self.root.configure(bg="#0A0A0A")
        
        self.setup_styles()
        self.create_widgets()
        
    def load_settings(self) -> dict:
        """Load settings from file."""
        if self.settings_path.exists():
            with open(self.settings_path) as f:
                return json.load(f)
        return {
            "model_type": "parakeet",
            "model_size": "base",
            "hotkey": {"modifiers": ["cmd"], "key": "rightAlt"},
            "start_on_login": False
        }
    
    def save_settings(self):
        """Save settings to file."""
        self.app_support.mkdir(parents=True, exist_ok=True)
        with open(self.settings_path, 'w') as f:
            json.dump(self.settings, f, indent=2)
    
    def setup_styles(self):
        """Configure ttk styles for dark theme."""
        style = ttk.Style()
        style.theme_use('clam')
        
        style.configure("Dark.TFrame", background="#0A0A0A")
        style.configure("Dark.TLabel", background="#0A0A0A", foreground="#FFFFFF", font=("SF Pro", 12))
        style.configure("Dark.TButton", background="#141414", foreground="#FFFFFF", font=("SF Pro", 11))
        style.configure("Header.TLabel", background="#0A0A0A", foreground="#FFFFFF", font=("SF Pro", 16, "bold"))
        style.configure("Dark.TRadiobutton", background="#0A0A0A", foreground="#FFFFFF", font=("SF Pro", 11))
        
    def create_widgets(self):
        """Create the UI widgets."""
        main_frame = ttk.Frame(self.root, style="Dark.TFrame", padding=20)
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        ttk.Label(main_frame, text="Preferences", style="Header.TLabel").pack(anchor=tk.W, pady=(0, 20))
        
        ttk.Label(main_frame, text="Transcription Model", style="Dark.TLabel").pack(anchor=tk.W, pady=(10, 5))
        
        self.model_var = tk.StringVar(value=self.settings.get("model_type", "parakeet"))
        
        ttk.Radiobutton(main_frame, text="Parakeet (Recommended)", variable=self.model_var, 
                       value="parakeet", style="Dark.TRadiobutton").pack(anchor=tk.W, padx=10)
        ttk.Radiobutton(main_frame, text="Whisper", variable=self.model_var,
                       value="whisper", style="Dark.TRadiobutton").pack(anchor=tk.W, padx=10)
        
        self.whisper_size_var = tk.StringVar(value=self.settings.get("model_size", "base"))
        whisper_frame = ttk.Frame(main_frame, style="Dark.TFrame")
        whisper_frame.pack(anchor=tk.W, padx=30, pady=5)
        
        for size in ["tiny", "base", "small", "medium"]:
            ttk.Radiobutton(whisper_frame, text=size.capitalize(), variable=self.whisper_size_var,
                           value=size, style="Dark.TRadiobutton").pack(side=tk.LEFT, padx=5)
        
        self.progress_var = tk.StringVar(value="")
        self.progress_label = ttk.Label(main_frame, textvariable=self.progress_var, style="Dark.TLabel")
        self.progress_label.pack(anchor=tk.W, pady=10)
        
        self.progress_bar = ttk.Progressbar(main_frame, length=300, mode='determinate')
        self.progress_bar.pack(anchor=tk.W, pady=5)
        
        self.download_btn = ttk.Button(main_frame, text="Download Model", 
                                       command=self.download_model, style="Dark.TButton")
        self.download_btn.pack(anchor=tk.W, pady=10)
        
        ttk.Separator(main_frame).pack(fill=tk.X, pady=20)
        
        ttk.Label(main_frame, text="Hotkey", style="Dark.TLabel").pack(anchor=tk.W, pady=(10, 5))
        
        hotkey_frame = ttk.Frame(main_frame, style="Dark.TFrame")
        hotkey_frame.pack(anchor=tk.W)
        
        self.hotkey_display = ttk.Label(hotkey_frame, text=self.format_hotkey(), style="Dark.TLabel")
        self.hotkey_display.pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(hotkey_frame, text="Set Hotkey", command=self.capture_hotkey, 
                  style="Dark.TButton").pack(side=tk.LEFT)
        
        ttk.Separator(main_frame).pack(fill=tk.X, pady=20)
        
        ttk.Button(main_frame, text="Save & Close", command=self.save_and_close,
                  style="Dark.TButton").pack(anchor=tk.E, pady=10)
        
        self.update_model_status()
    
    def format_hotkey(self) -> str:
        """Format hotkey for display."""
        hk = self.settings.get("hotkey", {})
        mods = hk.get("modifiers", [])
        key = hk.get("key", "rightAlt")
        
        mod_symbols = {"cmd": "⌘", "ctrl": "⌃", "alt": "⌥", "shift": "⇧"}
        mod_str = "".join(mod_symbols.get(m, m) for m in mods)
        
        return f"{mod_str}{key}"
    
    def update_model_status(self):
        """Update the model download status."""
        model_type = self.model_var.get()
        if is_model_downloaded(model_type):
            self.progress_var.set(f"✓ {model_type.capitalize()} model ready")
            self.download_btn.configure(text="Re-download Model")
        else:
            self.progress_var.set(f"Model not downloaded")
            self.download_btn.configure(text="Download Model")
    
    def download_model(self):
        """Download the selected model."""
        self.download_btn.configure(state=tk.DISABLED)
        
        def do_download():
            model_type = self.model_var.get()
            
            def progress(msg, pct):
                self.root.after(0, lambda: self.progress_var.set(msg))
                self.root.after(0, lambda: self.progress_bar.configure(value=pct))
            
            if model_type == "parakeet":
                success = download_parakeet(progress)
            else:
                success = download_whisper(self.whisper_size_var.get(), progress)
            
            self.root.after(0, lambda: self.download_btn.configure(state=tk.NORMAL))
            self.root.after(0, self.update_model_status)
            
            if not success:
                self.root.after(0, lambda: messagebox.showerror("Error", "Failed to download model"))
        
        threading.Thread(target=do_download, daemon=True).start()
    
    def capture_hotkey(self):
        """Open dialog to capture new hotkey."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Press Hotkey")
        dialog.geometry("250x100")
        dialog.configure(bg="#0A0A0A")
        dialog.transient(self.root)
        dialog.grab_set()
        
        ttk.Label(dialog, text="Press your desired hotkey...", style="Dark.TLabel").pack(pady=20)
        
        def on_key(event):
            modifiers = []
            if event.state & 0x8:
                modifiers.append("cmd")
            if event.state & 0x4:
                modifiers.append("ctrl")
            if event.state & 0x1:
                modifiers.append("shift")
            if event.state & 0x10:
                modifiers.append("alt")
            
            self.settings["hotkey"] = {"modifiers": modifiers, "key": event.keysym}
            self.hotkey_display.configure(text=self.format_hotkey())
            dialog.destroy()
        
        dialog.bind("<Key>", on_key)
        dialog.focus_set()
    
    def save_and_close(self):
        """Save settings and close window."""
        self.settings["model_type"] = self.model_var.get()
        self.settings["model_size"] = self.whisper_size_var.get()
        self.save_settings()
        self.root.destroy()
    
    def run(self):
        """Run the UI."""
        self.root.mainloop()

if __name__ == "__main__":
    ui = PreferencesUI()
    ui.run()
```

**Step 2: Test preferences UI**

Run: `python3 python/setup_ui.py`

---

### Task 1.5: Test Transcription End-to-End

**Files:**
- Create: `python/test_transcription.py`

**Step 1: Create test script**

```python
#!/usr/bin/env python3
"""Test transcription with a sample audio file."""

import subprocess
import tempfile
import wave
import struct
import math

def generate_test_audio(path: str, duration: float = 1.0):
    """Generate a simple test audio file (silence with beep)."""
    sample_rate = 16000
    num_samples = int(sample_rate * duration)
    
    with wave.open(path, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        
        for i in range(num_samples):
            value = int(32767 * 0.3 * math.sin(2 * math.pi * 440 * i / sample_rate))
            wav.writeframes(struct.pack('<h', value))

def test_with_socket():
    """Test transcription via socket."""
    import socket
    from pathlib import Path
    
    socket_path = Path.home() / "Library" / "Application Support" / "Superwhisperfree" / "transcribe.sock"
    
    if not socket_path.exists():
        print("ERROR: Transcription server not running. Start with: python3 transcribe_helper.py")
        return
    
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        test_path = f.name
    
    generate_test_audio(test_path)
    print(f"Generated test audio: {test_path}")
    
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(str(socket_path))
    sock.send(f"TRANSCRIBE:{test_path}".encode())
    
    response = sock.recv(4096).decode()
    print(f"Response: {response}")
    
    sock.close()

if __name__ == "__main__":
    test_with_socket()
```

**Step 2: Run test**

Terminal 1: `python3 python/transcribe_helper.py`
Terminal 2: `python3 python/test_transcription.py`

---

# Workstream 2: Swift Project Setup + Core

### Task 2.1: Create Xcode Project Structure

**Files:**
- Create: `Superwhisperfree/Superwhisperfree.xcodeproj` (via Xcode or script)
- Create: `Superwhisperfree/Sources/App/AppDelegate.swift`
- Create: `Superwhisperfree/Sources/App/main.swift`
- Create: `Superwhisperfree/Resources/Info.plist`

**Step 1: Create directory structure**

```bash
mkdir -p Superwhisperfree/Sources/{App,Windows,Views/{Onboarding,Dashboard,Components},Services,DesignSystem/SuperwhisperUI}
mkdir -p Superwhisperfree/Resources/Fonts
```

**Step 2: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Superwhisperfree</string>
    <key>CFBundleIdentifier</key>
    <string>com.superwhisperfree.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>Superwhisperfree</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Superwhisperfree needs microphone access to record your voice for transcription.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Superwhisperfree needs accessibility access to paste transcribed text.</string>
</dict>
</plist>
```

**Step 3: Create main.swift**

```swift
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 4: Create AppDelegate.swift**

```swift
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        
        if !UserDefaults.standard.bool(forKey: "onboardingComplete") {
            showOnboarding()
        }
    }
    
    func setupMenuBar() {
        menuBarController = MenuBarController()
    }
    
    func showOnboarding() {
        let onboarding = OnboardingWindowController()
        onboarding.showWindow(nil)
    }
    
    func showDashboard() {
        let dashboard = DashboardWindowController()
        dashboard.showWindow(nil)
    }
}
```

---

### Task 2.2: Design System Tokens

**Files:**
- Create: `Superwhisperfree/Sources/DesignSystem/SuperwhisperUI/DesignTokens.swift`

**Step 1: Create DesignTokens.swift**

```swift
import Cocoa

public enum DesignTokens {
    public enum Colors {
        public static let background = NSColor(hex: "#0A0A0A")!
        public static let surface = NSColor(hex: "#141414")!
        public static let surfaceHover = NSColor(hex: "#1A1A1A")!
        public static let text = NSColor.white
        public static let textSecondary = NSColor(hex: "#888888")!
        public static let accent = NSColor.white
        public static let error = NSColor(hex: "#FF4444")!
        public static let success = NSColor(hex: "#44FF44")!
    }
    
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }
    
    public enum CornerRadius {
        public static let small: CGFloat = 4
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
    }
    
    public enum Typography {
        public static func heading(size: CGFloat = 24) -> NSFont {
            NSFont(name: "Montserrat-SemiBold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
        }
        
        public static func body(size: CGFloat = 14) -> NSFont {
            NSFont(name: "Montserrat-Regular", size: size) ?? NSFont.systemFont(ofSize: size)
        }
        
        public static func mono(size: CGFloat = 12) -> NSFont {
            NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
```

---

### Task 2.3: Settings Manager

**Files:**
- Create: `Superwhisperfree/Sources/Services/SettingsManager.swift`

**Step 1: Create SettingsManager.swift**

```swift
import Foundation

struct AppSettings: Codable {
    var modelType: String
    var modelSize: String
    var hotkey: HotkeyConfig
    var startOnLogin: Bool
    var uiTheme: String
    
    struct HotkeyConfig: Codable {
        var modifiers: [String]
        var key: String
    }
    
    static var `default`: AppSettings {
        AppSettings(
            modelType: "parakeet",
            modelSize: "base",
            hotkey: HotkeyConfig(modifiers: ["cmd"], key: "rightAlt"),
            startOnLogin: false,
            uiTheme: "dark"
        )
    }
}

class SettingsManager {
    static let shared = SettingsManager()
    
    private let fileManager = FileManager.default
    private var settingsURL: URL {
        appSupportURL.appendingPathComponent("settings.json")
    }
    
    var appSupportURL: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superwhisperfree")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private(set) var settings: AppSettings
    
    private init() {
        settings = SettingsManager.load() ?? .default
    }
    
    private static func load() -> AppSettings? {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superwhisperfree/settings.json")
        
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
    
    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL)
    }
    
    func reload() {
        settings = SettingsManager.load() ?? .default
    }
}
```

---

### Task 2.4: Menu Bar Controller

**Files:**
- Create: `Superwhisperfree/Sources/App/MenuBarController.swift`

**Step 1: Create MenuBarController.swift**

```swift
import Cocoa

class MenuBarController {
    private var statusItem: NSStatusItem
    private var dashboardController: DashboardWindowController?
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Superwhisperfree")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        
        let startOnLoginItem = NSMenuItem(title: "Start on Login", action: #selector(toggleStartOnLogin), keyEquivalent: "")
        startOnLoginItem.state = SettingsManager.shared.settings.startOnLogin ? .on : .off
        menu.addItem(startOnLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Welcome Again", action: #selector(showWelcome), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        for item in menu.items {
            item.target = self
        }
        
        statusItem.menu = menu
    }
    
    @objc private func openDashboard() {
        if dashboardController == nil {
            dashboardController = DashboardWindowController()
        }
        dashboardController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func toggleStartOnLogin(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        SettingsManager.shared.settings.startOnLogin = sender.state == .on
        SettingsManager.shared.save()
    }
    
    @objc private func showWelcome() {
        UserDefaults.standard.set(false, forKey: "onboardingComplete")
        let onboarding = OnboardingWindowController()
        onboarding.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

---

# Workstream 3: Swift Recording + Hotkey + Overlay

### Task 3.1: Audio Recorder

**Files:**
- Create: `Superwhisperfree/Sources/Services/AudioRecorder.swift`

**Step 1: Create AudioRecorder.swift**

```swift
import AVFoundation

class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioLevelTimer: Timer?
    
    var onAudioLevel: ((Float) -> Void)?
    var recordingURL: URL?
    
    func startRecording() throws -> URL {
        let url = SettingsManager.shared.appSupportURL
            .appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        
        recordingURL = url
        startMetering()
        
        return url
    }
    
    func stopRecording() -> URL? {
        stopMetering()
        audioRecorder?.stop()
        return recordingURL
    }
    
    private func startMetering() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.audioRecorder?.updateMeters()
            let level = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160
            let normalizedLevel = max(0, (level + 60) / 60)
            self?.onAudioLevel?(normalizedLevel)
        }
    }
    
    private func stopMetering() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    func cleanup() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

---

### Task 3.2: Global Hotkey Manager

**Files:**
- Create: `Superwhisperfree/Sources/Services/HotkeyManager.swift`

**Step 1: Create HotkeyManager.swift**

```swift
import Cocoa
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?
    
    private var eventMonitor: Any?
    private var flagsMonitor: Any?
    private var isKeyDown = false
    
    private init() {}
    
    func start() {
        guard AXIsProcessTrusted() else {
            requestAccessibilityPermission()
            return
        }
        
        setupMonitors()
    }
    
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }
    
    private func setupMonitors() {
        let settings = SettingsManager.shared.settings.hotkey
        
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let settings = SettingsManager.shared.settings.hotkey
        
        if settings.key == "rightAlt" || settings.key == "Option" {
            let rightOptionDown = event.modifierFlags.contains(.option) && 
                                  event.keyCode == 61
            
            if rightOptionDown && !isKeyDown {
                isKeyDown = true
                onHotkeyDown?()
            } else if !event.modifierFlags.contains(.option) && isKeyDown {
                isKeyDown = false
                onHotkeyUp?()
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let settings = SettingsManager.shared.settings.hotkey
        
        guard settings.key != "rightAlt" && settings.key != "Option" else { return }
        
        let requiredModifiers = modifiersFromStrings(settings.modifiers)
        let hasRequiredModifiers = event.modifierFlags.contains(requiredModifiers)
        
        if event.type == .keyDown && hasRequiredModifiers && !isKeyDown {
            if keyMatches(event, settings.key) {
                isKeyDown = true
                onHotkeyDown?()
            }
        } else if event.type == .keyUp && isKeyDown {
            if keyMatches(event, settings.key) {
                isKeyDown = false
                onHotkeyUp?()
            }
        }
    }
    
    private func modifiersFromStrings(_ strings: [String]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for str in strings {
            switch str.lowercased() {
            case "cmd", "command": flags.insert(.command)
            case "ctrl", "control": flags.insert(.control)
            case "alt", "option": flags.insert(.option)
            case "shift": flags.insert(.shift)
            default: break
            }
        }
        return flags
    }
    
    private func keyMatches(_ event: NSEvent, _ key: String) -> Bool {
        event.charactersIgnoringModifiers?.lowercased() == key.lowercased()
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
}
```

---

### Task 3.3: Recording Overlay Window

**Files:**
- Create: `Superwhisperfree/Sources/Windows/RecordingOverlay.swift`
- Create: `Superwhisperfree/Sources/Views/Components/WaveformView.swift`

**Step 1: Create WaveformView.swift**

```swift
import Cocoa

class WaveformView: NSView {
    private var barLayers: [CALayer] = []
    private let barCount = 5
    private var levels: [CGFloat] = []
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        levels = Array(repeating: 0.1, count: barCount)
        
        for i in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = DesignTokens.Colors.text.cgColor
            bar.cornerRadius = 2
            barLayers.append(bar)
            layer?.addSublayer(bar)
        }
    }
    
    override func layout() {
        super.layout()
        updateBarPositions()
    }
    
    private func updateBarPositions() {
        let barWidth: CGFloat = 4
        let spacing: CGFloat = 6
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2
        
        for (i, bar) in barLayers.enumerated() {
            let height = max(8, bounds.height * levels[i])
            let x = startX + CGFloat(i) * (barWidth + spacing)
            let y = (bounds.height - height) / 2
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.05)
            bar.frame = CGRect(x: x, y: y, width: barWidth, height: height)
            CATransaction.commit()
        }
    }
    
    func updateLevel(_ level: Float) {
        levels.removeFirst()
        levels.append(CGFloat(level) * 0.8 + 0.2)
        updateBarPositions()
    }
    
    func reset() {
        levels = Array(repeating: 0.1, count: barCount)
        updateBarPositions()
    }
}
```

**Step 2: Create RecordingOverlay.swift**

```swift
import Cocoa

class RecordingOverlay: NSPanel {
    enum State {
        case recording
        case transcribing
        case success
        case error(String)
    }
    
    private let waveformView = WaveformView()
    private let statusLabel = NSTextField(labelWithString: "Recording...")
    private let spinner = NSProgressIndicator()
    
    var state: State = .recording {
        didSet { updateState() }
    }
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setup()
    }
    
    private func setup() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        let contentView = NSVisualEffectView()
        contentView.material = .hudWindow
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = DesignTokens.CornerRadius.large
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = DesignTokens.Colors.surface.withAlphaComponent(0.95).cgColor
        self.contentView = contentView
        
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(waveformView)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = DesignTokens.Typography.body(size: 13)
        statusLabel.textColor = DesignTokens.Colors.text
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isHidden = true
        contentView.addSubview(spinner)
        
        NSLayoutConstraint.activate([
            waveformView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            waveformView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            waveformView.widthAnchor.constraint(equalToConstant: 80),
            waveformView.heightAnchor.constraint(equalToConstant: 30),
            
            statusLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: waveformView.centerYAnchor)
        ])
    }
    
    func showNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        var x = mouseLocation.x - frame.width / 2
        var y = mouseLocation.y + 20
        
        x = max(10, min(x, screenFrame.maxX - frame.width - 10))
        y = max(10, min(y, screenFrame.maxY - frame.height - 10))
        
        setFrameOrigin(NSPoint(x: x, y: y))
        
        alphaValue = 0
        orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1
        }
    }
    
    func hide(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            completion?()
        })
    }
    
    func updateAudioLevel(_ level: Float) {
        waveformView.updateLevel(level)
    }
    
    private func updateState() {
        switch state {
        case .recording:
            waveformView.isHidden = false
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            statusLabel.stringValue = "Recording..."
            statusLabel.textColor = DesignTokens.Colors.text
            
        case .transcribing:
            waveformView.isHidden = true
            waveformView.reset()
            spinner.isHidden = false
            spinner.startAnimation(nil)
            statusLabel.stringValue = "Transcribing..."
            statusLabel.textColor = DesignTokens.Colors.text
            
        case .success:
            waveformView.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            statusLabel.stringValue = "✓"
            statusLabel.textColor = DesignTokens.Colors.success
            
        case .error(let message):
            waveformView.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            statusLabel.stringValue = message
            statusLabel.textColor = DesignTokens.Colors.error
        }
    }
}
```

---

### Task 3.4: Transcription Client

**Files:**
- Create: `Superwhisperfree/Sources/Services/TranscriptionClient.swift`

**Step 1: Create TranscriptionClient.swift**

```swift
import Foundation

class TranscriptionClient {
    static let shared = TranscriptionClient()
    
    private var helperProcess: Process?
    private let socketPath: String
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superwhisperfree")
        socketPath = appSupport.appendingPathComponent("transcribe.sock").path
    }
    
    func ensureHelperRunning() {
        guard !isHelperRunning() else { return }
        startHelper()
    }
    
    private func isHelperRunning() -> Bool {
        FileManager.default.fileExists(atPath: socketPath)
    }
    
    private func startHelper() {
        let pythonPath = "/usr/bin/python3"
        
        guard let helperScript = Bundle.main.path(forResource: "transcribe_helper", ofType: "py") 
              ?? findHelperScript() else {
            print("Could not find transcribe_helper.py")
            return
        }
        
        helperProcess = Process()
        helperProcess?.executableURL = URL(fileURLWithPath: pythonPath)
        helperProcess?.arguments = [helperScript]
        helperProcess?.standardOutput = FileHandle.nullDevice
        helperProcess?.standardError = FileHandle.nullDevice
        
        try? helperProcess?.run()
        
        Thread.sleep(forTimeInterval: 2.0)
    }
    
    private func findHelperScript() -> String? {
        let possiblePaths = [
            "../python/transcribe_helper.py",
            "python/transcribe_helper.py",
            NSHomeDirectory() + "/Desktop/ /Applications/superwhisperfreev2/python/transcribe_helper.py"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    func transcribe(audioPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        ensureHelperRunning()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.sendRequest("TRANSCRIBE:\(audioPath)")
                
                if result.hasPrefix("TEXT:") {
                    let text = String(result.dropFirst(5))
                    DispatchQueue.main.async {
                        completion(.success(text))
                    }
                } else if result.hasPrefix("ERROR:") {
                    let error = String(result.dropFirst(6))
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "Transcription", code: 1, 
                                                   userInfo: [NSLocalizedDescriptionKey: error])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func sendRequest(_ message: String) throws -> String {
        let socket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw NSError(domain: "Socket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }
        
        defer { close(socket) }
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            socketPath.withCString { cstr in
                _ = strcpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cstr)
            }
        }
        
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard connectResult >= 0 else {
            throw NSError(domain: "Socket", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to connect"])
        }
        
        _ = message.withCString { cstr in
            write(socket, cstr, strlen(cstr))
        }
        
        var buffer = [CChar](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, buffer.count - 1)
        
        guard bytesRead > 0 else {
            throw NSError(domain: "Socket", code: 3, userInfo: [NSLocalizedDescriptionKey: "No response"])
        }
        
        return String(cString: buffer)
    }
    
    func stopHelper() {
        _ = try? sendRequest("QUIT")
        helperProcess?.terminate()
        helperProcess = nil
    }
}
```

---

### Task 3.5: Paste Service and Recording Coordinator

**Files:**
- Create: `Superwhisperfree/Sources/Services/PasteService.swift`
- Create: `Superwhisperfree/Sources/Services/RecordingCoordinator.swift`

**Step 1: Create PasteService.swift**

```swift
import Cocoa
import Carbon

class PasteService {
    static let shared = PasteService()
    
    private init() {}
    
    func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        simulatePaste()
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
```

**Step 2: Create RecordingCoordinator.swift**

```swift
import Cocoa

class RecordingCoordinator {
    static let shared = RecordingCoordinator()
    
    private let recorder = AudioRecorder()
    private let overlay = RecordingOverlay()
    private var isRecording = false
    
    private init() {
        setupRecorder()
        setupHotkey()
    }
    
    private func setupRecorder() {
        recorder.onAudioLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.overlay.updateAudioLevel(level)
            }
        }
    }
    
    private func setupHotkey() {
        HotkeyManager.shared.onHotkeyDown = { [weak self] in
            self?.startRecording()
        }
        
        HotkeyManager.shared.onHotkeyUp = { [weak self] in
            self?.stopRecording()
        }
    }
    
    func start() {
        HotkeyManager.shared.start()
    }
    
    func stop() {
        HotkeyManager.shared.stop()
        if isRecording {
            cancelRecording()
        }
    }
    
    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        
        overlay.state = .recording
        overlay.showNearCursor()
        
        do {
            _ = try recorder.startRecording()
        } catch {
            overlay.state = .error("Mic error")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.overlay.hide()
            }
            isRecording = false
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        
        guard let audioURL = recorder.stopRecording() else {
            overlay.hide()
            return
        }
        
        overlay.state = .transcribing
        
        TranscriptionClient.shared.transcribe(audioPath: audioURL.path) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let text):
                self.overlay.state = .success
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.overlay.hide {
                        PasteService.shared.pasteText(text)
                        self.updateAnalytics(text: text)
                    }
                }
                
            case .failure(let error):
                self.overlay.state = .error(error.localizedDescription)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.overlay.hide()
                }
            }
            
            self.recorder.cleanup()
        }
    }
    
    private func cancelRecording() {
        _ = recorder.stopRecording()
        recorder.cleanup()
        overlay.hide()
        isRecording = false
    }
    
    private func updateAnalytics(text: String) {
        let wordCount = text.split(separator: " ").count
        AnalyticsManager.shared.addDictation(words: wordCount, durationSeconds: 0)
    }
}
```

---

# Workstream 4: Swift Onboarding Flow

### Task 4.1: Onboarding Window Controller

**Files:**
- Create: `Superwhisperfree/Sources/Windows/OnboardingWindow.swift`

**Step 1: Create OnboardingWindow.swift**

```swift
import Cocoa

class OnboardingWindowController: NSWindowController {
    enum Step: Int, CaseIterable {
        case welcome
        case feature1
        case feature2
        case feature3
        case feature4
        case setup
        case testRecording
        case done
    }
    
    private var currentStep: Step = .welcome
    private var contentView: NSView!
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Superwhisperfree"
        window.center()
        window.backgroundColor = DesignTokens.Colors.background
        
        self.init(window: window)
        setupContentView()
        showStep(.welcome)
    }
    
    private func setupContentView() {
        contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = DesignTokens.Colors.background.cgColor
        window?.contentView = contentView
    }
    
    func showStep(_ step: Step) {
        currentStep = step
        
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        switch step {
        case .welcome:
            showWelcome()
        case .feature1, .feature2, .feature3, .feature4:
            showFeature(step)
        case .setup:
            showSetup()
        case .testRecording:
            showTestRecording()
        case .done:
            finishOnboarding()
        }
    }
    
    private func showWelcome() {
        let titleLabel = NSTextField(labelWithString: "Superwhisperfree")
        titleLabel.font = DesignTokens.Typography.heading(size: 32)
        titleLabel.textColor = DesignTokens.Colors.text
        titleLabel.alignment = .center
        
        let subtitleLabel = NSTextField(labelWithString: "Local offline dictation.\nHold a key to record.")
        subtitleLabel.font = DesignTokens.Typography.body(size: 16)
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        
        let button = NSButton(title: "Get Started", target: self, action: #selector(nextStep))
        styleButton(button)
        
        let stack = NSStackView(views: [titleLabel, subtitleLabel, button])
        stack.orientation = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .centerX
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    private func showFeature(_ step: Step) {
        let features: [(String, String, String)] = [
            ("waveform", "Hold to Record", "Press and hold your hotkey to start recording your voice."),
            ("text.bubble", "Instant Transcription", "Your speech is transcribed locally using AI - no internet needed."),
            ("doc.on.clipboard", "Paste Anywhere", "Text automatically pastes where your cursor is."),
            ("chart.line.uptrend.xyaxis", "Track Productivity", "See how much time you save compared to typing.")
        ]
        
        let index = step.rawValue - 1
        let (icon, title, description) = features[index]
        
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        imageView.contentTintColor = DesignTokens.Colors.text
        imageView.symbolConfiguration = .init(pointSize: 48, weight: .light)
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = DesignTokens.Colors.text
        titleLabel.alignment = .center
        
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = DesignTokens.Typography.body(size: 14)
        descLabel.textColor = DesignTokens.Colors.textSecondary
        descLabel.alignment = .center
        
        let button = NSButton(title: "Continue", target: self, action: #selector(nextStep))
        styleButton(button)
        
        let dotsView = createDotsIndicator(current: index, total: 4)
        
        let stack = NSStackView(views: [imageView, titleLabel, descLabel, dotsView, button])
        stack.orientation = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .centerX
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 64),
            imageView.heightAnchor.constraint(equalToConstant: 64)
        ])
    }
    
    private func showSetup() {
        let setupView = SetupView()
        setupView.onComplete = { [weak self] in
            self?.showStep(.testRecording)
        }
        
        setupView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(setupView)
        
        NSLayoutConstraint.activate([
            setupView.topAnchor.constraint(equalTo: contentView.topAnchor),
            setupView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            setupView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            setupView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    private func showTestRecording() {
        let testView = TestRecordingView()
        testView.onComplete = { [weak self] in
            self?.showStep(.done)
        }
        
        testView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(testView)
        
        NSLayoutConstraint.activate([
            testView.topAnchor.constraint(equalTo: contentView.topAnchor),
            testView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            testView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            testView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        RecordingCoordinator.shared.start()
        window?.close()
    }
    
    @objc private func nextStep() {
        let nextIndex = currentStep.rawValue + 1
        if let next = Step(rawValue: nextIndex) {
            showStep(next)
        }
    }
    
    private func styleButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.font = DesignTokens.Typography.body(size: 14)
    }
    
    private func createDotsIndicator(current: Int, total: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        
        for i in 0..<total {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = (i == current ? DesignTokens.Colors.text : DesignTokens.Colors.textSecondary).cgColor
            
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8)
            ])
            
            stack.addArrangedSubview(dot)
        }
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return container
    }
}
```

---

### Task 4.2: Setup View (Permissions)

**Files:**
- Create: `Superwhisperfree/Sources/Views/Onboarding/SetupView.swift`

**Step 1: Create SetupView.swift**

```swift
import Cocoa

class SetupView: NSView {
    var onComplete: (() -> Void)?
    
    private var accessibilityStatus: NSTextField!
    private var modelStatus: NSTextField!
    private var hotkeyStatus: NSTextField!
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = DesignTokens.Colors.background.cgColor
        
        let titleLabel = NSTextField(labelWithString: "Setup")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = DesignTokens.Colors.text
        
        let descLabel = NSTextField(labelWithString: "Grant permissions and download the transcription model.")
        descLabel.font = DesignTokens.Typography.body(size: 14)
        descLabel.textColor = DesignTokens.Colors.textSecondary
        
        let accessibilityButton = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openAccessibility))
        accessibilityStatus = NSTextField(labelWithString: "⏳ Not granted")
        accessibilityStatus.font = DesignTokens.Typography.body(size: 12)
        accessibilityStatus.textColor = DesignTokens.Colors.textSecondary
        
        let preferencesButton = NSButton(title: "Open Preferences", target: self, action: #selector(openPreferences))
        modelStatus = NSTextField(labelWithString: "⏳ Model not downloaded")
        modelStatus.font = DesignTokens.Typography.body(size: 12)
        modelStatus.textColor = DesignTokens.Colors.textSecondary
        
        hotkeyStatus = NSTextField(labelWithString: "⏳ Hotkey not set")
        hotkeyStatus.font = DesignTokens.Typography.body(size: 12)
        hotkeyStatus.textColor = DesignTokens.Colors.textSecondary
        
        let doneButton = NSButton(title: "I'm Done", target: self, action: #selector(done))
        
        let stack = NSStackView(views: [
            titleLabel,
            descLabel,
            NSView(),
            accessibilityButton,
            accessibilityStatus,
            NSView(),
            preferencesButton,
            modelStatus,
            hotkeyStatus,
            NSView(),
            doneButton
        ])
        stack.orientation = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .leading
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl)
        ])
        
        updateStatuses()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatuses()
        }
    }
    
    private func updateStatuses() {
        if HotkeyManager.shared.hasAccessibilityPermission {
            accessibilityStatus.stringValue = "✓ Accessibility granted"
            accessibilityStatus.textColor = DesignTokens.Colors.success
        }
        
        let settings = SettingsManager.shared.settings
        if !settings.hotkey.key.isEmpty {
            hotkeyStatus.stringValue = "✓ Hotkey configured"
            hotkeyStatus.textColor = DesignTokens.Colors.success
        }
    }
    
    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    @objc private func openPreferences() {
        let pythonPath = "/usr/bin/python3"
        let scriptPath = NSHomeDirectory() + "/Desktop/ /Applications/superwhisperfreev2/python/setup_ui.py"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]
        try? process.run()
    }
    
    @objc private func done() {
        onComplete?()
    }
}
```

---

### Task 4.3: Test Recording View

**Files:**
- Create: `Superwhisperfree/Sources/Views/Onboarding/TestRecordingView.swift`

**Step 1: Create TestRecordingView.swift**

```swift
import Cocoa

class TestRecordingView: NSView {
    var onComplete: (() -> Void)?
    
    private let waveformView = WaveformView()
    private let statusLabel = NSTextField(labelWithString: "Hold your hotkey to try recording")
    private let resultLabel = NSTextField(wrappingLabelWithString: "")
    private let recorder = AudioRecorder()
    private var isRecording = false
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = DesignTokens.Colors.background.cgColor
        
        let titleLabel = NSTextField(labelWithString: "Try It Out!")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = DesignTokens.Colors.text
        
        statusLabel.font = DesignTokens.Typography.body(size: 14)
        statusLabel.textColor = DesignTokens.Colors.textSecondary
        statusLabel.alignment = .center
        
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        
        resultLabel.font = DesignTokens.Typography.body(size: 14)
        resultLabel.textColor = DesignTokens.Colors.text
        resultLabel.alignment = .center
        resultLabel.isHidden = true
        
        let skipButton = NSButton(title: "Skip", target: self, action: #selector(skip))
        let continueButton = NSButton(title: "Continue", target: self, action: #selector(done))
        continueButton.isHidden = true
        
        let buttonStack = NSStackView(views: [skipButton, continueButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = DesignTokens.Spacing.md
        
        let stack = NSStackView(views: [titleLabel, statusLabel, waveformView, resultLabel, buttonStack])
        stack.orientation = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .centerX
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 120),
            waveformView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        setupHotkey()
        
        recorder.onAudioLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.waveformView.updateLevel(level)
            }
        }
    }
    
    private func setupHotkey() {
        HotkeyManager.shared.onHotkeyDown = { [weak self] in
            self?.startRecording()
        }
        
        HotkeyManager.shared.onHotkeyUp = { [weak self] in
            self?.stopRecording()
        }
        
        HotkeyManager.shared.start()
    }
    
    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        
        statusLabel.stringValue = "Recording..."
        
        do {
            _ = try recorder.startRecording()
        } catch {
            statusLabel.stringValue = "Microphone error"
            isRecording = false
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        
        guard let audioURL = recorder.stopRecording() else { return }
        
        statusLabel.stringValue = "Transcribing..."
        
        TranscriptionClient.shared.transcribe(audioPath: audioURL.path) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let text):
                self.statusLabel.stringValue = "Success!"
                self.resultLabel.stringValue = "\"\(text)\""
                self.resultLabel.isHidden = false
                
                if let continueBtn = self.subviews.first?.subviews.compactMap({ $0 as? NSStackView }).last?.arrangedSubviews.last as? NSButton {
                    continueBtn.isHidden = false
                }
                
            case .failure(let error):
                self.statusLabel.stringValue = "Error: \(error.localizedDescription)"
            }
            
            self.recorder.cleanup()
        }
    }
    
    @objc private func skip() {
        HotkeyManager.shared.stop()
        onComplete?()
    }
    
    @objc private func done() {
        HotkeyManager.shared.stop()
        onComplete?()
    }
}
```

---

### Task 4.4-4.5: Additional Onboarding Polish

(These tasks involve animations and transitions - implement after core functionality works)

---

# Workstream 5: Swift Dashboard + Analytics

### Task 5.1: Analytics Manager

**Files:**
- Create: `Superwhisperfree/Sources/Services/AnalyticsManager.swift`

**Step 1: Create AnalyticsManager.swift**

```swift
import Foundation

struct DailyStat: Codable {
    let date: String
    var words: Int
    var recordings: Int
    var totalDurationSec: Double
}

struct Analytics: Codable {
    var typingWPM: Int?
    var dailyStats: [DailyStat]
    
    static var empty: Analytics {
        Analytics(typingWPM: nil, dailyStats: [])
    }
}

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private var analytics: Analytics
    private let fileURL: URL
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superwhisperfree")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        fileURL = appSupport.appendingPathComponent("analytics.json")
        analytics = AnalyticsManager.load(from: fileURL) ?? .empty
    }
    
    private static func load(from url: URL) -> Analytics? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Analytics.self, from: data)
    }
    
    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(analytics) else { return }
        try? data.write(to: fileURL)
    }
    
    func addDictation(words: Int, durationSeconds: Double) {
        let today = dateFormatter.string(from: Date())
        
        if let index = analytics.dailyStats.firstIndex(where: { $0.date == today }) {
            analytics.dailyStats[index].words += words
            analytics.dailyStats[index].recordings += 1
            analytics.dailyStats[index].totalDurationSec += durationSeconds
        } else {
            let stat = DailyStat(date: today, words: words, recordings: 1, totalDurationSec: durationSeconds)
            analytics.dailyStats.append(stat)
        }
        
        save()
    }
    
    func setTypingWPM(_ wpm: Int) {
        analytics.typingWPM = wpm
        save()
    }
    
    var typingWPM: Int? {
        analytics.typingWPM
    }
    
    var totalWords: Int {
        analytics.dailyStats.reduce(0) { $0 + $1.words }
    }
    
    var totalRecordings: Int {
        analytics.dailyStats.reduce(0) { $0 + $1.recordings }
    }
    
    var speakingWPM: Int {
        let totalDuration = analytics.dailyStats.reduce(0.0) { $0 + $1.totalDurationSec }
        guard totalDuration > 0 else { return 150 }
        return Int(Double(totalWords) / (totalDuration / 60))
    }
    
    func minutesSaved(benchmarkWPM: Int = 45) -> Double {
        let typingTime = Double(totalWords) / Double(benchmarkWPM)
        let speakingTime = Double(totalWords) / Double(speakingWPM)
        return max(0, typingTime - speakingTime)
    }
    
    func recentStats(days: Int = 30) -> [DailyStat] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let cutoffString = dateFormatter.string(from: cutoff)
        
        return analytics.dailyStats.filter { $0.date >= cutoffString }.sorted { $0.date < $1.date }
    }
}
```

---

### Task 5.2: Dashboard Window Controller

**Files:**
- Create: `Superwhisperfree/Sources/Windows/DashboardWindow.swift`

**Step 1: Create DashboardWindow.swift**

```swift
import Cocoa

class DashboardWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Superwhisperfree"
        window.center()
        window.backgroundColor = DesignTokens.Colors.background
        
        self.init(window: window)
        
        let dashboardView = DashboardView()
        dashboardView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = dashboardView
    }
}
```

---

### Task 5.3: Dashboard View

**Files:**
- Create: `Superwhisperfree/Sources/Views/Dashboard/DashboardView.swift`

**Step 1: Create DashboardView.swift**

```swift
import Cocoa

class DashboardView: NSView {
    private var minutesSavedLabel: NSTextField!
    private var wordsLabel: NSTextField!
    private var typingWPMLabel: NSTextField!
    private var speakingWPMLabel: NSTextField!
    private var chartView: LineChartView!
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = DesignTokens.Colors.background.cgColor
        
        let titleLabel = NSTextField(labelWithString: "Dashboard")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = DesignTokens.Colors.text
        
        let minutesSaved = AnalyticsManager.shared.minutesSaved()
        minutesSavedLabel = createStatLabel(value: String(format: "%.1f", minutesSaved), unit: "minutes saved")
        
        let totalWords = AnalyticsManager.shared.totalWords
        wordsLabel = createStatLabel(value: "\(totalWords)", unit: "words dictated")
        
        let typingWPM = AnalyticsManager.shared.typingWPM ?? 0
        typingWPMLabel = createStatLabel(value: typingWPM > 0 ? "\(typingWPM)" : "—", unit: "typing WPM")
        
        let speakingWPM = AnalyticsManager.shared.speakingWPM
        speakingWPMLabel = createStatLabel(value: "\(speakingWPM)", unit: "speaking WPM")
        
        let statsGrid = NSStackView(views: [minutesSavedLabel, wordsLabel, typingWPMLabel, speakingWPMLabel])
        statsGrid.orientation = .horizontal
        statsGrid.distribution = .fillEqually
        statsGrid.spacing = DesignTokens.Spacing.md
        
        let wpmTestButton = NSButton(title: "Take Typing Test", target: self, action: #selector(startTypingTest))
        
        chartView = LineChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        updateChart()
        
        let preferencesButton = NSButton(title: "Preferences...", target: self, action: #selector(openPreferences))
        
        let stack = NSStackView(views: [titleLabel, statsGrid, wpmTestButton, chartView, preferencesButton])
        stack.orientation = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .leading
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            statsGrid.widthAnchor.constraint(equalTo: stack.widthAnchor),
            chartView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            chartView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func createStatLabel(value: String, unit: String) -> NSTextField {
        let container = NSTextField(labelWithString: "\(value)\n\(unit)")
        container.font = DesignTokens.Typography.body(size: 12)
        container.textColor = DesignTokens.Colors.text
        container.alignment = .center
        container.maximumNumberOfLines = 2
        return container
    }
    
    private func updateChart() {
        let stats = AnalyticsManager.shared.recentStats(days: 30)
        let dataPoints = stats.map { Double($0.words) }
        chartView.dataPoints = dataPoints
    }
    
    @objc private func startTypingTest() {
        let testWindow = TypingTestWindowController()
        testWindow.onComplete = { [weak self] wpm in
            AnalyticsManager.shared.setTypingWPM(wpm)
            self?.refreshStats()
        }
        testWindow.showWindow(nil)
    }
    
    @objc private func openPreferences() {
        let pythonPath = "/usr/bin/python3"
        let scriptPath = NSHomeDirectory() + "/Desktop/ /Applications/superwhisperfreev2/python/setup_ui.py"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]
        try? process.run()
    }
    
    private func refreshStats() {
        let minutesSaved = AnalyticsManager.shared.minutesSaved()
        let typingWPM = AnalyticsManager.shared.typingWPM ?? 0
        
        minutesSavedLabel.stringValue = String(format: "%.1f\nminutes saved", minutesSaved)
        typingWPMLabel.stringValue = "\(typingWPM)\ntyping WPM"
    }
}
```

---

### Task 5.4: Line Chart View

**Files:**
- Create: `Superwhisperfree/Sources/Views/Components/LineChartView.swift`

**Step 1: Create LineChartView.swift**

```swift
import Cocoa

class LineChartView: NSView {
    var dataPoints: [Double] = [] {
        didSet { needsDisplay = true }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        DesignTokens.Colors.surface.setFill()
        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        backgroundPath.fill()
        
        guard dataPoints.count > 1 else {
            drawEmptyState()
            return
        }
        
        let padding: CGFloat = 20
        let graphRect = bounds.insetBy(dx: padding, dy: padding)
        
        let maxValue = dataPoints.max() ?? 1
        let minValue: Double = 0
        let range = maxValue - minValue
        
        let path = NSBezierPath()
        
        for (index, value) in dataPoints.enumerated() {
            let x = graphRect.minX + (graphRect.width * CGFloat(index) / CGFloat(dataPoints.count - 1))
            let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
            let y = graphRect.minY + (graphRect.height * CGFloat(normalizedValue))
            
            if index == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        
        DesignTokens.Colors.text.setStroke()
        path.lineWidth = 2
        path.stroke()
        
        for (index, value) in dataPoints.enumerated() {
            let x = graphRect.minX + (graphRect.width * CGFloat(index) / CGFloat(dataPoints.count - 1))
            let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
            let y = graphRect.minY + (graphRect.height * CGFloat(normalizedValue))
            
            let dotRect = NSRect(x: x - 3, y: y - 3, width: 6, height: 6)
            let dot = NSBezierPath(ovalIn: dotRect)
            DesignTokens.Colors.text.setFill()
            dot.fill()
        }
    }
    
    private func drawEmptyState() {
        let text = "No data yet"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.Typography.body(size: 14),
            .foregroundColor: DesignTokens.Colors.textSecondary
        ]
        
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attributes)
    }
}
```

---

### Task 5.5: Typing Test Window

**Files:**
- Create: `Superwhisperfree/Sources/Views/Dashboard/TypingTestView.swift`

**Step 1: Create TypingTestView.swift**

```swift
import Cocoa

class TypingTestWindowController: NSWindowController, NSTextViewDelegate {
    var onComplete: ((Int) -> Void)?
    
    private var textView: NSTextView!
    private var timerLabel: NSTextField!
    private var startButton: NSButton!
    
    private var timer: Timer?
    private var timeRemaining = 60
    private var hasStarted = false
    
    private let sampleText = """
    The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. \
    How vexingly quick daft zebras jump. The five boxing wizards jump quickly. \
    Sphinx of black quartz, judge my vow. Two driven jocks help fax my big quiz.
    """
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typing Speed Test"
        window.center()
        window.backgroundColor = DesignTokens.Colors.background
        
        self.init(window: window)
        setupUI()
    }
    
    private func setupUI() {
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = DesignTokens.Colors.background.cgColor
        window?.contentView = contentView
        
        let titleLabel = NSTextField(labelWithString: "Type the text below as fast as you can")
        titleLabel.font = DesignTokens.Typography.heading(size: 18)
        titleLabel.textColor = DesignTokens.Colors.text
        
        let sampleLabel = NSTextField(wrappingLabelWithString: sampleText)
        sampleLabel.font = DesignTokens.Typography.body(size: 14)
        sampleLabel.textColor = DesignTokens.Colors.textSecondary
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        
        textView = NSTextView()
        textView.font = DesignTokens.Typography.body(size: 14)
        textView.textColor = DesignTokens.Colors.text
        textView.backgroundColor = DesignTokens.Colors.surface
        textView.delegate = self
        textView.isEditable = false
        
        scrollView.documentView = textView
        
        timerLabel = NSTextField(labelWithString: "60")
        timerLabel.font = DesignTokens.Typography.heading(size: 48)
        timerLabel.textColor = DesignTokens.Colors.text
        timerLabel.alignment = .center
        
        startButton = NSButton(title: "Start", target: self, action: #selector(startTest))
        
        let stack = NSStackView(views: [titleLabel, sampleLabel, scrollView, timerLabel, startButton])
        stack.orientation = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .centerX
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            scrollView.heightAnchor.constraint(equalToConstant: 100),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }
    
    @objc private func startTest() {
        hasStarted = true
        textView.isEditable = true
        textView.string = ""
        window?.makeFirstResponder(textView)
        
        startButton.isEnabled = false
        timeRemaining = 60
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        timeRemaining -= 1
        timerLabel.stringValue = "\(timeRemaining)"
        
        if timeRemaining <= 0 {
            endTest()
        }
    }
    
    private func endTest() {
        timer?.invalidate()
        timer = nil
        textView.isEditable = false
        
        let typedText = textView.string
        let wordCount = typedText.split(separator: " ").count
        let wpm = wordCount
        
        timerLabel.stringValue = "\(wpm) WPM"
        startButton.title = "Done"
        startButton.isEnabled = true
        startButton.action = #selector(finish)
        
        onComplete?(wpm)
    }
    
    @objc private func finish() {
        window?.close()
    }
}
```

---

# Workstream 6: Integration + Polish

### Task 6.1: Integrate All Components in AppDelegate

Update `AppDelegate.swift` to wire everything together.

### Task 6.2: Build Scripts

**Files:**
- Create: `scripts/dev-build.sh`
- Create: `scripts/build-release.sh`

### Task 6.3: Testing and Bug Fixes

### Task 6.4: Final Polish (animations, transitions, edge cases)

---

## Execution

**Plan complete and saved to `docs/plans/2026-02-19-superwhisperfree-implementation.md`.**

**Parallel Agent Dispatch Strategy:**

I will dispatch **4 parallel agents** for the independent workstreams:

| Agent | Workstream | Focus |
|-------|------------|-------|
| 1 | Python Transcription | Tasks 1.1-1.5 |
| 2 | Swift Core + Design System | Tasks 2.1-2.4 |
| 3 | Swift Recording + Hotkey + Overlay | Tasks 3.1-3.5 |
| 4 | Swift Onboarding | Tasks 4.1-4.3 |

After these complete, I'll dispatch agents for Dashboard (Workstream 5) and Integration (Workstream 6).

Ready to dispatch parallel agents?
