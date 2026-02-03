# Zone 2 Heart Rate Monitor

Simple iOS app that connects to any Bluetooth heart rate monitor and helps you stay in Zone 2.

## Features

- **Bluetooth HRM Support**: Works with any standard Bluetooth heart rate monitor (Polar, Garmin, Wahoo, Apple Watch, etc.)
- **Age-Based Zone Estimation**: Enter your age to get Zone 2 estimates (60-70% of max HR)
- **Custom Overrides**: Adjust your Zone 2 range if you know your actual numbers
- **Visual Feedback**:
  - 🟢 **Green**: In Zone 2
  - 🟡 **Yellow**: Below Zone 2 by 2+ bpm
  - 🔴 **Red**: Above Zone 2 by 2+ bpm
- **Blinking Heart**: Visual heartbeat indicator
- **Big Numbers**: Easy to see during workouts

## Setup in Xcode

1. Open Xcode → File → New → Project
2. Choose **App** (iOS)
3. Product Name: `Zone2Monitor`
4. Interface: **SwiftUI**
5. Language: **Swift**

### Add the files:

Copy all `.swift` files into your project:
- `Zone2MonitorApp.swift`
- `UserSettings.swift`
- `HeartRateManager.swift`
- `OnboardingView.swift`
- `MainView.swift`
- `SettingsView.swift`

### Configure Bluetooth permissions:

In your project's **Info.plist**, add:
- `NSBluetoothAlwaysUsageDescription` → "Zone 2 Monitor needs Bluetooth to connect to your heart rate monitor."
- `NSBluetoothPeripheralUsageDescription` → "Zone 2 Monitor needs Bluetooth to connect to your heart rate monitor."

Or copy the provided `Info.plist` entries.

### Enable Background Bluetooth (optional):

In **Signing & Capabilities** → Add "Background Modes" → Check "Uses Bluetooth LE accessories"

## Usage

1. **First Launch**: Enter your age to estimate Zone 2
2. **Connect**: Tap "Connect" to find your heart rate monitor
3. **Train**: Keep the screen green!
4. **Adjust**: Go to Settings (gear icon) to fine-tune your zones

## Zone 2 Calculation

Default formula: `Max HR = 220 - age`, Zone 2 = 60-70% of Max HR

Example for age 45:
- Max HR = 175
- Zone 2 Low = 105 bpm
- Zone 2 High = 122 bpm

Override these in Settings if you have actual test data.

## Requirements

- iOS 15.0+
- Xcode 14+
- Bluetooth heart rate monitor

## Future Ideas

- Apple Watch app
- Workout history
- Audio cues (beeps when out of zone)
- Haptic feedback
- Integration with Animal Zone 2 workouts

---

Built for @thelongevitydude / Longevity Athlete
