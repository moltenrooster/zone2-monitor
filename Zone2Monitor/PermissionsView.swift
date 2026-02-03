import SwiftUI
import HealthKit
import CoreBluetooth

struct PermissionsView: View {
    @EnvironmentObject var settings: UserSettings
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Title
            VStack(spacing: 8) {
                Text("Before We Start")
                    .font(.system(size: 32, weight: .bold))
                Text("Zone2Monitor needs a couple permissions to work")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "heart.fill",
                    title: "Health Data",
                    description: "Read your heart rate during workouts",
                    status: permissionManager.healthStatus
                )
                
                PermissionCard(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Bluetooth",
                    description: "Connect to heart rate monitors",
                    status: permissionManager.bluetoothStatus
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action button
            VStack(spacing: 12) {
                if permissionManager.allPermissionsGranted {
                    Button(action: {
                        settings.hasCompletedOnboarding = true
                    }) {
                        Text("Let's Go!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                } else if permissionManager.anyPermissionDenied {
                    Button(action: openSettings) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(16)
                    }
                    
                    Text("Please enable permissions in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button(action: {
                        permissionManager.requestAllPermissions()
                    }) {
                        Text("Grant Permissions")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            permissionManager.checkPermissions()
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            statusIcon
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    var statusIcon: some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        case .notDetermined:
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .font(.title2)
        }
    }
}

enum PermissionStatus {
    case notDetermined, granted, denied
}

class PermissionManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var healthStatus: PermissionStatus = .notDetermined
    @Published var bluetoothStatus: PermissionStatus = .notDetermined
    
    private var centralManager: CBCentralManager?
    private let healthStore = HKHealthStore()
    
    var allPermissionsGranted: Bool {
        healthStatus == .granted && bluetoothStatus == .granted
    }
    
    var anyPermissionDenied: Bool {
        healthStatus == .denied || bluetoothStatus == .denied
    }
    
    func checkPermissions() {
        checkHealthPermission()
        checkBluetoothPermission()
    }
    
    func requestAllPermissions() {
        requestHealthPermission()
        requestBluetoothPermission()
    }
    
    // MARK: - Health
    
    private func checkHealthPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthStatus = .denied
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let status = healthStore.authorizationStatus(for: heartRateType)
        
        DispatchQueue.main.async {
            switch status {
            case .sharingAuthorized:
                self.healthStatus = .granted
            case .sharingDenied:
                self.healthStatus = .denied
            case .notDetermined:
                self.healthStatus = .notDetermined
            @unknown default:
                self.healthStatus = .notDetermined
            }
        }
    }
    
    private func requestHealthPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.healthStatus = success ? .granted : .denied
            }
        }
    }
    
    // MARK: - Bluetooth
    
    private func checkBluetoothPermission() {
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }
    
    private func requestBluetoothPermission() {
        // Creating the central manager triggers the permission request
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.bluetoothStatus = .granted
            case .unauthorized:
                self.bluetoothStatus = .denied
            case .poweredOff:
                // Bluetooth is off but permission might be granted
                self.bluetoothStatus = .granted
            default:
                self.bluetoothStatus = .notDetermined
            }
        }
    }
}

#Preview {
    PermissionsView()
        .environmentObject(UserSettings())
}
