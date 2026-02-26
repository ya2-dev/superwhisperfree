import Foundation

struct DailyStat: Codable, Equatable {
    var date: String
    var words: Int
    var recordings: Int
    var totalDurationSec: Double
}

struct TranscriptionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let wordCount: Int
    let durationSeconds: Double
    let timestamp: Date
    let wpm: Int
    
    init(text: String, durationSeconds: Double) {
        self.id = UUID()
        self.text = text
        self.wordCount = text.split(separator: " ").count
        self.durationSeconds = durationSeconds
        self.timestamp = Date()
        
        let minutes = durationSeconds / 60.0
        self.wpm = minutes > 0 ? Int(Double(self.wordCount) / minutes) : 0
    }
}

struct Analytics: Codable {
    var typingWPM: Int?
    var dailyStats: [DailyStat]
    var recentTranscriptions: [TranscriptionRecord]
    
    static let empty = Analytics(typingWPM: nil, dailyStats: [], recentTranscriptions: [])
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
    
    func addTranscription(text: String, durationSeconds: Double) {
        let record = TranscriptionRecord(text: text, durationSeconds: durationSeconds)
        analytics.recentTranscriptions.insert(record, at: 0)
        
        if analytics.recentTranscriptions.count > 50 {
            analytics.recentTranscriptions = Array(analytics.recentTranscriptions.prefix(50))
        }
        
        addDictation(words: record.wordCount, durationSeconds: durationSeconds)
    }
    
    var recentTranscriptions: [TranscriptionRecord] {
        analytics.recentTranscriptions
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
        guard totalMinutes > 0 else { return 0 }
        return Int(Double(totalWords) / totalMinutes)
    }
    
    var averageDictationWPM: Double {
        let totalMinutes = totalDurationSeconds / 60.0
        guard totalMinutes > 0 else { return 0 }
        return Double(totalWords) / totalMinutes
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
    
    func stats(for period: StatPeriod) -> PeriodStats {
        let days: Int
        switch period {
        case .today: days = 1
        case .week: days = 7
        case .month: days = 30
        case .allTime: days = 0
        }
        
        let dailySlice: [DailyStat]
        if days == 0 {
            dailySlice = analytics.dailyStats
        } else {
            let calendar = Calendar.current
            let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date()))!
            dailySlice = analytics.dailyStats.filter {
                if let d = dateFormatter.date(from: $0.date) { return d >= cutoff }
                return false
            }
        }
        
        let words = dailySlice.reduce(0) { $0 + $1.words }
        let recordings = dailySlice.reduce(0) { $0 + $1.recordings }
        let durationSec = dailySlice.reduce(0.0) { $0 + $1.totalDurationSec }
        let speakMin = durationSec / 60.0
        let speakWPM = speakMin > 0 ? Int(Double(words) / speakMin) : 0
        let avgWords = recordings > 0 ? Int(Double(words) / Double(recordings)) : 0
        let tWPM = analytics.typingWPM ?? 45
        let saved = tWPM > 0 ? max(0, Double(words) / Double(tWPM) - speakMin) : 0
        
        return PeriodStats(
            words: words,
            sessions: recordings,
            speakingWPM: speakWPM,
            avgWordsPerSession: avgWords,
            minutesSaved: saved,
            dailyStats: days == 0 ? recentStats(days: max(analytics.dailyStats.count, 30)) : recentStats(days: days)
        )
    }
    
    func todayHourlyStats() -> [(hour: Int, words: Int)] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        let todayRecords = analytics.recentTranscriptions.filter { $0.timestamp >= startOfToday }
        
        var hourBuckets = [Int: Int]()
        for record in todayRecords {
            let hour = calendar.component(.hour, from: record.timestamp)
            hourBuckets[hour, default: 0] += record.wordCount
        }
        
        let now = calendar.component(.hour, from: Date())
        return (0...now).map { h in (hour: h, words: hourBuckets[h] ?? 0) }
    }
    
    func reload() {
        load()
    }
}

enum StatPeriod: String, CaseIterable {
    case today = "Today"
    case week = "7D"
    case month = "30D"
    case allTime = "All Time"
}

struct PeriodStats {
    let words: Int
    let sessions: Int
    let speakingWPM: Int
    let avgWordsPerSession: Int
    let minutesSaved: Double
    let dailyStats: [DailyStat]
}
