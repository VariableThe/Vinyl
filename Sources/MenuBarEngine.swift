import AppKit

@MainActor
public final class MenuBarEngine: NSObject {
    private var statusItem: NSStatusItem!
    private var areLyricsEnabled: Bool = true
    
    public override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = getMusicIcon()
            button.imagePosition = .imageLeft
            button.lineBreakMode = .byClipping
            button.alignment = .left
        }
        setupMenu()
    }
    
    private func getMusicIcon() -> NSImage? {
        let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music")
        image?.isTemplate = true
        return image
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: "Show Lyrics",
            action: #selector(toggleLyrics(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = areLyricsEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func toggleLyrics(_ sender: NSMenuItem) {
        areLyricsEnabled.toggle()
        sender.state = areLyricsEnabled ? .on : .off
    }
    
    public func update(state: PlayerState, lyrics: [LyricLine], status: LyricsStatus, lastUpdated: Date) {
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
            let currentPos = getCurrentPosition(state: state, lastUpdated: lastUpdated)
            
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
                        
                        // Use 250.0 instead of 350.0 to prevent the notch from hiding the item
                        let scrollResult = getScrolledTitle(lyricText, maxWidth: 250.0, font: font, elapsed: elapsed, duration: lineDuration)
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
                button.image = getMusicIcon()
            } else {
                if needsScroll {
                    statusItem.length = 250.0
                } else {
                    statusItem.length = NSStatusItem.variableLength
                }
                button.title = title
                button.image = getMusicIcon()
            }
        }
    }
    
    private func getScrolledTitle(_ text: String, maxWidth: CGFloat, font: NSFont, elapsed: Double, duration: Double) -> (title: String, needsScrolling: Bool) {
        let fullWidth = getStringWidth(text, font: font)
        if fullWidth <= maxWidth {
            return (text, false)
        }
        
        let pauseRatio = 0.2
        let scrollDuration = max(0.1, duration * (1.0 - pauseRatio))
        let adjustedElapsed = max(0.0, elapsed - (duration * pauseRatio / 2.0))
        
        var progress = adjustedElapsed / scrollDuration
        if progress < 0 { progress = 0 }
        if progress > 1 { progress = 1 }
        
        var maxStartIndex = 0
        for i in 0..<text.count {
            let idx = text.index(text.startIndex, offsetBy: i)
            let sub = String(text[idx...])
            if getStringWidth(sub, font: font) <= maxWidth {
                maxStartIndex = i
                break
            }
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
