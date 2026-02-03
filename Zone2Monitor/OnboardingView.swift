import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: UserSettings
    @State private var age: String = "40"
    @State private var showEstimate = false
    @State private var showPermissions = false
    @FocusState private var isAgeFocused: Bool
    
    var estimatedZone: (low: Int, high: Int) {
        settings.calculateZone2(forAge: Int(age) ?? 40)
    }
    
    var body: some View {
        if showPermissions {
            PermissionsView()
                .environmentObject(settings)
        } else {
            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 60)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Zone 2")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("Heart Rate Monitor")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Age input
                    VStack(spacing: 16) {
                        Text("Enter your age")
                            .font(.headline)
                        
                        TextField("Age", text: $age)
                            .keyboardType(.numberPad)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(width: 150)
                            .focused($isAgeFocused)
                            .onChange(of: age) { _ in
                                showEstimate = true
                            }
                    }
                    
                    // Zone estimate
                    if showEstimate, let ageInt = Int(age), ageInt > 0 && ageInt < 120 {
                        VStack(spacing: 8) {
                            Text("Your estimated Zone 2:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(estimatedZone.low) - \(estimatedZone.high) bpm")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    Spacer(minLength: 40)
                    
                    // Continue button
                    Button(action: {
                        isAgeFocused = false
                        saveAgeAndContinue()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                    .disabled(Int(age) == nil || Int(age)! <= 0 || Int(age)! >= 120)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .onTapGesture {
                isAgeFocused = false
            }
        }
    }
    
    private func saveAgeAndContinue() {
        guard let ageInt = Int(age) else { return }
        settings.userAge = ageInt
        settings.setZoneFromAge()
        showPermissions = true
    }
}
