import Foundation

enum TranscriptionError: Error, LocalizedError {
    case modelNotLoaded
    case modelNotFound(String)
    case failedToReadAudio(String)
    case failedToCreateRecognizer
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No transcription model is loaded"
        case .modelNotFound(let path):
            return "Model not found at path: \(path)"
        case .failedToReadAudio(let path):
            return "Failed to read audio file: \(path)"
        case .failedToCreateRecognizer:
            return "Failed to create speech recognizer"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}

final class TranscriptionService {
    static let shared = TranscriptionService()
    private init() {}
    
    private var currentModelId: String?
    private var recognizer: SherpaOnnxOfflineRecognizer?
    
    private var modelsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superwhisperfree/models")
    }
    
    func loadModel(modelId: String) throws {
        if currentModelId == modelId && recognizer != nil {
            print("TranscriptionService: Model \(modelId) already loaded")
            return
        }
        
        unloadModel()
        
        print("TranscriptionService: Loading model \(modelId)")
        
        let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
        let modelConfig: SherpaOnnxOfflineModelConfig
        
        if modelId.hasPrefix("whisper-") {
            modelConfig = try createWhisperModelConfig(modelId: modelId)
        } else if modelId == "parakeet-v2" {
            modelConfig = try createParakeetModelConfig()
        } else {
            throw TranscriptionError.modelNotFound("Unknown model type: \(modelId)")
        }
        
        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search"
        )
        
        do {
            recognizer = try SherpaOnnxOfflineRecognizer(config: &config)
            currentModelId = modelId
            print("TranscriptionService: Successfully loaded model \(modelId)")
        } catch {
            print("TranscriptionService: Failed to create recognizer - \(error.localizedDescription)")
            throw TranscriptionError.failedToCreateRecognizer
        }
    }
    
    func transcribe(audioURL: URL) -> String? {
        guard let recognizer = recognizer else {
            print("TranscriptionService: No model loaded")
            return nil
        }
        
        print("TranscriptionService: Transcribing \(audioURL.path)")
        
        let wave = SherpaOnnxWaveWrapper.readWave(filename: audioURL.path)
        
        guard wave.wave != nil else {
            print("TranscriptionService: Failed to read audio file")
            return nil
        }
        
        let samples = wave.samples
        let sampleRate = wave.sampleRate
        
        guard !samples.isEmpty else {
            print("TranscriptionService: Audio file is empty")
            return nil
        }
        
        print("TranscriptionService: Audio has \(samples.count) samples at \(sampleRate)Hz")
        
        do {
            let result = try recognizer.decode(samples: samples, sampleRate: sampleRate)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("TranscriptionService: Transcription result: \(text)")
            
            return text.isEmpty ? nil : text
        } catch {
            print("TranscriptionService: Decode failed - \(error.localizedDescription)")
            return nil
        }
    }
    
    func unloadModel() {
        recognizer = nil
        currentModelId = nil
        print("TranscriptionService: Model unloaded")
    }
    
    private func createWhisperModelConfig(modelId: String) throws -> SherpaOnnxOfflineModelConfig {
        let size: String
        switch modelId {
        case "whisper-tiny":
            size = "tiny.en"
        case "whisper-base":
            size = "base.en"
        case "whisper-small":
            size = "small.en"
        default:
            throw TranscriptionError.modelNotFound("Unknown Whisper model: \(modelId)")
        }
        
        let modelDir = modelsDirectory.appendingPathComponent("sherpa-onnx-whisper-\(size)")
        
        let encoder = modelDir.appendingPathComponent("\(size)-encoder.int8.onnx").path
        let decoder = modelDir.appendingPathComponent("\(size)-decoder.int8.onnx").path
        let tokens = modelDir.appendingPathComponent("\(size)-tokens.txt").path
        
        guard FileManager.default.fileExists(atPath: encoder) else {
            throw TranscriptionError.modelNotFound(encoder)
        }
        guard FileManager.default.fileExists(atPath: decoder) else {
            throw TranscriptionError.modelNotFound(decoder)
        }
        guard FileManager.default.fileExists(atPath: tokens) else {
            throw TranscriptionError.modelNotFound(tokens)
        }
        
        let whisperConfig = sherpaOnnxOfflineWhisperModelConfig(
            encoder: encoder,
            decoder: decoder,
            language: "en",
            task: "transcribe"
        )
        
        return sherpaOnnxOfflineModelConfig(
            tokens: tokens,
            whisper: whisperConfig,
            numThreads: 4,
            provider: "cpu",
            debug: 0
        )
    }
    
    private func createParakeetModelConfig() throws -> SherpaOnnxOfflineModelConfig {
        let modelDir = modelsDirectory.appendingPathComponent("sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8")
        
        let encoder = modelDir.appendingPathComponent("encoder.int8.onnx").path
        let decoder = modelDir.appendingPathComponent("decoder.int8.onnx").path
        let joiner = modelDir.appendingPathComponent("joiner.int8.onnx").path
        let tokens = modelDir.appendingPathComponent("tokens.txt").path
        
        guard FileManager.default.fileExists(atPath: encoder) else {
            throw TranscriptionError.modelNotFound(encoder)
        }
        guard FileManager.default.fileExists(atPath: decoder) else {
            throw TranscriptionError.modelNotFound(decoder)
        }
        guard FileManager.default.fileExists(atPath: joiner) else {
            throw TranscriptionError.modelNotFound(joiner)
        }
        guard FileManager.default.fileExists(atPath: tokens) else {
            throw TranscriptionError.modelNotFound(tokens)
        }
        
        let transducerConfig = sherpaOnnxOfflineTransducerModelConfig(
            encoder: encoder,
            decoder: decoder,
            joiner: joiner
        )
        
        return sherpaOnnxOfflineModelConfig(
            tokens: tokens,
            transducer: transducerConfig,
            numThreads: 4,
            provider: "cpu",
            debug: 0
        )
    }
}
