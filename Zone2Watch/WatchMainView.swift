import SwiftUI
import HealthKit

struct WatchMainView: View {
    @StateObject private var workoutManager = WatchWorkoutManager()
    @AppStorage("userAge") private var userAge: Int = 40
    
    var zone2Range: (low: Int, high: Int) {
        let maxHR = 220 - userAge
        let low = Int(Double(maxHR) * 0.60)
        let high = Int(Double(maxHR) * 0.70)
        return (low, high)
    }
    
    var zoneStatus: (color: Color, message: String) {
        guard let hr = workoutManager.heartRate else {
            return (.gray, "--")
        }
        let bpm = Int(hr)
        if bpm < zone2Range.low {
            return (.blue, "PUSH HARDER")
        } else if bpm > zone2Range.high {
            return (.red, "SLOW DOWN")
        } else {
            return (.green, "PERFECT")
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if workoutManager.isWorkoutActive {
                // Active workout view
                Text(zoneStatus.message)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(zoneStatus.color)
                
                Text(workoutManager.heartRate != nil ? "\(Int(workoutManager.heartRate!))" : "--")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(zoneStatus.color)
                
                Text("BPM")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("Zone 2: \(zone2Range.low)-\(zone2Range.high)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { workoutManager.endWorkout() }) {
                    Text("END")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
            } else {
                // Start screen
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Zone 2")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("Target: \(zone2Range.low)-\(zone2Range.high) BPM")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: { workoutManager.startWorkout() }) {
                        Text("START")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

#Preview {
    WatchMainView()
}
