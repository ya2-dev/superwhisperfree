import Foundation

struct DailyStat: Codable, Equatable {
    var date: String
    var words: Int
    var recordings: Int
    var totalDurationSec: Double
}

struct Analytics: Codable {
    var typingWPM: Int?
    var dailyStats: [DailyStat]
    
    static let empty = Analytics(typingWPM: nil, dailyStats: [])
}

final class AnalyticsManager {
    
    static let shared = AnalyticsManager()
    
    private var analytics: Analytics = .empty
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private var analyticsURL: URL {
        SettingsManager.shared.appSupportURL.appendingPathComponent("analytics.json")
    }
    
    private init() {
        load()
    }
    
    private func load() {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: analyticsURL.path) else {
            analytics = .empty
            return
        }
        
        do {
            let data = try Data(contentsOf: analyticsURL)
            let decoder = JSONDecoder()
            analytics = try decoder.decode(Analytics.self, from: data)
        } catch {
            print("Failed to load analytics: \(error)")
            analytics = .empty
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(analytics)
            try data.write(to: analyticsURL, options: .atomic)
        } catch {
            print("Failed to save analytics: \(error)")
        }
    }
    
    func addDictation(words: Int, durationSeconds: Double) {
        let today = dateFormatter.string(from: Date())
        
        if let index = analytics.dailyStats.firstIndex(where: { $0.date == today }) {
            analytics.dailyStats[index].words += words
            analytics.dailyStats[index].recordings += 1
            analytics.dailyStats[index].totalDurationSec += durationSeconds
        } else {
            let newStat = DailyStat(
                date: today,
                words: words,
                recordings: 1,
                totalDurationSec: durationSeconds
            )
            analytics.dailyStats.append(newStat)
        }
        
        save()
    }
    
    func setTypingWPM(_ wpm: Int) {
        analytics.typingWPM = wpm
        save()
    }
    
    var typingWPM: Int? {
        analytics.typingWPM
    }
    
    var totalWords: Int {
        analytics.dailyStats.reduce(0) { $0 + $1.words }
    }
    
    var totalRecordings: Int {
        analytics.dailyStats.reduce(0) { $0 + $1.recordings }
    }
    
    private var totalDurationSeconds: Double {
        analytics.dailyStats.reduce(0) { $0 + $1.totalDurationSec }
    }
    
    var speakingWPM: Int {
        let totalMinutes = totalDurationSeconds / 60.0
        guard totalMinutes > 0 else { return 150 }
        return Int(Double(totalWords) / totalMinutes)
    }
    
    func minutesSaved(benchmarkWPM: Int = 45) -> Double {
        guard benchmarkWPM > 0 else { return 0 }
        
        let typingMinutes = Double(totalWords) / Double(benchmarkWPM)
        let speakingMinutes = totalDurationSeconds / 60.0
        
        return max(0, typingMinutes - speakingMinutes)
    }
    
    func recentStats(days: Int = 30) -> [DailyStat] {
        let calendar = Calendar.current
        let today = Date()
        
        var recentDates: [String] = []
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                recentDates.append(dateFormatter.string(from: date))
            }
        }
        
        var result: [DailyStat] = []
        for dateString in recentDates.reversed() {
            if let stat = analytics.dailyStats.first(where: { $0.date == dateString }) {
                result.append(stat)
            } else {
                result.append(DailyStat(date: dateString, words: 0, recordings: 0, totalDurationSec: 0))
            }
        }
        
        return result
    }
    
    func reload() {
        load()
    }
}
