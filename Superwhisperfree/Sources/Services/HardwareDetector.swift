import Foundation

final class HardwareDetector {
    static let shared = HardwareDetector()

    var ramGB: Int {
        Int(round(Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824))
    }

    var maxRecommendedRAM: Int {
        Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024) / 4)
    }

    func recommendedModelId(multilingual: Bool) -> String {
        if multilingual {
            return "parakeet-v3"
        }
        switch ramGB {
        case ..<16:
            return "parakeet"
        default:
            return "parakeet-v3"
        }
    }

    private init() {}
}
