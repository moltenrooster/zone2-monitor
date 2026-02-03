import Foundation
import HealthKit
import CoreBluetooth

class HeartRateManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
    
    @Published var heartRate: Int?
    @Published var isMonitoring = false
    @Published var connectionStatus: String = "Starting..."
    @Published var lastUpdate: Date?
    
    override init() {
        super.init()
    }
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func startScanning() {
        guard isHealthKitAvailable else {
            connectionStatus = "HealthKit not available"
            return
        }
        
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        connectionStatus = "Requesting HealthKit access..."
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.startHeartRateQuery()
                } else {
                    self?.connectionStatus = "Please allow Health access in Settings → Privacy → Health → Zone 2"
                }
            }
        }
    }
    
    private func startHeartRateQuery() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        isMonitoring = true
        connectionStatus = "Connecting to HealthKit..."
        
        // Get most recent heart rate first
        fetchMostRecentHeartRate()
        
        // Set up observer for new heart rate data
        heartRateQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            self?.fetchMostRecentHeartRate()
            completionHandler()
        }
        
        if let query = heartRateQuery {
            healthStore.execute(query)
        }
        
        // Also set up anchored query for real-time updates
        let anchorDate = Date().addingTimeInterval(-60)
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: nil, options: .strictStartDate)
        
        anchoredQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        anchoredQuery?.updateHandler = { [weak self] query, samples, deleted, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        if let query = anchoredQuery {
            healthStore.execute(query)
        }
        
        // Poll every 2 seconds as backup
        startPolling()
    }
    
    private var pollTimer: Timer?
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchMostRecentHeartRate()
        }
    }
    
    private func fetchMostRecentHeartRate() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // Only look at data from the last 30 seconds
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        let predicate = HKQuery.predicateForSamples(withStart: thirtySecondsAgo, end: nil, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            self?.processHeartRateSamples(samples)
        }
        
        healthStore.execute(query)
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample],
              let mostRecent = heartRateSamples.first else {
            // No recent samples - check if data is stale
            DispatchQueue.main.async {
                if let lastUpdate = self.lastUpdate {
                    let age = Date().timeIntervalSince(lastUpdate)
                    if age > 10 {
                        // Data is stale - clear heart rate and show disconnected
                        self.heartRate = nil
                        self.connectionStatus = "📡 Signal lost - check HR monitor"
                    }
                } else {
                    self.connectionStatus = "Waiting for heart rate..."
                }
            }
            return
        }
        
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let value = mostRecent.quantity.doubleValue(for: heartRateUnit)
        let sampleDate = mostRecent.startDate
        
        DispatchQueue.main.async {
            // Only update if this is newer data
            if self.lastUpdate == nil || sampleDate > self.lastUpdate! {
                self.heartRate = Int(value)
                self.lastUpdate = sampleDate
                
                // Check how fresh the data is
                let age = Date().timeIntervalSince(sampleDate)
                if age < 5 {
                    self.connectionStatus = "❤️ Live"
                } else if age < 10 {
                    self.connectionStatus = "❤️ Updated \(Int(age))s ago"
                } else {
                    // Data is getting stale
                    self.heartRate = nil
                    self.connectionStatus = "📡 Signal lost - check HR monitor"
                }
            } else {
                // No new data - check staleness
                if let lastUpdate = self.lastUpdate {
                    let age = Date().timeIntervalSince(lastUpdate)
                    if age > 10 {
                        self.heartRate = nil
                        self.connectionStatus = "📡 Signal lost - check HR monitor"
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        if let query = anchoredQuery {
            healthStore.stop(query)
        }
        pollTimer?.invalidate()
        
        isMonitoring = false
        heartRate = nil
        connectionStatus = "Stopped"
    }
}
