import SwiftUI

struct MainView: View {
    @EnvironmentObject var settings: UserSettings
    @StateObject private var heartRateManager = HeartRateManager()
    
    var zone2Range: (low: Int, high: Int) {
        let maxHR = 220 - settings.userAge
        let low = Int(Double(maxHR) * 0.60)
        let high = Int(Double(maxHR) * 0.70)
        return (low, high)
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
        case .tooLow: return Color.blue.opacity(0.15)
        case .inZone: return Color.green.opacity(0.15)
        case .tooHigh: return Color.red.opacity(0.15)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Settings button
                    HStack {
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
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // Heart rate display
                    VStack(spacing: 16) {
                        if heartRateManager.isMonitoring {
                            // Zone message
                            Text(zoneStatus.message)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(zoneStatus.color)
                            
                            // BPM
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(heartRateManager.heartRate != nil ? "\(heartRateManager.heartRate!)" : "--")
                                    .font(.system(size: 120, weight: .bold, design: .rounded))
                                    .foregroundColor(zoneStatus.color)
                                
                                Text("BPM")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Status
                            Text(heartRateManager.connectionStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let lastUpdate = heartRateManager.lastUpdate {
                                Text("Updated: \(lastUpdate, style: .relative) ago")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Not monitoring
                            Image(systemName: "heart.slash")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                            
                            Text("Tap Start to begin")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Start/Stop button
                    Button(action: toggleMonitoring) {
                        HStack {
                            Image(systemName: heartRateManager.isMonitoring ? "stop.fill" : "play.fill")
                            Text(heartRateManager.isMonitoring ? "Stop" : "Start")
                                .fontWeight(.semibold)
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(heartRateManager.isMonitoring ? Color.red : Color.green)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            heartRateManager.requestAuthorization { _ in }
        }
    }
    
    private func toggleMonitoring() {
        if heartRateManager.isMonitoring {
            heartRateManager.stopMonitoring()
        } else {
            heartRateManager.requestAuthorization { success in
                if success {
                    heartRateManager.startMonitoring()
                }
            }
        }
    }
}

enum ZoneStatus {
    case unknown, tooLow, inZone, tooHigh
    
    var message: String {
        switch self {
        case .unknown: return "Waiting..."
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
