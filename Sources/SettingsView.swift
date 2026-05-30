import SwiftUI
import ServiceManagement
public struct SettingsView: View {
    @AppStorage("scrollSpeedModifier") private var scrollSpeedModifier: Double = 1.0
    @AppStorage("pollingInterval") private var pollingInterval: Double = 2.0
    @AppStorage("textColorMode") private var textColorMode: String = "system"
    @AppStorage("enableDropdownUI") private var enableDropdownUI: Bool = true
    @AppStorage("smartScrollEnabled") private var smartScrollEnabled: Bool = false
    @AppStorage("enableBlurredBackground") private var enableBlurredBackground: Bool = true
    @AppStorage("enableHeaderAlbumArt") private var enableHeaderAlbumArt: Bool = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("General").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Polling Interval: \(pollingInterval, specifier: "%.1f")s")
                    Slider(value: $pollingInterval, in: 1.0...5.0, step: 0.5)
                    Text("How often to check for track updates.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scroll Speed Modifier: \(scrollSpeedModifier, specifier: "%.1f")x")
                    Slider(value: $scrollSpeedModifier, in: 0.5...3.0, step: 0.1)
                    Text("Higher is faster.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Appearance")
                    Picker("", selection: $textColorMode) {
                        Text("System").tag("system")
                        Text("Subtle").tag("subtle")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 8)
                
                Toggle("Enable Dropdown UI & Controls", isOn: $enableDropdownUI)
                
                Toggle("Smart Scroll (Beta)", isOn: $smartScrollEnabled)
                    
                Toggle("Show Blurred Background", isOn: $enableBlurredBackground)
                    
                Toggle("Show Album Art in Header", isOn: $enableHeaderAlbumArt)
                
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update launch at login: \(error)")
                            launchAtLogin = !newValue
                        }
                    }
            }
        }
        .padding(20)
        .frame(width: 380, height: 480)
    }
}
