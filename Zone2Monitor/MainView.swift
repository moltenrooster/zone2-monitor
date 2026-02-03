import SwiftUI

struct MainView: View {
    @EnvironmentObject var settings: UserSettings
    @StateObject private var heartRateManager = HeartRateManager()
    
    // Timer for Zone 2+
    @State private var zone2Seconds: Int = 0
    @State private var timer: Timer?
    
    var zone2Range: (low: Int, high: Int) {
        // Use custom values if set, otherwise calculate from age
        if settings.hasCustomZone && settings.zone2Low > 0 && settings.zone2High > 0 {
            return (settings.zone2Low, settings.zone2High)
        } else {
            let maxHR = 220 - settings.userAge
            let low = Int(Double(maxHR) * 0.60)
            let high = Int(Double(maxHR) * 0.70)
            return (low, high)
        }
    }
    
    var zoneStatus: ZoneStatus {
        guard let hr = heartRateManager.heartRate else {
            return .unknown
        }
        if hr < zone2Range.low {
            return .tooLow
        } else if hr > zone2Range.high {
            return .tooHigh
        } else {
            return .inZone
        }
    }
    
    var backgroundColor: Color {
        switch zoneStatus {
        case .unknown: return Color(.systemBackground)
        case .tooLow: return Color.blue.opacity(0.2)
        case .inZone: return Color.green.opacity(0.2)
        case .tooHigh: return Color.red.opacity(0.2)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Top bar with settings
                    HStack {
                        // Zone 2+ time (main metric)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TIME IN ZONE 2+")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(formatTime(zone2Seconds))
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: SettingsView().environmentObject(settings)) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Zone indicator
                    VStack(spacing: 4) {
                        Text("Zone 2")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("\(zone2Range.low) - \(zone2Range.high)")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // Main heart rate display
                    VStack(spacing: 12) {
                        if let hr = heartRateManager.heartRate {
                            // Zone message
                            Text(zoneStatus.message)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(zoneStatus.color)
                            
                            // Big BPM number
                            Text("\(hr)")
                                .font(.system(size: 130, weight: .bold, design: .rounded))
                                .foregroundColor(zoneStatus.color)
                            
                            Text("BPM")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        } else {
                            // Connecting state
                            Image(systemName: "heart.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .opacity(0.5)
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            
                            Text(heartRateManager.connectionStatus)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                    
                    // Reset button
                    Button(action: resetTimers) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("RESET")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(25)
                    }
                    .padding(.bottom, 10)
                    
                    // Connection status
                    Text(heartRateManager.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            heartRateManager.startScanning()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Only count if we have a heart rate reading and in Zone 2+
            if heartRateManager.heartRate != nil {
                if zoneStatus == .inZone || zoneStatus == .tooHigh {
                    zone2Seconds += 1
                }
            }
        }
    }
    
    private func resetTimers() {
        zone2Seconds = 0
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

enum ZoneStatus {
    case unknown, tooLow, inZone, tooHigh
    
    var message: String {
        switch self {
        case .unknown: return ""
        case .tooLow: return "⬆️ PUSH HARDER"
        case .inZone: return "✅ PERFECT"
        case .tooHigh: return "⬇️ SLOW DOWN"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .tooLow: return .blue
        case .inZone: return .green
        case .tooHigh: return .red
        }
    }
}

#Preview {
    MainView()
        .environmentObject(UserSettings())
}
