import AppKit
import SwiftUI

@MainActor
public final class MenuBarEngine: NSObject {
    private var statusItem: NSStatusItem!
    private var areLyricsEnabled: Bool = true
    private var baseLogoImageDark: NSImage?
    private var baseLogoImageLight: NSImage?
    private var logoRotationAngle: CGFloat = 0.0
    private let bridge: MediaBridge
    
    private var popover: NSPopover!
    private var rightClickMenu: NSMenu!
    
    private var latestState: PlayerState = .notRunning
    private var latestLyrics: [LyricLine] = []
    private var latestPosition: Double = 0
    
    public init(bridge: MediaBridge) {
        self.bridge = bridge
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = getVinylIcon(isPlaying: false)
            button.imagePosition = .imageLeft
            button.lineBreakMode = .byClipping
            button.alignment = .left
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        setupPopoverAndMenu()
    }
    
    private func getMusicIcon() -> NSImage? {
        let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music")
        image?.isTemplate = true
        return image
    }
    
    private func getVinylIcon(isPlaying: Bool) -> NSImage? {
        let isDark: Bool
        if #available(macOS 10.14, *) {
            isDark = statusItem.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDark = false
        }
        
        let targetLogoName = isDark ? "Logo - white" : "Logo - black"
        
        var activeImage: NSImage?
        if isDark {
            if baseLogoImageDark == nil {
                if let url = Bundle.module.url(forResource: targetLogoName, withExtension: "png") ?? Bundle.main.url(forResource: targetLogoName, withExtension: "png") {
                    baseLogoImageDark = loadAndResizeImage(from: url)
                }
            }
            activeImage = baseLogoImageDark
        } else {
            if baseLogoImageLight == nil {
                if let url = Bundle.module.url(forResource: targetLogoName, withExtension: "png") ?? Bundle.main.url(forResource: targetLogoName, withExtension: "png") {
                    baseLogoImageLight = loadAndResizeImage(from: url)
                }
            }
            activeImage = baseLogoImageLight
        }
        
        guard let img = activeImage else {
            return getMusicIcon()
        }
        
        if isPlaying {
            logoRotationAngle += 15.0 // 15 degrees per 100ms update
            if logoRotationAngle >= 360 {
                logoRotationAngle -= 360
            }
        }
        
