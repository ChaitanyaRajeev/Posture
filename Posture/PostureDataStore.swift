import Foundation

class PostureDataStore: ObservableObject {
    @Published var records: [PostureRecord] = []
    private var isTracking = false
    private var timer: Timer?
    
    func startTracking() {
        isTracking = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPostureStatus()
        }
    }
    
    func stopTracking() {
        isTracking = false
        timer?.invalidate()
        timer = nil
    }
    
    func addRecord(_ status: PostureStatus) {
        let record = PostureRecord(
            timestamp: Date(),
            angle: status.angle,
            direction: status.direction,
            rawAngle: status.rawAngle,
            yawAngle: status.yawAngle
        )
        records.append(record)
        
        // Keep only the last hour of data
        let oneHourAgo = Date().addingTimeInterval(-3600)
        records = records.filter { $0.timestamp > oneHourAgo }
    }
    
    private func checkPostureStatus() {
        // This will be called every second when tracking is active
        // You can add notifications or other checks here
    }
}
