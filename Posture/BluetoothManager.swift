import CoreBluetooth
import CoreMotion
import SwiftUI
import Foundation
import IOBluetooth
import CoreAudio

// MARK: - Bluetooth Manager
class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    static let shared = BluetoothManager()
    
    // MARK: - Published Properties
    @Published var isConnected = false {
        didSet {
            if !isConnected {
                // Reset all values when disconnected
                resetValues()
            }
            onConnectionStatusChanged?(isConnected)
        }
    }
    @Published var currentNeckAngle: Double = 0.0
    @Published var connectionStatus: String = "Please connect AirPods"
    @Published var postureStatus = PostureStatus(angle: 0, direction: .neutral, rawAngle: 0, yawAngle: 0)
    @Published var dataStore = PostureDataStore()
    @Published var rawAngle: Double = 0.0
    @Published var isCalibrating: Bool = false
    @Published var calibrationProgress: String = ""
    
    // MARK: - Callbacks
    var onPostureUpdate: ((Double) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?
    var onCalibrationUpdate: ((String) -> Void)?
    
    // MARK: - Private Properties
    private var headTracker = CMHeadphoneMotionManager()
    private var centralManager: CBCentralManager!
    
    // Known AirPods identifiers
    private let airPodsIdentifiers = [
        "AirPods Pro",
        "AirPods (3rd generation)",
        "AirPods",
        "AirPods Max"
    ]
    
    // Calibration and smoothing
    private var calibrationValues: [Double] = []
    private var yawCalibrationValues: [Double] = []
    private var smoothingValues: [Double] = []
    private var yawSmoothingValues: [Double] = []
    private let calibrationSamples = 30
    private let smoothingWindow = 5
    private var baselineAngle: Double?
    private var baselineYaw: Double?
    
    // Connection state
    private var isAirPodsConnected = false
    private var connectionCheckTimer: Timer?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupBluetooth()
        startConnectionCheck()
    }
    
    // MARK: - CBCentralManagerDelegate Methods
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            checkAirPodsConnection()
        case .poweredOff:
            print("Bluetooth is powered off")
            updateConnectionStatus(false)
        default:
            print("Bluetooth state: \(central.state)")
            updateConnectionStatus(false)
        }
    }
    
    private func checkAirPodsConnection() {
        guard let session = IOBluetoothHostController.default() else {
            updateConnectionStatus(false)
            return
        }
        
        // Get list of connected devices
        let connectedDevices = IOBluetoothDevice.pairedDevices()?.filter { device in
            guard let device = device as? IOBluetoothDevice else { return false }
            return device.isConnected() && airPodsIdentifiers.contains(device.name ?? "")
        } ?? []
        
        let isConnected = !connectedDevices.isEmpty
        updateConnectionStatus(isConnected)
        
        if !isConnected {
            resetValues()
        }
    }
    
    private func updateConnectionStatus(_ connected: Bool) {
        DispatchQueue.main.async {
            self.isConnected = connected
            self.connectionStatus = connected ? "AirPods Connected" : "AirPods Not Connected"
        }
    }
    
    private func resetValues() {
        DispatchQueue.main.async {
            self.currentNeckAngle = 0.0
            self.rawAngle = 0.0
            self.postureStatus = PostureStatus(angle: 0, direction: .neutral, rawAngle: 0, yawAngle: 0)
            self.calibrationProgress = ""
            self.isCalibrating = false
            self.baselineAngle = nil
            self.baselineYaw = nil
            self.calibrationValues.removeAll()
            self.yawCalibrationValues.removeAll()
            self.smoothingValues.removeAll()
            self.yawSmoothingValues.removeAll()
            
            // Stop motion updates
            self.headTracker.stopDeviceMotionUpdates()
        }
    }
    
    private func startConnectionCheck() {
        // Check connection status every 2 seconds
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAirPodsConnection()
        }
    }
    
    func startTracking() {
        print("BluetoothManager: Starting tracking")
        guard headTracker.isDeviceMotionAvailable else {
            print("BluetoothManager: Device motion is not available")
            return
        }
        
        resetCalibration()
        startCalibration()
        dataStore.startTracking()
        
        startMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard headTracker.isDeviceMotionAvailable else {
            print("BluetoothManager: Device motion not available")
            return
        }
        
        headTracker.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self,
                  let motion = motion else {
                print("BluetoothManager: Motion update error - \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            let pitch = motion.attitude.pitch * 180 / .pi
            let yaw = motion.attitude.yaw * 180 / .pi
            
            if self.isCalibrating {
                self.handleCalibrationData(pitch, yaw)
            } else {
                self.updatePostureStatus(pitch, yaw)
            }
        }
    }
    
    private func updatePostureStatus(_ currentAngle: Double, _ currentYaw: Double) {
        guard let baseline = baselineAngle,
              let baselineYaw = baselineYaw else {
            print("BluetoothManager: No baseline angles")
            return
        }
        
        // Handle pitch (forward/backward)
        let pitchDeviation = currentAngle - baseline
        smoothingValues.append(pitchDeviation)
        if smoothingValues.count > smoothingWindow {
            smoothingValues.removeFirst()
        }
        
        // Handle yaw (left/right)
        let yawDeviation = currentYaw - baselineYaw
        yawSmoothingValues.append(yawDeviation)
        if yawSmoothingValues.count > smoothingWindow {
            yawSmoothingValues.removeFirst()
        }
        
        let smoothedPitchDeviation = smoothingValues.reduce(0, +) / Double(smoothingValues.count)
        let smoothedYawDeviation = yawSmoothingValues.reduce(0, +) / Double(yawSmoothingValues.count)
        
        currentNeckAngle = smoothedPitchDeviation
        
        let direction: PostureDirection = {
            // First check if there's significant left/right movement
            if abs(smoothedYawDeviation) > 15.0 {  // Threshold for left/right detection
                return smoothedYawDeviation > 0 ? .left : .right
            }
            
            // If no significant left/right movement, check forward/backward
            if abs(smoothedPitchDeviation) <= 3.0 {
                return .neutral
            } else if smoothedPitchDeviation < -3.0 {
                return .forward
            } else {
                return .backward
            }
        }()
        
        postureStatus = PostureStatus(
            angle: abs(smoothedPitchDeviation),
            direction: direction,
            rawAngle: currentAngle,
            yawAngle: smoothedYawDeviation
        )
        
        print("BluetoothManager: Updated - Pitch: \(smoothedPitchDeviation)°, Yaw: \(smoothedYawDeviation)°, Direction: \(direction)")
        
        DispatchQueue.main.async {
            self.onPostureUpdate?(currentAngle)
        }
    }
    
    // MARK: - Setup Methods
    private func setupBluetooth() {
        print("BluetoothManager: Setting up Bluetooth")
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBluetoothChange),
            name: NSNotification.Name(rawValue: "BluetoothConnected"),
            object: nil
        )
        
        // Listen for Bluetooth connection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBluetoothChange),
            name: NSNotification.Name(rawValue: "IOBluetoothDeviceConnected"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBluetoothChange),
            name: NSNotification.Name(rawValue: "IOBluetoothDeviceDisconnected"),
            object: nil
        )
    }
    
    private func startConnectionTimer() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkConnectedDevices()
        }
    }
    
    // MARK: - Bluetooth Connection Methods
    @objc private func handleBluetoothChange(notification: Notification) {
        checkConnectedDevices()
    }
    
    private func checkConnectedDevices() {
        let connectedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        
        let hasConnectedAirPods = connectedDevices.contains { device in
            guard let name = device.name else { return false }
            let isAirPods = airPodsIdentifiers.contains { identifier in
                name.contains(identifier)
            }
            let isConnected = device.isConnected()
            
            if isAirPods {
                print("BluetoothManager: Found \(name) - Connected: \(isConnected)")
            }
            
            return isAirPods && isConnected
        }
        
        // Update connection state
        handleBluetoothStateChange(hasConnectedAirPods)
    }
    
    private func handleBluetoothStateChange(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isAirPodsConnected != connected {
                print("BluetoothManager: Connection state changed to \(connected)")
                self.isAirPodsConnected = connected
                self.connectionStatus = connected ? "AirPods Connected" : "Please connect AirPods"
                
                if connected {
                    self.checkMotionAvailability()
                } else {
                    self.stopTracking()
                }
            }
        }
    }
    
    // MARK: - Motion Tracking Methods
    private func checkMotionAvailability() {
        let isMotionAvailable = headTracker.isDeviceMotionAvailable
        print("BluetoothManager: Motion availability - \(isMotionAvailable)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let shouldBeConnected = isMotionAvailable && self.isAirPodsConnected
            
            if self.isConnected != shouldBeConnected {
                self.isConnected = shouldBeConnected
                print("BluetoothManager: Connection status updated - Connected: \(shouldBeConnected)")
            }
        }
    }
    
    func stopTracking() {
        print("BluetoothManager: Stopping tracking")
        headTracker.stopDeviceMotionUpdates()
        dataStore.stopTracking()
        resetCalibration()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentNeckAngle = 0
            self.rawAngle = 0
            self.postureStatus = PostureStatus(angle: 0, direction: .neutral, rawAngle: 0, yawAngle: 0)
        }
    }
    
    // MARK: - Calibration Methods
    private func resetCalibration() {
        print("BluetoothManager: Resetting calibration")
        isCalibrating = false
        calibrationValues.removeAll()
        yawCalibrationValues.removeAll()
        smoothingValues.removeAll()
        yawSmoothingValues.removeAll()
        baselineAngle = nil
        baselineYaw = nil
    }
    
    func startCalibration() {
        print("BluetoothManager: Starting calibration")
        isCalibrating = true
        calibrationValues.removeAll()
        yawCalibrationValues.removeAll()
        calibrationProgress = "Calibrating... Please maintain neutral posture"
        onCalibrationUpdate?("Calibrating... (0/\(calibrationSamples))")
    }
    
    private func handleCalibrationData(_ pitch: Double, _ yaw: Double) {
        calibrationValues.append(pitch)
        yawCalibrationValues.append(yaw)
        
        let progress = Int((Double(calibrationValues.count) / Double(calibrationSamples)) * 100)
        calibrationProgress = "Calibrating: \(progress)%"
        onCalibrationUpdate?("Calibrating: \(progress)%")
        
        if calibrationValues.count >= calibrationSamples {
            // Sort and take middle 60% of values to remove outliers
            let sortedPitchValues = calibrationValues.sorted()
            let sortedYawValues = yawCalibrationValues.sorted()
            let startIndex = Int(Double(calibrationSamples) * 0.2)
            let endIndex = Int(Double(calibrationSamples) * 0.8)
            
            let middlePitchValues = Array(sortedPitchValues[startIndex..<endIndex])
            let middleYawValues = Array(sortedYawValues[startIndex..<endIndex])
            
            baselineAngle = middlePitchValues.reduce(0, +) / Double(middlePitchValues.count)
            baselineYaw = middleYawValues.reduce(0, +) / Double(middleYawValues.count)
            
            calibrationValues.removeAll()
            yawCalibrationValues.removeAll()
            isCalibrating = false
            calibrationProgress = "Calibration Complete"
            onCalibrationUpdate?("Calibration Complete")
            
            print("BluetoothManager: Calibration complete - Baseline angle: \(baselineAngle ?? 0)°, Baseline yaw: \(baselineYaw ?? 0)°")
        }
    }
    
    // MARK: - Posture Status Methods
    private func determinePostureStatus(from deviation: Double, rawAngle: Double) -> PostureStatus {
        let absoluteDeviation = abs(deviation)
        let threshold: Double = 3.0
        
        var direction: PostureDirection = .neutral
        if absoluteDeviation >= threshold {
            direction = deviation > 0 ? .forward : .backward
        }
        
        return PostureStatus(
            angle: absoluteDeviation,
            direction: direction,
            rawAngle: rawAngle,
            yawAngle: 0.0
        )
    }
    
    // MARK: - Public Methods
    func recalibrate() {
        print("BluetoothManager: Starting recalibration")
        resetCalibration()
        startCalibration()
    }
}
