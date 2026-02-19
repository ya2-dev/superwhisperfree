# Model Selection Screen + Path Fix

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a dedicated model selection screen to onboarding with download functionality, and fix Python script path resolution.

**Architecture:** New `ModelSelectionView` in Swift onboarding flow, subprocess calls to Python `model_downloader.py` for actual downloads.

---

## Parallel Workstreams

| # | Workstream | Description |
|---|------------|-------------|
| 1 | Fix Path Resolution | Update SetupView to use PreferencesLauncher |
| 2 | Model Selection View | Create new ModelSelectionView with download UI |
| 3 | Update Onboarding Flow | Add model selection step to OnboardingWindow |

---

## Workstream 1: Fix Path Resolution

### Task 1.1: Update SetupView to use PreferencesLauncher

**File:** `Superwhisperfree/Sources/Views/Onboarding/SetupView.swift`

Replace the `openPreferences()` method to use `PreferencesLauncher.openPreferences()` instead of hardcoded bundle path.

---

## Workstream 2: Model Selection View

### Task 2.1: Create ModelSelectionView

**File:** `Superwhisperfree/Sources/Views/Onboarding/ModelSelectionView.swift`

Create a new view with:
- Title "Choose Your Model"
- Subtitle explaining they can change later
- Model options as radio buttons:
  - Parakeet TDT 1.1B (2.5 GB, Fast, Recommended for English)
  - Whisper Tiny (75 MB, Very Fast, Quick notes)
  - Whisper Base (150 MB, Fast, Balanced)
  - Whisper Small (500 MB, Medium, Good accuracy)
  - Whisper Medium (1.5 GB, Slower, High accuracy)
- Each option shows: name, size badge, speed indicator, description
- "Download & Continue" button
- Progress bar (hidden until download starts)
- Status label for download progress
- `onComplete` callback

### Task 2.2: Create ModelDownloader Swift wrapper

**File:** `Superwhisperfree/Sources/Services/ModelDownloader.swift`

Create a service that:
- Finds and runs `python/model_downloader.py` via Process
- Parses stdout for progress updates (format: "PROGRESS:0.5:Downloading...")
- Provides async callback for progress
- Saves selected model to settings.json via SettingsManager

---

## Workstream 3: Update Onboarding Flow

### Task 3.1: Add modelSelection step to OnboardingWindow

**File:** `Superwhisperfree/Sources/Windows/OnboardingWindow.swift`

- Add `.modelSelection` to Step enum (after feature4, before setup)
- Add case in `showStep()` to display `ModelSelectionView`
- Wire up `onComplete` to advance to setup

---

## Model Info Reference

| Model | Type | Size | Speed | Description |
|-------|------|------|-------|-------------|
| Parakeet TDT 1.1B | parakeet | 2.5 GB | ⚡⚡⚡ Fast | Best for English, highest accuracy |
| Whisper Tiny | whisper/tiny | 75 MB | ⚡⚡⚡⚡ Very Fast | Quick notes, basic accuracy |
| Whisper Base | whisper/base | 150 MB | ⚡⚡⚡ Fast | Balanced speed and accuracy |
| Whisper Small | whisper/small | 500 MB | ⚡⚡ Medium | Good accuracy, moderate speed |
| Whisper Medium | whisper/medium | 1.5 GB | ⚡ Slower | High accuracy, slower processing |
