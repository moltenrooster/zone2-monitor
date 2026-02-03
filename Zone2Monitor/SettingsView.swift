import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: UserSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var lowZone: String = ""
    @State private var highZone: String = ""
    @State private var age: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Zone 2 Range")) {
                    HStack {
                        Text("Low")
                        Spacer()
                        TextField("Low", text: $lowZone)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("bpm")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("High")
                        Spacer()
                        TextField("High", text: $highZone)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("bpm")
                            .foregroundColor(.secondary)
                    }
                    
                    if settings.hasCustomZone {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Using custom values")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section(header: Text("Age-Based Estimate")) {
                    HStack {
                        Text("Your Age")
                        Spacer()
                        TextField("Age", text: $age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    if let ageInt = Int(age), ageInt > 0 && ageInt < 120 {
                        let estimate = settings.calculateZone2(forAge: ageInt)
                        HStack {
                            Text("Estimated Zone 2")
                            Spacer()
                            Text("\(estimate.low) - \(estimate.high) bpm")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: resetToEstimate) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Age Estimate")
                        }
                    }
                }
                
                Section(header: Text("About Zone 2")) {
                    Text("Zone 2 is typically 60-70% of your maximum heart rate. This is the aerobic zone where you build endurance and burn fat efficiently.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("The 2 bpm buffer helps account for natural heart rate variability.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                lowZone = String(settings.zone2Low)
                highZone = String(settings.zone2High)
                age = String(settings.userAge)
            }
        }
    }
    
    private func saveSettings() {
        if let low = Int(lowZone), let high = Int(highZone), let ageInt = Int(age) {
            settings.zone2Low = low
            settings.zone2High = high
            settings.userAge = ageInt
            
            // Check if custom (different from estimate)
            let estimate = settings.calculateZone2(forAge: ageInt)
            settings.hasCustomZone = (low != estimate.low || high != estimate.high)
        }
        dismiss()
    }
    
    private func resetToEstimate() {
        if let ageInt = Int(age) {
            settings.userAge = ageInt
            let estimate = settings.calculateZone2(forAge: ageInt)
            lowZone = String(estimate.low)
            highZone = String(estimate.high)
            settings.hasCustomZone = false
        }
    }
}
