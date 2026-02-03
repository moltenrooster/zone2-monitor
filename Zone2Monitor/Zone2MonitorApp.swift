import SwiftUI

@main
struct Zone2MonitorApp: App {
    @StateObject private var settings = UserSettings()
    @StateObject private var heartRateManager = HeartRateManager()
    
    var body: some Scene {
        WindowGroup {
            if settings.hasCompletedOnboarding {
                MainView()
                    .environmentObject(settings)
                    .environmentObject(heartRateManager)
            } else {
                OnboardingView()
                    .environmentObject(settings)
            }
        }
    }
}
