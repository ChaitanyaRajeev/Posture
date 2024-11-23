import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var isTrackingEnabled = false
    @State private var showingCalibrationAlert = false
    @State private var showingDashboard = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Posture Monitor")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Connection Status
            Text(bluetoothManager.connectionStatus)
                .foregroundColor(bluetoothManager.isConnected ? .green : .red)
                .padding()
            
            // Current Measurement
            if bluetoothManager.isConnected {
                Text(String(format: "Current Angle: %.1f°", bluetoothManager.currentNeckAngle))
                    .font(.title2)
                
                // Removed optional binding since postureStatus is not optional
                Text("Status: \(bluetoothManager.postureStatus.direction.rawValue)")
                    .font(.title3)
                    .foregroundColor(bluetoothManager.postureStatus.direction == .neutral ? .green : .red)
            } else {
                Text("Please connect AirPods to start monitoring")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            // Calibration and Start/Stop Buttons
            VStack(spacing: 15) {
                Button(action: {
                    showingCalibrationAlert = true
                }) {
                    Text("Calibrate")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding()
                        .background(bluetoothManager.isConnected ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!bluetoothManager.isConnected)
                
                Button(action: {
                    isTrackingEnabled.toggle()
                    if isTrackingEnabled {
                        bluetoothManager.dataStore.startTracking()
                    } else {
                        bluetoothManager.dataStore.stopTracking()
                    }
                }) {
                    Text(isTrackingEnabled ? "Stop Monitoring" : "Start Monitoring")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding()
                        .background(buttonBackground)
                        .cornerRadius(10)
                }
                .disabled(!bluetoothManager.isConnected)
                
                Button(action: {
                    showingDashboard = true
                }) {
                    Text("View Dashboard")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .alert("Calibration", isPresented: $showingCalibrationAlert) {
            Button("Start", action: {
                bluetoothManager.startCalibration()
            })
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please sit in a neutral position with your head straight and press Start to begin calibration.")
        }
        .sheet(isPresented: $showingDashboard) {
            DashboardView()
                .environmentObject(bluetoothManager)
        }
    }
    
    private var buttonBackground: Color {
        if !bluetoothManager.isConnected {
            return .gray
        }
        return isTrackingEnabled ? .red : .blue
    }
}
