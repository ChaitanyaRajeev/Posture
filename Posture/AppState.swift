import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var bluetoothManager = BluetoothManager.shared
    
    private init() {}
}
