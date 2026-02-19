import Foundation

final class TranscriptionClient {
    static let shared = TranscriptionClient()
    private init() {}
    
    func start() {
        // Load model based on settings
        let settings = SettingsManager.shared.settings
        let modelId = settings.modelType == "parakeet" ? "parakeet-v2" : "whisper-\(settings.modelSize)"
        
        do {
            try TranscriptionService.shared.loadModel(modelId: modelId)
            print("TranscriptionClient: Model loaded")
        } catch {
            print("TranscriptionClient: Failed to load model: \(error)")
        }
    }
    
    func stop() {
        TranscriptionService.shared.unloadModel()
    }
    
    func transcribe(audioPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: audioPath)
            if let text = TranscriptionService.shared.transcribe(audioURL: url) {
                DispatchQueue.main.async {
                    completion(.success(text))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "TranscriptionClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Transcription failed"])))
                }
            }
        }
    }
}
