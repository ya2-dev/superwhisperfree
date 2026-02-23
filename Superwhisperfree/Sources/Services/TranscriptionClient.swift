import Foundation
import os.log

extension Notification.Name {
    static let modelLoadingStateDidChange = Notification.Name("modelLoadingStateDidChange")
}

final class TranscriptionClient {
    static let shared = TranscriptionClient()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Superwhisperfree", category: "TranscriptionClient")
    
    private(set) var isModelLoaded = false
    private(set) var currentModelId: String?
    
    private init() {}
    
    /// Maps settings to the correct model ID for TranscriptionService
    private func resolveModelId(modelType: String, modelSize: String) -> String {
        let normalizedType = modelType.lowercased()
        
        if normalizedType == "parakeet" {
            return "parakeet-v2"
        } else {
            let validSizes = ["tiny", "base", "small", "medium"]
            let normalizedSize = modelSize.lowercased()
            let size = validSizes.contains(normalizedSize) ? normalizedSize : "base"
            return "whisper-\(size)"
        }
    }
    
    /// Check if a model is loaded and ready for transcription
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
        
        logger.info("Loading model: \(modelId) (type: \(settings.modelType), size: \(settings.modelSize))")
        
        isLoading = true
        postLoadingStateNotification()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try TranscriptionService.shared.loadModel(modelId: modelId)
                DispatchQueue.main.async {
                    self.currentModelId = modelId
                    self.isModelLoaded = true
                    self.isLoading = false
                    self.logger.info("Model loaded successfully: \(modelId)")
                    self.postLoadingStateNotification()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isModelLoaded = false
                    self.currentModelId = nil
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
