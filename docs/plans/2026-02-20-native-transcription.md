# Native Transcription Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Python-based transcription with native sherpa-onnx for zero-install Whisper and Parakeet support.

**Architecture:** Build sherpa-onnx as a static library for macOS, create Swift wrapper, download ONNX model files via HTTP, transcribe audio natively.

**Tech Stack:** sherpa-onnx (C++), Swift, ONNX models, URLSession for downloads

---

## Task 1: Build sherpa-onnx for macOS

**Files:**
- Create: `vendor/sherpa-onnx/` (git submodule or source)
- Create: `scripts/build-sherpa-onnx.sh`

**Step 1: Clone sherpa-onnx**
```bash
cd /Users/yan/Desktop\ /Applications/superwhisperfreev2
mkdir -p vendor
cd vendor
git clone https://github.com/k2-fsa/sherpa-onnx.git
cd sherpa-onnx
```

**Step 2: Build for macOS with Swift support**
```bash
mkdir build-macos
cd build-macos
cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  ..
cmake --build . --config Release -j4
```

**Step 3: Verify build outputs**
Expected: `libsherpa-onnx-c-api.a` and headers in build directory

---

## Task 2: Create Swift C-API Wrapper

**Files:**
- Create: `Superwhisperfree/Sources/SherpaOnnx/SherpaOnnxBridge.h`
- Create: `Superwhisperfree/Sources/SherpaOnnx/SherpaOnnx.swift`

**Step 1: Create bridging header**
```c
// SherpaOnnxBridge.h
#ifndef SHERPA_ONNX_BRIDGE_H
#define SHERPA_ONNX_BRIDGE_H

#include "sherpa-onnx/c-api/c-api.h"

#endif
```

**Step 2: Create Swift wrapper class**
```swift
// SherpaOnnx.swift
import Foundation

final class SherpaOnnxTranscriber {
    private var recognizer: OpaquePointer?
    
    struct ModelConfig {
        let encoder: String
        let decoder: String
        let joiner: String
        let tokens: String
        let modelType: String  // "whisper" or "nemo_transducer"
    }
    
    init(config: ModelConfig) throws {
        // Initialize recognizer with config
    }
    
    func transcribe(audioPath: String) -> String? {
        // Transcribe audio file
    }
    
    deinit {
        // Cleanup
    }
}
```

---

## Task 3: Create Model Downloader Service

**Files:**
- Modify: `Superwhisperfree/Sources/Services/ModelDownloader.swift`

**Step 1: Update ModelDownloader for ONNX models**

Model URLs:
- Parakeet: `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2`
- Whisper base: `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-base.en.tar.bz2`

**Step 2: Implement download with progress**
- Use URLSession with delegate for progress
- Extract tar.bz2 after download
- Store in `~/Library/Application Support/Superwhisperfree/models/`

---

## Task 4: Update Model Selection View

**Files:**
- Modify: `Superwhisperfree/Sources/Views/Onboarding/ModelSelectionView.swift`

**Step 1: Update model list with ONNX models**
```swift
static let models: [ModelInfo] = [
    ModelInfo(id: "parakeet-v2", name: "Parakeet v2", size: "630 MB", speed: "Very Fast", ...),
    ModelInfo(id: "whisper-base", name: "Whisper Base", size: "150 MB", speed: "Fast", ...),
    ModelInfo(id: "whisper-small", name: "Whisper Small", size: "500 MB", speed: "Medium", ...),
]
```

**Step 2: Remove dependency check - just download models directly**

---

## Task 5: Update Transcription Client

**Files:**
- Modify: `Superwhisperfree/Sources/Services/TranscriptionClient.swift`

**Step 1: Replace Python socket client with SherpaOnnx**
- Load model on startup based on settings
- Transcribe using native API
- Return text result

---

## Task 6: Cleanup Python Files

**Files:**
- Delete: `python/` directory (no longer needed)
- Delete: `Superwhisperfree/Sources/Services/DependencyInstaller.swift`
- Modify: `Superwhisperfree/Sources/Services/PreferencesLauncher.swift` (remove Python references)

---

## Task 7: Update Build System

**Files:**
- Modify: `scripts/dev-build.sh`
- Create: `Superwhisperfree.xcodeproj` updates for linking sherpa-onnx

**Step 1: Link sherpa-onnx static library in build**

---

## Parallel Execution Strategy

These tasks can be parallelized:
- **Agent 1:** Tasks 1-2 (Build sherpa-onnx + Swift wrapper)
- **Agent 2:** Task 3 (Model downloader for ONNX)
- **Agent 3:** Tasks 4-5 (UI updates + transcription client)
- **Agent 4:** Tasks 6-7 (Cleanup + build system)

