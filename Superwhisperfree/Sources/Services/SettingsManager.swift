import Cocoa

struct HotkeyConfig: Codable, Equatable {
    var modifiers: [String]
    var key: String
    
    static let defaultHotkey = HotkeyConfig(modifiers: ["rightAlt"], key: "")
}

struct AppSettings: Codable, Equatable {
    var modelType: String
    var modelSize: String
    var hotkey: HotkeyConfig
    var startOnLogin: Bool
    var uiTheme: String
    var languageMode: String
    var selectedLanguage: String
    
    static let `default` = AppSettings(
        modelType: "Parakeet",
        modelSize: "medium",
        hotkey: .defaultHotkey,
        startOnLogin: false,
        uiTheme: "dark",
        languageMode: "english",
        selectedLanguage: "en"
    )
}

final class SettingsManager {
    
    static let shared = SettingsManager()
    
    var settings: AppSettings = .default
    
    var appSupportURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Superwhisperfree", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        
        return appFolder
    }
    
    var settingsURL: URL {
        appSupportURL.appendingPathComponent("settings.json")
    }
    
    private init() {
        load()
    }
    
    func load() {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            settings = .default
            return
        }
        
        do {
            let data = try Data(contentsOf: settingsURL)
            let decoder = JSONDecoder()
            settings = try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            settings = .default
        }
    }
    
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    func reload() {
        load()
    }
    
    func reset() {
        settings = .default
        save()
    }
    
    var hotkeyConfig: InternalHotkeyConfig {
        let hotkey = settings.hotkey
        
        if hotkey.modifiers.contains("rightAlt") && hotkey.key.isEmpty {
            return InternalHotkeyConfig(keyCode: 0, modifiers: [], useRightAlt: true, useRightCmd: false, useFnKey: false)
        }
        
        if hotkey.modifiers.contains("rightCmd") && hotkey.key.isEmpty {
            return InternalHotkeyConfig(keyCode: 0, modifiers: [], useRightAlt: false, useRightCmd: true, useFnKey: false)
        }
        
        if hotkey.modifiers.contains("fn") && hotkey.key.isEmpty {
            return InternalHotkeyConfig(keyCode: 0, modifiers: [], useRightAlt: false, useRightCmd: false, useFnKey: true)
        }
        
        var modifierFlags: NSEvent.ModifierFlags = []
        for modifier in hotkey.modifiers {
            switch modifier.lowercased() {
            case "command", "cmd":
                modifierFlags.insert(.command)
            case "option", "alt":
                modifierFlags.insert(.option)
            case "control", "ctrl":
                modifierFlags.insert(.control)
            case "shift":
                modifierFlags.insert(.shift)
            default:
                break
            }
        }
        
        let keyCode = keyCodeForString(hotkey.key)
        
        return InternalHotkeyConfig(keyCode: keyCode, modifiers: modifierFlags, useRightAlt: false, useRightCmd: false, useFnKey: false)
    }
    
    private func keyCodeForString(_ key: String) -> UInt16 {
        let keyMap: [String: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, "space": 49
        ]
        return keyMap[key.lowercased()] ?? 0
    }
    
    private let wordCountKey = "totalWordCount"
    
    var totalWordCount: Int {
        get { UserDefaults.standard.integer(forKey: wordCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: wordCountKey) }
    }
    
    func incrementWordCount(by count: Int) {
        totalWordCount += count
    }
}

struct InternalHotkeyConfig {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var useRightAlt: Bool
    var useRightCmd: Bool
    var useFnKey: Bool
    
    static var defaultConfig: InternalHotkeyConfig {
        return InternalHotkeyConfig(keyCode: 0, modifiers: [], useRightAlt: true, useRightCmd: false, useFnKey: false)
    }
}
