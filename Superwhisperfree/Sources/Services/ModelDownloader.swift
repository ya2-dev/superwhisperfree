import Foundation

final class ModelDownloader: NSObject {
    static let shared = ModelDownloader()
    
    typealias ProgressCallback = (Double, String) -> Void
    typealias CompletionCallback = (Result<URL, Error>) -> Void
    
    private var downloadTask: URLSessionDownloadTask?
    private var progressCallback: ProgressCallback?
    private var completionCallback: CompletionCallback?
    private var currentModelId: String?
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private static let modelURLs: [String: String] = [
        "parakeet": "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2",
        "whisper-tiny": "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.en.tar.bz2",
        "whisper-base": "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-base.en.tar.bz2",
        "whisper-small": "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.en.tar.bz2"
    ]
    
    private static let modelDirectoryNames: [String: String] = [
        "parakeet": "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8",
        "whisper-tiny": "sherpa-onnx-whisper-tiny.en",
        "whisper-base": "sherpa-onnx-whisper-base.en",
        "whisper-small": "sherpa-onnx-whisper-small.en"
    ]
    
    private override init() {
        super.init()
    }
    
    /// Returns the base models directory: ~/Library/Application Support/Superwhisperfree/models/
    static func modelsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Superwhisperfree/models", isDirectory: true)
    }
    
    /// Returns the directory path for a specific model ID
    /// - Parameter modelId: The model identifier (e.g., "parakeet", "whisper-tiny")
    /// - Returns: URL to the model's extracted directory, or nil if model ID is invalid
    static func modelDirectory(for modelId: String) -> URL? {
        guard let dirName = modelDirectoryNames[modelId] else {
            return nil
        }
        return modelsDirectory().appendingPathComponent(dirName, isDirectory: true)
    }
    
    /// Checks if a model is already downloaded and extracted
    /// - Parameter modelId: The model identifier
    /// - Returns: true if the model directory exists
    static func isModelDownloaded(_ modelId: String) -> Bool {
        guard let modelDir = modelDirectory(for: modelId) else {
            return false
        }
        return FileManager.default.fileExists(atPath: modelDir.path)
    }
    
    /// Downloads and extracts a model
    /// - Parameters:
    ///   - modelId: The model identifier (e.g., "parakeet", "whisper-tiny", "whisper-base", "whisper-small")
    ///   - progress: Callback with (0.0-1.0, status message)
    ///   - completion: Callback with Result containing the model directory URL on success
    func download(
        modelId: String,
        progress: @escaping ProgressCallback,
        completion: @escaping CompletionCallback
    ) {
        guard let urlString = Self.modelURLs[modelId],
              let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(.failure(ModelDownloaderError.invalidModelId(modelId)))
            }
            return
        }
        
        if Self.isModelDownloaded(modelId) {
            if let modelDir = Self.modelDirectory(for: modelId) {
                DispatchQueue.main.async {
                    progress(1.0, "Model already downloaded")
                    completion(.success(modelDir))
                }
                return
            }
        }
        
        do {
            try FileManager.default.createDirectory(
                at: Self.modelsDirectory(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            DispatchQueue.main.async {
                completion(.failure(ModelDownloaderError.fileSystemError(error)))
            }
            return
        }
        
        self.currentModelId = modelId
        self.progressCallback = progress
        self.completionCallback = completion
        
        DispatchQueue.main.async {
            progress(0.0, "Starting download...")
        }
        
        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    /// Cancels the current download if one is in progress
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressCallback = nil
        completionCallback = nil
        currentModelId = nil
    }
    
    private func extractTarBz2(at archivePath: URL, to destinationDir: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            self.progressCallback?(0.95, "Extracting model files...")
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["xjf", archivePath.path, "-C", destinationDir.path]
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    try? FileManager.default.removeItem(at: archivePath)
                    completion(.success(()))
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown extraction error"
                    completion(.failure(ModelDownloaderError.extractionFailed(errorMessage)))
                }
            } catch {
                completion(.failure(ModelDownloaderError.extractionFailed(error.localizedDescription)))
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - URLSessionDownloadDelegate
extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelId = currentModelId else {
            DispatchQueue.main.async {
                self.completionCallback?(.failure(ModelDownloaderError.internalError("No model ID set")))
                self.cleanup()
            }
            return
        }
        
        let modelsDir = Self.modelsDirectory()
        let archivePath = modelsDir.appendingPathComponent("\(modelId).tar.bz2")
        
        do {
            if FileManager.default.fileExists(atPath: archivePath.path) {
                try FileManager.default.removeItem(at: archivePath)
            }
            try FileManager.default.moveItem(at: location, to: archivePath)
        } catch {
            DispatchQueue.main.async {
                self.completionCallback?(.failure(ModelDownloaderError.fileSystemError(error)))
                self.cleanup()
            }
            return
        }
        
        extractTarBz2(at: archivePath, to: modelsDir) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.saveModelSelection(modelId: modelId)
                
                if let modelDir = Self.modelDirectory(for: modelId) {
                    DispatchQueue.main.async {
                        self.progressCallback?(1.0, "Download complete!")
                        self.completionCallback?(.success(modelDir))
                        self.cleanup()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.completionCallback?(.failure(ModelDownloaderError.internalError("Could not determine model directory")))
                        self.cleanup()
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.completionCallback?(.failure(error))
                    self.cleanup()
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress: Double
        let statusMessage: String
        
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let downloadedStr = formatBytes(totalBytesWritten)
            let totalStr = formatBytes(totalBytesExpectedToWrite)
            statusMessage = "Downloading: \(downloadedStr) / \(totalStr)"
        } else {
            progress = 0.0
            let downloadedStr = formatBytes(totalBytesWritten)
            statusMessage = "Downloading: \(downloadedStr)"
        }
        
        DispatchQueue.main.async {
            self.progressCallback?(min(progress * 0.95, 0.94), statusMessage)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                DispatchQueue.main.async {
                    self.completionCallback?(.failure(ModelDownloaderError.downloadCancelled))
                    self.cleanup()
                }
            } else {
                DispatchQueue.main.async {
                    self.completionCallback?(.failure(ModelDownloaderError.networkError(error)))
                    self.cleanup()
                }
            }
        }
    }
    
    private func cleanup() {
        downloadTask = nil
        progressCallback = nil
        completionCallback = nil
        currentModelId = nil
    }
    
    private func saveModelSelection(modelId: String) {
        let (modelType, modelSize) = parseModelId(modelId)
        var settings = SettingsManager.shared.settings
        settings.modelType = modelType
        settings.modelSize = modelSize
        SettingsManager.shared.settings = settings
        SettingsManager.shared.save()
    }
    
    private func parseModelId(_ modelId: String) -> (type: String, size: String) {
        if modelId == "parakeet" {
            return ("parakeet", "default")
        } else if modelId.hasPrefix("whisper-") {
            let size = String(modelId.dropFirst(8))
            return ("whisper", size)
        }
        return ("parakeet", "default")
    }
}

// MARK: - Errors
enum ModelDownloaderError: LocalizedError {
    case invalidModelId(String)
    case networkError(Error)
    case fileSystemError(Error)
    case extractionFailed(String)
    case downloadCancelled
    case internalError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidModelId(let id):
            return "Invalid model ID: \(id). Valid IDs are: parakeet, whisper-tiny, whisper-base, whisper-small"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .extractionFailed(let message):
            return "Failed to extract model: \(message)"
        case .downloadCancelled:
            return "Download was cancelled"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}
