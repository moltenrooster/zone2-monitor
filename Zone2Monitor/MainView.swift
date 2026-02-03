import SwiftUI

struct MainView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var heartRateManager: HeartRateManager
    @State private var showSettings = false
    @State private var heartBeat = false
    
    var zoneStatus: ZoneStatus {
        let hr = heartRateManager.heartRate
        if hr == 0 { return .noData }
        if hr > settings.zone2High + 2 { return .tooHigh }
        if hr < settings.zone2Low - 2 { return .tooLow }
        return .inZone
    }
    
    var statusColor: Color {
        switch zoneStatus {
        case .noData: return .gray
        case .tooHigh: return .red
        case .tooLow: return .yellow
        case .inZone: return .green
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color based on zone
                statusColor.opacity(0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Zone range display (top)
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Zone 2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(settings.zone2Low) - \(settings.zone2High)")
                                .font(.headline)
                                .foregroundColor(statusColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Main heart rate display
                    if heartRateManager.isConnected {
                        VStack(spacing: 16) {
                            // Heart icon
                            Image(systemName: "heart.fill")
                                .font(.system(size: 60))
                                .foregroundColor(statusColor)
                                .scaleEffect(heartBeat ? 1.2 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 0.3)
                                        .repeatForever(autoreverses: true),
                                    value: heartBeat
                                )
                                .onAppear { heartBeat = true }
                            
                            // Heart rate number
                            Text("\(heartRateManager.heartRate)")
                                .font(.system(size: 120, weight: .bold, design: .rounded))
                                .foregroundColor(statusColor)
                            
                            Text("bpm")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            // Status message
                            Text(statusMessage)
                                .font(.headline)
                                .foregroundColor(statusColor)
                                .padding(.top, 8)
                        }
                    } else {
                        // Connection UI
                        VStack(spacing: 24) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                            
                            if heartRateManager.isScanning {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    Text("Searching for heart rate monitor...")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Text("No heart rate monitor connected")
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: { heartRateManager.startScanning() }) {
                                        Label("Connect", systemImage: "antenna.radiowaves.left.and.right")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            
                            if let error = heartRateManager.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Device info (bottom)
                    if heartRateManager.isConnected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(heartRateManager.deviceName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Disconnect") {
                                heartRateManager.disconnect()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    var statusMessage: String {
        switch zoneStatus {
        case .noData: return "Waiting for data..."
        case .tooHigh: return "Slow down! Above Zone 2"
        case .tooLow: return "Pick it up! Below Zone 2"
        case .inZone: return "Perfect! In Zone 2"
        }
    }
}

enum ZoneStatus {
    case noData, tooHigh, tooLow, inZone
}
