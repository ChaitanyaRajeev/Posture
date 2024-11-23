import Foundation

struct PostureRecord: Codable {
    let timestamp: Date
    let isGoodPosture: Bool
    let angle: Double
    let direction: PostureDirection
    
    var hourKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: timestamp)
    }
    
    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }
    
    var weekKey: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: timestamp)
        let year = calendar.component(.year, from: timestamp)
        return "\(year)-W\(weekOfYear)"
    }
}

class PostureDataStore: ObservableObject {
    @Published var records: [PostureRecord] = []
    @Published var currentGoodPostureTime: TimeInterval = 0
    @Published var currentBadPostureTime: TimeInterval = 0
    @Published var totalGoodPostureTime: TimeInterval = 0
    @Published var totalBadPostureTime: TimeInterval = 0
    
    private let cleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private var isTracking = false
    private var lastCleanupTime: Date?
    private var currentPostureStartTime: Date?
    private var lastPostureStatus: Bool?
    private var updateTimer: Timer?
    
    init() {
        cleanupOldRecords()
        print("PostureDataStore initialized")
    }
    
    func startTracking() {
        isTracking = true
        currentPostureStartTime = Date()
        totalGoodPostureTime = 0
        totalBadPostureTime = 0
        currentGoodPostureTime = 0
        currentBadPostureTime = 0
        print(" Tracking started")
        startPeriodicUpdates()
    }
    
    func stopTracking() {
        isTracking = false
        currentPostureStartTime = nil
        lastPostureStatus = nil
        updateTimer?.invalidate()
        updateTimer = nil
        currentGoodPostureTime = 0
        currentBadPostureTime = 0
        totalGoodPostureTime = 0
        totalBadPostureTime = 0
        print(" Tracking stopped")
    }
    
    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentPostureTime()
        }
        print(" Periodic updates started with interval 0.1s")
    }
    
    private func updateCurrentPostureTime() {
        guard isTracking,
              let startTime = currentPostureStartTime,
              let isGoodPosture = lastPostureStatus else {
            return
        }
        
        let currentDuration = Date().timeIntervalSince(startTime)
        
        DispatchQueue.main.async {
            if isGoodPosture {
                self.currentGoodPostureTime = currentDuration
                if currentDuration >= 60.0 {
                    self.totalGoodPostureTime += 60.0
                    print(" One minute of good posture completed! Total: \(self.formatTime(self.totalGoodPostureTime))")
                    self.currentPostureStartTime = Date()
                    self.currentGoodPostureTime = 0
                    print(" Current Stats - Good: \(self.formatTime(self.currentGoodPostureTime)), Bad: \(self.formatTime(self.currentBadPostureTime))")
                }
            } else {
                self.currentBadPostureTime = currentDuration
                if currentDuration >= 60.0 {
                    self.totalBadPostureTime += 60.0
                    print(" One minute of bad posture completed! Total: \(self.formatTime(self.totalBadPostureTime))")
                    self.currentPostureStartTime = Date()
                    self.currentBadPostureTime = 0
                    print(" Current Stats - Good: \(self.formatTime(self.currentGoodPostureTime)), Bad: \(self.formatTime(self.currentBadPostureTime))")
                }
            }
            
            // Log every 5 seconds for debugging
            if Int(currentDuration) % 5 == 0 {
                print(" Time Update - Current Duration: \(self.formatTime(currentDuration))")
                print(" Stats - Good: \(self.formatTime(self.totalGoodPostureTime + self.currentGoodPostureTime)), Bad: \(self.formatTime(self.totalBadPostureTime + self.currentBadPostureTime))")
            }
        }
    }
    
    func addRecord(_ status: PostureStatus) {
        guard isTracking else { return }
        
        let isGoodPosture = status.direction == .neutral
        print(" Posture Update - Status: \(isGoodPosture ? "Good" : "Bad"), Direction: \(status.direction)")
        
        // If posture state changed or we're just starting
        if lastPostureStatus != isGoodPosture || currentPostureStartTime == nil {
            print(" Posture state changed from \(String(describing: lastPostureStatus)) to \(isGoodPosture)")
            
            // Save any accumulated time from the previous posture
            if let startTime = currentPostureStartTime,
               let wasGoodPosture = lastPostureStatus {
                let duration = Date().timeIntervalSince(startTime)
                
                DispatchQueue.main.async {
                    if wasGoodPosture {
                        self.totalGoodPostureTime += min(duration, 60.0)
                        self.currentGoodPostureTime = 0
                        print(" Added \(self.formatTime(min(duration, 60.0))) to good posture total")
                    } else {
                        self.totalBadPostureTime += min(duration, 60.0)
                        self.currentBadPostureTime = 0
                        print(" Added \(self.formatTime(min(duration, 60.0))) to bad posture total")
                    }
                }
            }
            
            // Start tracking new posture state
            currentPostureStartTime = Date()
            lastPostureStatus = isGoodPosture
        }
        
        cleanupOldRecords()
    }
    
    private func cleanupOldRecords() {
        if let lastCleanup = lastCleanupTime,
           Date().timeIntervalSince(lastCleanup) < 3600 {
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-cleanupInterval)
        records.removeAll { $0.timestamp < cutoffDate }
        lastCleanupTime = Date()
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return "\(minutes)m \(remainingSeconds)s"
    }
    
    func getPostureStats(for timeRange: TimeRange) -> PostureStats {
        var stats = PostureStats()
        
        // Add the total accumulated time
        stats.goodPostureTime = totalGoodPostureTime
        stats.badPostureTime = totalBadPostureTime
        
        // Add the current running time
        if isTracking {
            stats.goodPostureTime += currentGoodPostureTime
            stats.badPostureTime += currentBadPostureTime
        }
        
        print(" Getting Stats - Good: \(formatTime(stats.goodPostureTime)), Bad: \(formatTime(stats.badPostureTime))")
        return stats
    }
    
    struct HourlyData: Identifiable {
        let id: Int
        let hour: Int
        let goodTime: TimeInterval
        let badTime: TimeInterval
        
        init(hour: Int, goodTime: TimeInterval, badTime: TimeInterval) {
            self.id = hour
            self.hour = hour
            self.goodTime = goodTime
            self.badTime = badTime
        }
    }
    
    func getHourlyBreakdown(for timeRange: TimeRange) -> [HourlyData] {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        
        let data = [
            HourlyData(
                hour: currentHour,
                goodTime: totalGoodPostureTime + currentGoodPostureTime,
                badTime: totalBadPostureTime + currentBadPostureTime
            )
        ]
        
        print(" Hourly Data - Hour: \(currentHour), Good: \(formatTime(data[0].goodTime)), Bad: \(formatTime(data[0].badTime))")
        return data
    }
}

struct PostureStats {
    var goodPostureTime: TimeInterval = 0
    var badPostureTime: TimeInterval = 0
    
    var totalPostureTime: TimeInterval {
        return goodPostureTime + badPostureTime
    }
    
    var goodPosturePercentage: Double {
        guard totalPostureTime > 0 else { return 0 }
        return (goodPostureTime / totalPostureTime) * 100
    }
}

enum TimeRange {
    case hour, day, week, month
}
