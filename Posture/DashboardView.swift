import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var selectedTimeRange: TimeRange = .day
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    Text("Hour").tag(TimeRange.hour)
                    Text("Today").tag(TimeRange.day)
                    Text("Week").tag(TimeRange.week)
                    Text("Month").tag(TimeRange.month)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Summary Cards
                let stats = bluetoothManager.dataStore.getPostureStats(for: selectedTimeRange)
                HStack(spacing: 20) {
                    StatCard(
                        title: "Good Posture",
                        value: formatDuration(stats.goodPostureTime),
                        color: .green
                    )
                    
                    StatCard(
                        title: "Poor Posture",
                        value: formatDuration(stats.badPostureTime),
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(stats.goodPosturePercentage / 100))
                        .stroke(Color.green, lineWidth: 20)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(Int(stats.goodPosturePercentage))%")
                            .font(.title)
                            .bold()
                        Text("Good Posture")
                            .font(.subheadline)
                    }
                }
                .frame(width: 200, height: 200)
                .padding()
                
                // Chart
                let hourlyData = bluetoothManager.dataStore.getHourlyBreakdown(for: selectedTimeRange)
                if !hourlyData.isEmpty {
                    Chart {
                        ForEach(hourlyData) { data in
                            BarMark(
                                x: .value("Hour", "\(data.hour):00"),
                                y: .value("Good Time", data.goodTime / 60.0)
                            )
                            .foregroundStyle(.green)
                            
                            BarMark(
                                x: .value("Hour", "\(data.hour):00"),
                                y: .value("Bad Time", data.badTime / 60.0)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                    .frame(height: 300)
                    .padding()
                } else {
                    Text("No data available for the selected time range")
                        .foregroundColor(.secondary)
                        .frame(height: 300)
                        .padding()
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 800)
        .onReceive(bluetoothManager.dataStore.$records) { _ in
            refreshID = UUID()
        }
        .onReceive(bluetoothManager.dataStore.$currentGoodPostureTime) { _ in
            refreshID = UUID()
        }
        .onReceive(bluetoothManager.dataStore.$currentBadPostureTime) { _ in
            refreshID = UUID()
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
