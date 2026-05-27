import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowManager {
    public static let shared = SettingsWindowManager()
    
    private var settingsWindow: NSWindow?
    
    private init() {}
    
    public func showWindow() {
        if settingsWindow == nil {
            let view = SettingsView()
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 350),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.title = "Vinyl Settings"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
