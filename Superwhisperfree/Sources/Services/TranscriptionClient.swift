import Foundation
import os.log

extension Notification.Name {
    static let modelLoadingStateDidChange = Notification.Name("modelLoadingStateDidChange")
    static let languageSettingsDidChange = Notification.Name("languageSettingsDidChange")
}

final class TranscriptionClient {
    static let shared = TranscriptionClient()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Superwhisperfree", category: "TranscriptionClient")
    
    private(set) var isModelLoaded = false
    private(set) var currentModelId: String?
    private var currentLanguage: String?
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .languageSettingsDidChange,
            object: nil
        )
    }
    
    @objc private func handleLanguageChange() {
        guard isModelLoaded || isLoading else { return }
        logger.info("Language settings changed, reloading model")
        stop()
        start()
    }
    
    private func resolveModelId(modelType: String, modelSize: String) -> String {
        let normalizedType = modelType.lowercased()
        if normalizedType == "parakeet" {
            return "parakeet"
        } else if normalizedType == "parakeet-v3" {
            return "parakeet-v3"
        } else {
            let validSizes = ["tiny", "base", "small", "medium", "large-v3", "turbo", "distil-small", "distil-medium", "distil-large-v3.5"]
            let normalizedSize = modelSize.lowercased()
            let size = validSizes.contains(normalizedSize) ? normalizedSize : "base"
            return "whisper-\(size)"
        }
    }
    
    private func resolveLanguage() -> String? {
        let settings = SettingsManager.shared.settings
        let modelType = settings.modelType.lowercased()
        guard modelType != "parakeet" && modelType != "parakeet-v3" else { return nil }
        return settings.languageMode == "english" ? "en" : settings.selectedLanguage
    }
    
    var isReady: Bool {
        return isModelLoaded && currentModelId != nil
    }
    
    private(set) var isLoading = false
    
    private func postLoadingStateNotification() {
        NotificationCenter.default.post(
            name: .modelLoadingStateDidChange,
            object: nil,
            userInfo: ["isLoading": isLoading, "isReady": isReady]
        )
    }
    
    func start() {
        let settings = SettingsManager.shared.settings
        let modelId = resolveModelId(modelType: settings.modelType, modelSize: settings.modelSize)
        let language = resolveLanguage()
        
        logger.info("Loading model: \(modelId) (type: \(settings.modelType), size: \(settings.modelSize), lang: \(language ?? "n/a"))")
        
        if let language = language, language != "en", modelId.hasPrefix("whisper-") {
            let multiModelId = "\(modelId)-multi"
            if !ModelDownloader.isModelDownloaded(multiModelId) {
                logger.info("Multilingual model not downloaded, downloading \(multiModelId)")
                isLoading = true
                postLoadingStateNotification()
                ModelDownloader.shared.download(modelId: multiModelId, progress: { progress, status in
                    self.logger.debug("Download progress: \(progress) - \(status)")
                }, completion: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        self.logger.info("Multilingual model downloaded, loading...")
                        self.loadModelAsync(modelId: modelId, language: language)
                    case .failure(let error):
                        self.logger.error("Failed to download multilingual model: \(error.localizedDescription)")
                        self.isLoading = false
                        self.isModelLoaded = false
                        self.postLoadingStateNotification()
                    }
                })
                return
            }
        }
        
        isLoading = true
        postLoadingStateNotification()
        loadModelAsync(modelId: modelId, language: language)
    }
    
    private func loadModelAsync(modelId: String, language: String?) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try TranscriptionService.shared.loadModel(modelId: modelId, language: language)
                DispatchQueue.main.async {
                    self.currentModelId = modelId
                    self.currentLanguage = language
                    self.isModelLoaded = true
                    self.isLoading = false
                    self.logger.info("Model loaded successfully: \(modelId) (lang: \(language ?? "n/a"))")
                    self.postLoadingStateNotification()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isModelLoaded = false
                    self.currentModelId = nil
                    self.currentLanguage = nil
                    self.isLoading = false
                    self.logger.error("Failed to load model '\(modelId)': \(error.localizedDescription)")
                    self.postLoadingStateNotification()
                }
            }
        }
    }
    
    func stop() {
        if let modelId = currentModelId {
            logger.info("Unloading model: \(modelId)")
        }
        TranscriptionService.shared.unloadModel()
        isModelLoaded = false
        currentModelId = nil
        currentLanguage = nil
    }
    
    func transcribe(audioPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard isReady else {
            let error = NSError(
                domain: "TranscriptionClient",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded. Call start() before transcribing."]
            )
            logger.error("Transcription attempted without loaded model")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let url = URL(fileURLWithPath: audioPath)
            self?.logger.debug("Starting transcription for: \(audioPath)")
            
            if let text = TranscriptionService.shared.transcribe(audioURL: url) {
                self?.logger.info("Transcription completed successfully")
                DispatchQueue.main.async {
                    completion(.success(text))
                }
            } else {
                self?.logger.error("Transcription failed for: \(audioPath)")
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "TranscriptionClient",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Transcription failed"]
                    )))
                }
            }
        }
    }
}
