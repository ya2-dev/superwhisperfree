import Foundation

struct ModelManifestEntry: Codable {
    let id: String
    let name: String
    let size: String
    let sha: String
    let recommended: Bool
    let multilingual: Bool
    let huggingfaceId: String
    let downloadUrl: String
    let description: String
}

struct ModelManifest: Codable {
    let version: Int
    let lastUpdated: String
    let models: [ModelManifestEntry]
}

final class ModelManifestService {
    static let shared = ModelManifestService()
    
    private let manifestURL = URL(string: "https://raw.githubusercontent.com/user/superwhisperfreev2/main/models-manifest.json")!
    private let cacheKey = "cachedModelManifest"
    private let cacheTimestampKey = "manifestCacheTimestamp"
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {}
    
    /// Fetches the model manifest, using cache if available and fresh
    func fetchManifest(forceRefresh: Bool = false, completion: @escaping (Result<ModelManifest, Error>) -> Void) {
        // Check cache first unless force refresh
        if !forceRefresh, let cached = getCachedManifest() {
            completion(.success(cached))
            return
        }
        
        // Fetch from network
        URLSession.shared.dataTask(with: manifestURL) { [weak self] data, response, error in
            if let error = error {
                // Try to return cached version on error
                if let cached = self?.getCachedManifest(ignoreExpiry: true) {
                    DispatchQueue.main.async {
                        completion(.success(cached))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(ModelManifestError.noData))
                }
                return
            }
            
            do {
                let manifest = try JSONDecoder().decode(ModelManifest.self, from: data)
                self?.cacheManifest(data)
                DispatchQueue.main.async {
                    completion(.success(manifest))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Checks if any models have updates available
    func checkForUpdates(currentModels: [String: String], completion: @escaping (Result<[String], Error>) -> Void) {
        fetchManifest(forceRefresh: true) { result in
            switch result {
            case .success(let manifest):
                var updatesAvailable: [String] = []
                for model in manifest.models {
                    if let currentSha = currentModels[model.id], currentSha != model.sha {
                        updatesAvailable.append(model.id)
                    }
                }
                completion(.success(updatesAvailable))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func getCachedManifest(ignoreExpiry: Bool = false) -> ModelManifest? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        
        if !ignoreExpiry {
            let timestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
            if Date().timeIntervalSince1970 - timestamp > cacheDuration {
                return nil
            }
        }
        
        return try? JSONDecoder().decode(ModelManifest.self, from: data)
    }
    
    private func cacheManifest(_ data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
    }
}

enum ModelManifestError: LocalizedError {
    case noData
    case invalidManifest
    
    var errorDescription: String? {
        switch self {
        case .noData: return "No data received from manifest URL"
        case .invalidManifest: return "Invalid manifest format"
        }
    }
}
