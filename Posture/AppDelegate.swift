import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var startStopItem: NSMenuItem!
    private var statusTextItem: NSMenuItem!
    private var postureAngleItem: NSMenuItem!
    private var posturePositionItem: NSMenuItem!
    private var calibrationItem: NSMenuItem!
    private var badPostureStartTime: Date?
    private var notificationTimer: Timer?
    private var badPostureTimer: Timer?
    private var isMonitoring = false
    
    var bluetoothManager: BluetoothManager? {
        didSet {
            if bluetoothManager != nil {
                print("AppDelegate: BluetoothManager set successfully")
                setupBluetoothManager()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application did finish launching")
        requestNotificationPermissions()
        setupMenuBar()
        UNUserNotificationCenter.current().delegate = self
        
        if bluetoothManager == nil {
            bluetoothManager = BluetoothManager.shared
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: "Posture")
        }
        
        menu = NSMenu()
        
        // Status text item
        statusTextItem = NSMenuItem(title: "AirPods Not Connected", action: nil, keyEquivalent: "")
        menu.addItem(statusTextItem)
        
        // Posture position item
        posturePositionItem = NSMenuItem(title: "Posture Position: --", action: nil, keyEquivalent: "")
        menu.addItem(posturePositionItem)
        
        // Posture angle item
        postureAngleItem = NSMenuItem(title: "Posture Angle: --", action: nil, keyEquivalent: "")
        menu.addItem(postureAngleItem)
        
        // Calibration item
        calibrationItem = NSMenuItem(title: "Calibrating...", action: nil, keyEquivalent: "")
        calibrationItem.isHidden = true
        menu.addItem(calibrationItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Start/Stop item
        startStopItem = NSMenuItem(title: "Start Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
        startStopItem.target = self
        menu.addItem(startStopItem)
        
        // Calibrate item
        let calibrateItem = NSMenuItem(title: "Calibrate", action: #selector(recalibrate), keyEquivalent: "")
        calibrateItem.target = self
        menu.addItem(calibrateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func setupBluetoothManager() {
        guard let bluetoothManager = bluetoothManager else { return }
        
        print("AppDelegate: Setting up BluetoothManager callbacks")
        
        // Set up the posture update callback with explicit type annotation
        bluetoothManager.onPostureUpdate = { [weak self] (angle: Double) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.updateMenuBar()
            }
        }
        
        // Set up connection status callback with explicit type annotation
        bluetoothManager.onConnectionStatusChanged = { [weak self] (isConnected: Bool) in
            DispatchQueue.main.async {
                self?.statusTextItem.title = isConnected ? "AirPods Connected" : "AirPods Not Connected"
                if !isConnected {
                    self?.postureAngleItem.title = "Posture Angle: --"
                    self?.posturePositionItem.title = "Posture Position: --"
                    self?.calibrationItem.isHidden = true
                }
            }
        }
        
        // Set up calibration update callback
        bluetoothManager.onCalibrationUpdate = { [weak self] (progress: String) in
            DispatchQueue.main.async {
                self?.calibrationItem.title = progress
                self?.calibrationItem.isHidden = false
                if progress == "Calibration Complete" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.calibrationItem.isHidden = true
                    }
                }
            }
        }
        
        // Initial status update
        DispatchQueue.main.async { [weak self] in
            self?.statusTextItem.title = bluetoothManager.isConnected ? "AirPods Connected" : "AirPods Not Connected"
        }
    }
    
    private func updateMenuBar() {
        guard let bluetoothManager = bluetoothManager else { return }
        
        // Update menu items based on current status
        statusTextItem.title = bluetoothManager.isConnected ? "AirPods Connected" : "AirPods Not Connected"
        
        if bluetoothManager.isCalibrating {
            posturePositionItem.title = "Posture Position: Calibrating..."
            postureAngleItem.title = "Posture Angle: Calibrating..."
            return
        }
        
        // Update position text based on direction
        let direction = bluetoothManager.postureStatus.direction
        var positionText = "Posture Position: "
        switch direction {
        case .forward:
            positionText += "Looking Down"
        case .backward:
            positionText += "Looking Up"
        case .neutral:
            positionText += "Good Posture"
        case .left:
            positionText += "Looking Left"
        case .right:
            positionText += "Looking Right"
        }
        posturePositionItem.title = positionText
        
        // Update angle text
        postureAngleItem.title = String(format: "Posture Angle: %.1f°", bluetoothManager.currentNeckAngle)
        
        // Update menu bar icon based on posture
        if let button = statusItem.button {
            let imageName: String
            switch direction {
            case .neutral:
                imageName = "figure.stand"
            case .forward, .backward:
                imageName = "figure.walk.motion"
            case .left, .right:
                imageName = "arrow.left.and.right"
            }
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Posture")
        }
    }
    
    @objc func toggleMonitoring() {
        guard let bluetoothManager = bluetoothManager else {
            print("AppDelegate: BluetoothManager is nil")
            return
        }
        
        isMonitoring.toggle()
        print("AppDelegate: Toggling monitoring to \(isMonitoring)")
        
        if isMonitoring {
            startStopItem.title = "Stop Monitoring"
            bluetoothManager.startTracking()
            print("AppDelegate: Started tracking")
            
            // Show calibration status
            calibrationItem.isHidden = false
            posturePositionItem.title = "Posture Position: Calibrating"
        } else {
            startStopItem.title = "Start Monitoring"
            bluetoothManager.stopTracking()
            print("AppDelegate: Stopped tracking")
            
            // Reset UI
            postureAngleItem.title = "Posture Angle: --"
            posturePositionItem.title = "Posture Position: --"
            calibrationItem.isHidden = true
        }
    }
    
    @objc func recalibrate() {
        guard let bluetoothManager = bluetoothManager else { return }
        
        // Reset UI
        posturePositionItem.title = "Posture Position: Calibrating"
        postureAngleItem.title = "Posture Angle: --"
        calibrationItem.isHidden = false
        
        // Start calibration
        bluetoothManager.recalibrate()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func setBluetoothManager(_ manager: BluetoothManager) {
        self.bluetoothManager = manager
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
}
