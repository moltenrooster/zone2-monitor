import Foundation
import CoreBluetooth

class HeartRateManager: NSObject, ObservableObject {
    @Published var heartRate: Int = 0
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var deviceName: String = ""
    @Published var errorMessage: String?
    
    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?
    
    // Standard Bluetooth Heart Rate Service UUID
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            errorMessage = "Bluetooth is not available"
            return
        }
        isScanning = true
        errorMessage = nil
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)
    }
    
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }
    
    func disconnect() {
        if let peripheral = heartRatePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        heartRatePeripheral = nil
        isConnected = false
        deviceName = ""
        heartRate = 0
    }
}

extension HeartRateManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            errorMessage = nil
        case .poweredOff:
            errorMessage = "Bluetooth is turned off"
        case .unauthorized:
            errorMessage = "Bluetooth permission denied"
        case .unsupported:
            errorMessage = "Bluetooth not supported"
        default:
            errorMessage = "Bluetooth unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        heartRatePeripheral = peripheral
        deviceName = peripheral.name ?? "Heart Rate Monitor"
        centralManager.stopScan()
        isScanning = false
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices([heartRateServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        heartRate = 0
        // Try to reconnect
        if let peripheral = heartRatePeripheral {
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        errorMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        isConnected = false
    }
}

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
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == heartRateMeasurementUUID,
              let data = characteristic.value else { return }
        
        let heartRate = parseHeartRate(from: data)
        DispatchQueue.main.async {
            self.heartRate = heartRate
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
