import SwiftUI

class UserSettings: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("userAge") var userAge: Int = 40
    @AppStorage("zone2Low") var zone2Low: Int = 0
    @AppStorage("zone2High") var zone2High: Int = 0
    @AppStorage("hasCustomZone") var hasCustomZone: Bool = false
    
    // Zone 2 calculation using Maffetone formula (180 - age) as base
    // Zone 2 typically spans about 10 bpm
    func calculateZone2(forAge age: Int) -> (low: Int, high: Int) {
        // Using heart rate reserve method approximation
        // Zone 2 is typically 60-70% of max HR
        // Max HR estimate: 220 - age (or 180 - age for MAF method)
        let maxHR = 220 - age
        let low = Int(Double(maxHR) * 0.60)
        let high = Int(Double(maxHR) * 0.70)
        return (low, high)
    }
    
    func setZoneFromAge() {
        let zone = calculateZone2(forAge: userAge)
        zone2Low = zone.low
        zone2High = zone.high
        hasCustomZone = false
    }
    
    func resetToEstimate() {
        setZoneFromAge()
    }
}
