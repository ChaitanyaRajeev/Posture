//
//  PostureApp.swift
//  Posture
//
//  Created by Chaitanya Rajeev on 11/20/24.
//

import SwiftUI

@main
struct PostureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var bluetoothManager = BluetoothManager.shared
    
    var body: some Scene {
        WindowGroup {
            EmptyView() // We don't need a main window since we're using menu bar
        }
        .commands {
            // Add menu commands if needed
            CommandGroup(replacing: .newItem) { }
        }
    }
}
