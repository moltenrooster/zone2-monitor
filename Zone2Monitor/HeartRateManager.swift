import Foundation
import HealthKit
import Combine

class HeartRateManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?
    
    @Published var heartRate: Int?
    @Published var isMonitoring = false
    @Published var connectionStatus: String = "Ready"
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
        let workoutType = HKObjectType.workoutType()
        
        let typesToRead: Set<HKObjectType> = [heartRateType, workoutType]
        let typesToWrite: Set<HKSampleType> = [heartRateType, workoutType]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.connectionStatus = "HealthKit authorized"
                } else {
                    self.connectionStatus = "Please allow Health access in Settings"
                }
                completion(success)
            }
        }
    }
    
    func startMonitoring() {
        guard isHealthKitAvailable else {
            connectionStatus = "HealthKit not available"
            return
        }
        
        connectionStatus = "Starting workout session..."
        
        // Start a workout session to get live heart rate
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.isMonitoring = true
                        self.connectionStatus = "Waiting for heart rate..."
                    } else {
                        self.connectionStatus = "Failed to start: \(error?.localizedDescription ?? "Unknown")"
                    }
                }
            }
        } catch {
            connectionStatus = "Error: \(error.localizedDescription)"
        }
    }
    
    func stopMonitoring() {
        workoutSession?.end()
        
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.connectionStatus = "Stopped"
            self.heartRate = nil
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension HeartRateManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.connectionStatus = "Workout active - reading heart rate..."
            case .ended:
                self.workoutBuilder?.endCollection(withEnd: date) { success, error in
                    self.workoutBuilder?.finishWorkout { workout, error in
                        DispatchQueue.main.async {
                            self.isMonitoring = false
                            self.connectionStatus = "Workout ended"
                        }
                    }
                }
            case .paused:
                self.connectionStatus = "Paused"
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.connectionStatus = "Error: \(error.localizedDescription)"
            self.isMonitoring = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension HeartRateManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            
            if let value = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                DispatchQueue.main.async {
                    self.heartRate = Int(value)
                    self.lastUpdate = Date()
                    self.connectionStatus = "❤️ Live from Polar"
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle events if needed
    }
}
