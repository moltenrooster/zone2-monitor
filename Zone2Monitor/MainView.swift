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
        case .tooLow: return Color.blue.opacity(0.2)
        case .inZone: return Color.green.opacity(0.2)
        case .tooHigh: return Color.red.opacity(0.2)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Top bar with settings
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
                    
                    // Main heart rate display
                    VStack(spacing: 16) {
                        if let hr = heartRateManager.heartRate {
                            // Zone message
                            Text(zoneStatus.message)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(zoneStatus.color)
                            
                            // Big BPM number
                            Text("\(hr)")
                                .font(.system(size: 140, weight: .bold, design: .rounded))
                                .foregroundColor(zoneStatus.color)
                            
                            Text("BPM")
                                .font(.title)
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
                    
                    // Status bar at bottom
                    Text(heartRateManager.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Auto-start scanning when app opens
            heartRateManager.startScanning()
        }
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
