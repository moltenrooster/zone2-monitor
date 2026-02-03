import Foundation
import CoreBluetooth
import Combine

class HeartRateManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?
    
    // Standard Bluetooth Heart Rate Service UUID
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")
    
    @Published var heartRate: Int?
    @Published var isMonitoring = false
    @Published var connectionStatus: String = "Ready"
    @Published var lastUpdate: Date?
    @Published var discoveredDevices: [CBPeripheral] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionStatus = "Bluetooth is off"
            return
        }
        
        isMonitoring = true
        connectionStatus = "Scanning for heart rate monitors..."
        discoveredDevices = []
        
        // First, check for already-connected devices
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID])
        
        if !connectedPeripherals.isEmpty {
            connectionStatus = "Found connected device!"
            for peripheral in connectedPeripherals {
                discoveredDevices.append(peripheral)
                // Auto-connect to first found device
                connectTo(peripheral)
                return
            }
        }
        
        // If no connected devices, scan for new ones
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.heartRatePeripheral == nil {
                self?.centralManager.stopScan()
                if self?.discoveredDevices.isEmpty == true {
                    self?.connectionStatus = "No heart rate monitors found. Make sure your Polar is on!"
                }
            }
        }
    }
    
    func connectTo(_ peripheral: CBPeripheral) {
        heartRatePeripheral = peripheral
        peripheral.delegate = self
        centralManager.stopScan()
        connectionStatus = "Connecting to \(peripheral.name ?? "device")..."
        centralManager.connect(peripheral, options: nil)
    }
    
    func stopMonitoring() {
        centralManager.stopScan()
        
        if let peripheral = heartRatePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        heartRatePeripheral = nil
        isMonitoring = false
        heartRate = nil
        connectionStatus = "Stopped"
        discoveredDevices = []
    }
}

// MARK: - CBCentralManagerDelegate
extension HeartRateManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth ready"
        case .poweredOff:
            connectionStatus = "Turn on Bluetooth"
        case .unauthorized:
            connectionStatus = "Bluetooth not authorized"
        case .unsupported:
            connectionStatus = "Bluetooth not supported"
        default:
            connectionStatus = "Bluetooth unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Add to discovered list if not already there
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
            connectionStatus = "Found: \(peripheral.name ?? "Unknown device")"
            
            // Auto-connect to Polar devices
            if let name = peripheral.name?.lowercased(), name.contains("polar") {
                connectTo(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Connected to \(peripheral.name ?? "device")!"
        peripheral.discoverServices([heartRateServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        isMonitoring = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Disconnected"
        heartRate = nil
        
        // Try to reconnect
        if isMonitoring {
            connectionStatus = "Reconnecting..."
            centralManager.connect(peripheral, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension HeartRateManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == heartRateServiceUUID {
                peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == heartRateMeasurementUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                connectionStatus = "❤️ Live heart rate active"
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == heartRateMeasurementUUID,
              let data = characteristic.value else { return }
        
        let heartRateValue = parseHeartRate(from: data)
        
        DispatchQueue.main.async {
            self.heartRate = heartRateValue
            self.lastUpdate = Date()
            self.connectionStatus = "❤️ Live from \(peripheral.name ?? "HRM")"
        }
    }
    
    private func parseHeartRate(from data: Data) -> Int {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return 0 }
        
        // First byte contains flags
        let flags = bytes[0]
        let is16Bit = (flags & 0x01) != 0
        
        if is16Bit && bytes.count >= 3 {
            return Int(bytes[1]) | (Int(bytes[2]) << 8)
        } else if bytes.count >= 2 {
            return Int(bytes[1])
        }
        
        return 0
    }
}
