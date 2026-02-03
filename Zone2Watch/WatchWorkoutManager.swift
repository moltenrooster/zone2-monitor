import Foundation
import HealthKit
import Combine
import AVFoundation
import WatchKit

enum ZoneState {
    case unknown
    case below
    case inZone
    case above
}

class WatchWorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    @Published var heartRate: Double?
    @Published var isWorkoutActive = false
    @Published var elapsedTime: TimeInterval = 0
    
    private var timer: Timer?
    private var startDate: Date?
    
    // Zone tracking for sound alerts
    private var currentZoneState: ZoneState = .unknown
    private var audioPlayer: AVAudioPlayer?
    
    // Zone boundaries (will be set from view)
    var zoneLow: Int = 100
    var zoneHigh: Int = 140
    
    func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            let startDate = Date()
            self.startDate = startDate
            
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isWorkoutActive = true
                        self.startTimer()
                    }
                }
            }
        } catch {
            print("Failed to start workout: \(error.localizedDescription)")
        }
    }
    
    func endWorkout() {
        workoutSession?.end()
        stopTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Zone Sound Alerts
    
    func updateZoneBoundaries(low: Int, high: Int) {
        zoneLow = low
        zoneHigh = high
    }
    
    private func checkZoneAndPlaySound(heartRate: Double) {
        let bpm = Int(heartRate)
        let newState: ZoneState
        
        if bpm < zoneLow {
            newState = .below
        } else if bpm > zoneHigh {
            newState = .above
        } else {
            newState = .inZone
        }
        
        // Only play sound on state transitions (not initial unknown state)
        if currentZoneState != .unknown && currentZoneState != newState {
            // Crossed into or out of zone
            if newState == .below && currentZoneState != .below {
                playSound(named: "below_zone")
                playHaptic(.directionDown)
            } else if newState == .above && currentZoneState != .above {
                playSound(named: "above_zone")
                playHaptic(.directionUp)
            }
            // No sound when entering the zone (that's the goal!)
        }
        
        currentZoneState = newState
    }
    
    private func playSound(named soundName: String) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "wav") else {
            print("Sound file not found: \(soundName).wav")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }
    
    private func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    func resetZoneState() {
        currentZoneState = .unknown
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isWorkoutActive = true
            case .ended:
                self.isWorkoutActive = false
                self.workoutBuilder?.endCollection(withEnd: date) { success, error in
                    self.workoutBuilder?.finishWorkout { workout, error in
                        // Workout saved
                    }
                }
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            
            if let value = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                DispatchQueue.main.async {
                    self.heartRate = value
                    self.checkZoneAndPlaySound(heartRate: value)
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}