        return img.rotated(by: logoRotationAngle)
    }
    
    private func loadAndResizeImage(from url: URL) -> NSImage? {
        guard let img = NSImage(contentsOf: url) else { return nil }
        let size = NSSize(width: 18, height: 18)
        let resized = NSImage(size: size)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        img.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: img.size), operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        return resized
    }
    
    private func setupPopoverAndMenu() {
        rightClickMenu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: "Show Lyrics",
            action: #selector(toggleLyrics(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = areLyricsEnabled ? .on : .off
        rightClickMenu.addItem(toggleItem)
        
        rightClickMenu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences(_:)),
            keyEquivalent: ","
        )
        prefsItem.target = self
        rightClickMenu.addItem(prefsItem)
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        rightClickMenu.addItem(quitItem)
        
        popover = NSPopover()
        popover.behavior = .transient
        updatePopoverContent()
    }
    
    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        let enableDropdown = UserDefaults.standard.object(forKey: "enableDropdownUI") == nil ? true : UserDefaults.standard.bool(forKey: "enableDropdownUI")
        
        if event.type == .rightMouseUp || !enableDropdown {
            rightClickMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
        } else {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                updatePopoverContent()
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    private func updatePopoverContent() {
        var currentTrack: Track? = nil
        var isPlaying = false
        if case let .playing(t, _) = latestState {
            currentTrack = t
            isPlaying = true
        } else if case let .paused(t, _) = latestState {
            currentTrack = t
            isPlaying = false
        }
        
        let view = LyricsDropdownView(
            currentTrack: currentTrack,
            isPlaying: isPlaying,
            lyrics: latestLyrics,
            currentPosition: latestPosition,
            bridge: bridge
        )
        
        if popover.contentViewController == nil {
            popover.contentViewController = NSHostingController(rootView: view)
        } else if let hosting = popover.contentViewController as? NSHostingController<LyricsDropdownView> {
            hosting.rootView = view
        }
    }
    
    @objc private func showPreferences(_ sender: NSMenuItem) {
        SettingsWindowManager.shared.showWindow()
    }
    
    @objc private func toggleLyrics(_ sender: NSMenuItem) {
        areLyricsEnabled.toggle()
        sender.state = areLyricsEnabled ? .on : .off
    }
    
    public func update(state: PlayerState, lyrics: [LyricLine], status: LyricsStatus, lastUpdated: Date) {
        latestState = state
        latestLyrics = lyrics
        let currentPos = getCurrentPosition(state: state, lastUpdated: lastUpdated)
        latestPosition = currentPos
        
        if popover.isShown {
            updatePopoverContent()
        }
        
        let title: String
        var showOnlyIcon = false
        var needsScroll = false
        
        if !areLyricsEnabled {
            title = ""
            showOnlyIcon = true
        } else if !state.isPlaying {
            title = ""
            showOnlyIcon = true
        } else {
            switch status {
            case .none, .loading:
                if case let .playing(track, _) = state {
                    title = track.title
                } else {
                    title = ""
                }
            case .notFound, .error:
                title = ""
                showOnlyIcon = true
            case .loaded:
                let activeIdx = activeLyricIndex(for: currentPos, in: lyrics)
                
                if let activeIdx = activeIdx, activeIdx < lyrics.count {
                    let lyricText = lyrics[activeIdx].text
                        .replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "\r", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if lyricText.isEmpty || lyricText.hasPrefix("[") {
                        title = ""
                        showOnlyIcon = true
                    } else {
                        let tStart = lyrics[activeIdx].timestamp
                        let tEnd: TimeInterval
                        if activeIdx + 1 < lyrics.count {
                            tEnd = lyrics[activeIdx + 1].timestamp
                        } else {
                            if case let .playing(track, _) = state {
                                tEnd = track.duration > tStart ? track.duration : tStart + 8.0
                            } else {
                                tEnd = tStart + 8.0
                            }
                        }
                        
                        let lineDuration = max(1.0, tEnd - tStart)
                        let elapsed = max(0.0, currentPos - tStart)
                        
                        let font = statusItem.button?.font ?? NSFont.systemFont(ofSize: 13.0)
                        
                        // Use 250.0 instead of 350.0 to prevent the notch from hiding the item.
                        // Pass 200.0 as maxWidth for the text calculation to leave room for the icon, padding, and leading spaces.
                        let scrollResult = getScrolledTitle(lyricText, maxWidth: 200.0, font: font, elapsed: elapsed, duration: lineDuration)
                        title = scrollResult.title
                        needsScroll = scrollResult.needsScrolling
                    }
                } else {
                    title = ""
                    showOnlyIcon = true
                }
            }
        }
        if let button = statusItem.button {
            if showOnlyIcon || title.isEmpty {
                statusItem.length = NSStatusItem.squareLength
                button.title = ""
                button.image = getVinylIcon(isPlaying: state.isPlaying)
            } else {
                // Always use fixed length to prevent layout shifts which jar the popover
                statusItem.length = 250.0
                
                let textColorMode = UserDefaults.standard.string(forKey: "textColorMode") ?? "system"
                if textColorMode == "subtle" {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .font: button.font ?? NSFont.systemFont(ofSize: 13.0)
                    ]
                    button.attributedTitle = NSAttributedString(string: "  " + title, attributes: attrs)
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor.labelColor,
                        .font: button.font ?? NSFont.systemFont(ofSize: 13.0)
                    ]
                    button.attributedTitle = NSAttributedString(string: "  " + title, attributes: attrs)
                }
                
                button.image = getVinylIcon(isPlaying: state.isPlaying)
            }
        }
    }
    
    private func getScrolledTitle(_ text: String, maxWidth: CGFloat, font: NSFont, elapsed: Double, duration: Double) -> (title: String, needsScrolling: Bool) {
        let fullWidth = getStringWidth(text, font: font)
        if fullWidth <= maxWidth {
            return (text, false)
        }
        
        let pauseRatio = 0.2
        let speedModifier = UserDefaults.standard.double(forKey: "scrollSpeedModifier") > 0 ? UserDefaults.standard.double(forKey: "scrollSpeedModifier") : 1.0
        let scrollDuration = max(0.1, duration * (1.0 - pauseRatio)) / speedModifier
        let adjustedElapsed = max(0.0, elapsed - (duration * pauseRatio / 2.0))
        
        var progress = adjustedElapsed / scrollDuration
        if progress < 0 { progress = 0 }
        if progress > 1 { progress = 1 }
        
        var maxStartIndex = 0
        var currentIndex = text.startIndex
        for i in 0..<text.count {
            let sub = String(text[currentIndex...])
            if getStringWidth(sub, font: font) <= maxWidth {
                maxStartIndex = i
                break
            }
            text.formIndex(after: &currentIndex)
        }
        
        let shift = Int(progress * Double(maxStartIndex))
        let startIndex = text.index(text.startIndex, offsetBy: shift)
        
        var endIndex = startIndex
        while endIndex < text.endIndex {
            let nextIndex = text.index(after: endIndex)
            let sub = String(text[startIndex..<nextIndex])
            if getStringWidth(sub, font: font) > maxWidth {
                break
            }
            endIndex = nextIndex
        }
        
        return (String(text[startIndex..<endIndex]), true)
    }
    
    private func getStringWidth(_ text: String, font: NSFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return (text as NSString).size(withAttributes: attributes).width
    }
    
    private func getCurrentPosition(state: PlayerState, lastUpdated: Date) -> TimeInterval {
        if case let .playing(_, position) = state {
            let elapsed = Date().timeIntervalSince(lastUpdated)
            return position + elapsed
        }
        if case let .paused(_, position) = state {
            return position
        }
        return 0
    }
    
    private func activeLyricIndex(for position: Double, in lyrics: [LyricLine]) -> Int? {
        guard !lyrics.isEmpty else { return nil }
        var activeIndex: Int? = nil
        for (index, line) in lyrics.enumerated() {
            if line.timestamp <= position {
                activeIndex = index
            } else {
                break
            }
        }
        return activeIndex
    }
}

extension NSImage {
    func rotated(by degrees: CGFloat) -> NSImage {
        let imageSize = self.size
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return self
        }
        
        context.translateBy(x: imageSize.width / 2, y: imageSize.height / 2)
        context.rotate(by: -degrees * .pi / 180)
        context.translateBy(x: -imageSize.width / 2, y: -imageSize.height / 2)
        
        self.draw(in: NSRect(origin: .zero, size: imageSize))
        
        image.unlockFocus()
        return image
    }
}
