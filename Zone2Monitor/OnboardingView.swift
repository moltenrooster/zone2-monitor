import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: UserSettings
    @State private var age: String = "40"
    @State private var showEstimate = false
    
    var estimatedZone: (low: Int, high: Int) {
        settings.calculateZone2(forAge: Int(age) ?? 40)
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
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
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
            }
            
            Spacer()
            
            // Continue button
            Button(action: completeOnboarding) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .disabled(Int(age) == nil || Int(age)! <= 0 || Int(age)! >= 120)
        }
        .padding()
    }
    
    private func completeOnboarding() {
        guard let ageInt = Int(age) else { return }
        settings.userAge = ageInt
        settings.setZoneFromAge()
        settings.hasCompletedOnboarding = true
    }
}
