import Foundation
import HealthKit
import Combine

class HeartRateManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    
    @Published var heartRate: Int?
    @Published var isMonitoring = false
    @Published var connectionStatus: String = "Not started"
    @Published var lastUpdate: Date?
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isHealthKitAvailable else {
            connectionStatus = "HealthKit not available"
            completion(false)
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.connectionStatus = "HealthKit authorized"
                } else {
                    self.connectionStatus = "Authorization denied"
                }
                completion(success)
            }
        }
    }
    
    func startMonitoring() {
        guard isHealthKitAvailable else {
            connectionStatus = "HealthKit not available on this device"
            return
        }
        
        isMonitoring = true
        connectionStatus = "Connecting to HealthKit..."
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Query for the most recent heart rate
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // First, get the most recent heart rate
        let recentQuery = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    let value = sample.quantity.doubleValue(for: heartRateUnit)
                    self.heartRate = Int(value)
                    self.lastUpdate = sample.startDate
                    self.connectionStatus = "Reading from HealthKit"
                } else {
                    self.connectionStatus = "No heart rate data found. Start a workout with your Polar!"
                }
            }
        }
        
        healthStore.execute(recentQuery)
        
        // Set up anchored query for live updates
        let anchorDate = Date().addingTimeInterval(-60) // Look back 1 minute
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: nil, options: .strictStartDate)
        
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        heartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        if let query = heartRateQuery {
            healthStore.execute(query)
            DispatchQueue.main.async {
                self.connectionStatus = "Monitoring for live heart rate..."
            }
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample],
              let mostRecent = heartRateSamples.last else { return }
        
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let value = mostRecent.quantity.doubleValue(for: heartRateUnit)
        
        DispatchQueue.main.async {
            self.heartRate = Int(value)
            self.lastUpdate = mostRecent.startDate
            self.connectionStatus = "Live from HealthKit"
        }
    }
    
    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.connectionStatus = "Stopped"
        }
    }
}
