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
    private var currentLanguage: String?
    private var recognizer: SherpaOnnxOfflineRecognizer?
    
    private var modelsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Superwhisperfree/models")
    }
    
    func loadModel(modelId: String, language: String? = nil) throws {
        if currentModelId == modelId && currentLanguage == language && recognizer != nil {
            print("TranscriptionService: Model \(modelId) (lang: \(language ?? "default")) already loaded")
            return
        }
        
        unloadModel()
        
        print("TranscriptionService: Loading model \(modelId) (lang: \(language ?? "default"))")
        
        let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
        let modelConfig: SherpaOnnxOfflineModelConfig
        
        if modelId.hasPrefix("whisper-") {
            modelConfig = try createWhisperModelConfig(modelId: modelId, language: language ?? "en")
        } else if modelId == "parakeet" || modelId == "parakeet-v2" {
            modelConfig = try createParakeetModelConfig()
        } else if modelId == "parakeet-v3" {
            modelConfig = try createParakeetV3ModelConfig()
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
            currentLanguage = language
            print("TranscriptionService: Successfully loaded model \(modelId) (lang: \(language ?? "default"))")
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
        
        let durationSeconds = Double(samples.count) / Double(sampleRate)
        print("TranscriptionService: Audio has \(samples.count) samples at \(sampleRate)Hz (\(String(format: "%.1f", durationSeconds))s)")
        
        // Whisper has a 30-second context window - for longer audio, use chunked transcription
        let maxChunkSeconds = 25.0
        
        if durationSeconds <= maxChunkSeconds {
            return transcribeSamples(samples, sampleRate: sampleRate, recognizer: recognizer)
        } else {
            return transcribeChunked(samples: samples, sampleRate: sampleRate, recognizer: recognizer, maxChunkSeconds: maxChunkSeconds)
        }
    }
    
    private func transcribeSamples(_ samples: [Float], sampleRate: Int, recognizer: SherpaOnnxOfflineRecognizer) -> String? {
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
    
    private func transcribeChunked(samples: [Float], sampleRate: Int, recognizer: SherpaOnnxOfflineRecognizer, maxChunkSeconds: Double) -> String? {
        let samplesPerChunk = Int(maxChunkSeconds * Double(sampleRate))
        let overlapSamples = Int(1.0 * Double(sampleRate)) // 1 second overlap for continuity
        
        var transcriptions: [String] = []
        var startIndex = 0
        var chunkNumber = 1
        
        while startIndex < samples.count {
            let endIndex = min(startIndex + samplesPerChunk, samples.count)
            let chunkSamples = Array(samples[startIndex..<endIndex])
            
            let chunkDuration = Double(chunkSamples.count) / Double(sampleRate)
            print("TranscriptionService: Processing chunk \(chunkNumber) (\(String(format: "%.1f", chunkDuration))s)")
            
            if let chunkText = transcribeSamples(chunkSamples, sampleRate: sampleRate, recognizer: recognizer) {
                transcriptions.append(chunkText)
            }
            
            // Move forward, accounting for overlap (except on last chunk)
            if endIndex >= samples.count {
                break
            }
            startIndex = endIndex - overlapSamples
            chunkNumber += 1
        }
        
        guard !transcriptions.isEmpty else {
            print("TranscriptionService: No transcriptions from chunks")
            return nil
        }
        
        // Join chunks, removing potential duplicate words at overlap boundaries
        let fullText = joinChunkTranscriptions(transcriptions)
        print("TranscriptionService: Full transcription (\(chunkNumber) chunks): \(fullText)")
        
        return fullText.isEmpty ? nil : fullText
    }
    
    private func joinChunkTranscriptions(_ transcriptions: [String]) -> String {
        guard transcriptions.count > 1 else {
            return transcriptions.first ?? ""
        }
        
        var result = transcriptions[0]
        
        for i in 1..<transcriptions.count {
            let nextChunk = transcriptions[i]
            
            // Try to find overlap and remove duplicate words
            let resultWords = result.split(separator: " ").map(String.init)
            let nextWords = nextChunk.split(separator: " ").map(String.init)
            
            // Look for overlap in last few words of result vs first few words of next
            let overlapCheckCount = min(5, resultWords.count, nextWords.count)
            var bestOverlap = 0
            
            for overlapLength in 1...overlapCheckCount {
                let endOfResult = resultWords.suffix(overlapLength)
                let startOfNext = nextWords.prefix(overlapLength)
                
                if endOfResult.map({ $0.lowercased() }) == startOfNext.map({ $0.lowercased() }) {
                    bestOverlap = overlapLength
                }
            }
            
            if bestOverlap > 0 {
                // Remove overlapping words from the next chunk
                let nonOverlappingNext = nextWords.dropFirst(bestOverlap).joined(separator: " ")
                if !nonOverlappingNext.isEmpty {
                    result += " " + nonOverlappingNext
                }
            } else {
                result += " " + nextChunk
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func unloadModel() {
        recognizer = nil
        currentModelId = nil
        currentLanguage = nil
        print("TranscriptionService: Model unloaded")
    }
    
    private func createWhisperModelConfig(modelId: String, language: String) throws -> SherpaOnnxOfflineModelConfig {
        let size: String
        switch modelId {
        case "whisper-tiny":
            size = language != "en" ? "tiny" : "tiny.en"
        case "whisper-base":
            size = language != "en" ? "base" : "base.en"
        case "whisper-small":
            size = language != "en" ? "small" : "small.en"
        case "whisper-medium":
            size = language != "en" ? "medium" : "medium.en"
        case "whisper-large-v3":
            size = "large-v3"
        case "whisper-turbo":
            size = "turbo"
        case "whisper-distil-small":
            size = "distil-small.en"
        case "whisper-distil-medium":
            size = "distil-medium.en"
        case "whisper-distil-large-v3.5":
            size = "distil-large-v3.5"
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
            language: language,
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
    
    private func createParakeetV3ModelConfig() throws -> SherpaOnnxOfflineModelConfig {
        let modelDir = modelsDirectory.appendingPathComponent("sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8")
        
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
