import Foundation

final class TranscriptionService {
    static let shared = TranscriptionService()
    private init() {}
    
    private var currentModelId: String?
    
    func loadModel(modelId: String) throws {
        // TODO: Initialize sherpa-onnx with model files
        currentModelId = modelId
        print("TranscriptionService: Would load model \(modelId)")
    }
    
    func transcribe(audioURL: URL) -> String? {
        guard currentModelId != nil else {
            print("TranscriptionService: No model loaded")
            return nil
        }
        // TODO: Actual transcription via sherpa-onnx
        print("TranscriptionService: Would transcribe \(audioURL.path)")
        return "[Transcription placeholder - sherpa-onnx integration pending]"
    }
    
    func unloadModel() {
        currentModelId = nil
    }
}
