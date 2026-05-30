# Vinyl

<div align="center">
  <img src="Normal use-preview.png" alt="Vinyl Normal Use Preview" width="600"/>
</div>

A native, lightweight macOS menu bar app that displays synchronized scrolling lyrics for **Apple Music** and **Spotify**.


## Features
- 🎵 **Dual Player Support:** Seamlessly detects whether Apple Music or Spotify is playing.
- 🎛️ **Interactive Dropdown & Media Controls:** Left-click the menu bar to reveal a beautiful popover with full scrolling lyrics, a seek bar, and playback controls.
- 💾 **Smart Local Caching:** Saves lyrics to a local JSON cache to completely eliminate API calls for songs you've played before.
- 🛜 **Offline Mode:** Falls back to fetching native plain-text lyrics from Apple Music via AppleScript when the internet or `lrclib.net` is unavailable.
- 📜 **Native & LRCLIB Support:** Queries Apple Music natively for lyrics or falls back to `lrclib.net` to automatically fetch synchronized lyrics (`[mm:ss.xx]`). *(Note: Spotify removed its lyrics API, so Vinyl relies exclusively on `lrclib.net` for fetching Spotify lyrics.)*
- ✨ **Smooth Marquee Scrolling:** Dynamically and smoothly scrolls long lyric lines within your menu bar without jittering or overflowing into the notch.
- ⚙️ **Customizable Preferences:** Adjust the marquee scroll speed, menu bar text appearance, and toggle the dropdown UI from a native SwiftUI settings window.
- 🌓 **Adaptive Icon:** Uses a custom vinyl logo that dynamically adapts to macOS Light and Dark modes.
- ⚡ **Instant Sync:** Uses macOS system notifications (`DistributedNotificationCenter`) for zero-delay, event-driven updates when tracks change, eliminating CPU-heavy interval polling.

## Screenshots

<p align="center">
  <img src="Left click-preview.png" alt="Left Click Preview" width="45%"/>
  <img src="Preferences -preview.png" alt="Preferences Preview" width="45%"/>
</p>
<p align="center">
  <img src="Right click-preview.png" alt="Right Click Preview" width="45%"/>
</p>

## Installation

### Homebrew (Recommended)
You can easily install Vinyl using Homebrew:
```bash
brew tap VariableThe/tap
brew install --cask vinyl
```

### Manual Download
Alternatively, you can download the latest pre-built release:
1. Go to the [Releases](https://github.com/VariableThe/Vinyl/releases/latest) page.
2. Download the `Vinyl.zip` file.
3. Extract the ZIP file and drag `Vinyl.app` into your `Applications/` folder.
4. Double-click to run!

> **Note:** Upon first run, macOS will prompt you to grant `Vinyl` permission to control "System Events" and "Music"/"Spotify". Please click **Allow** so the app can fetch currently playing metadata.

> ⚠️ **Note on macOS Gatekeeper ("App is damaged" error)**
> Because Vinyl is an open-source utility and is not code-signed with a paid Apple Developer ID, macOS will apply a quarantine flag to the application upon manual download, throwing a false "damaged app" warning.
>
> To fix this, simply open your Terminal and run the following command to strip the quarantine flag:
> ```bash
> xattr -cr /Applications/Vinyl.app
> ```
> Once run, you can open Vinyl normally!

## Build from Source

You will need the Swift toolchain installed (comes with Xcode Command Line Tools).

1. Clone the repository:
   ```bash
   git clone https://github.com/VariableThe/Vinyl.git
   cd Vinyl
   ```

2. Build and bundle the app using the provided `Makefile`:
   ```bash
   make app
   ```

3. The command will output a `Vinyl.app` folder. Simply drag this to your `Applications/` folder and double-click to run!

## Development

To run the app directly from source in development mode:
```bash
swift run
```
Interested in how Vinyl stacks up against choices like LyricsX, LyricFever, or LyricGlow? Check out the [Ecosystem Comparisons](comparisons.md) guide.

## 🎭 UI When You Want It, Invisible When You Don't

Vinyl is designed to be a fully interactive macOS application that can instantly strip down into a ghost process. 

- **Event-Driven Efficiency:** Vinyl doesn't waste CPU cycles constantly polling for track updates. It uses macOS native event notifications to sync instantly only when a track changes.
- **Smart Caching:** Your bandwidth matters. Lyrics are cached in a local JSON file, meaning if you loop a song 100 times, Vinyl only fetches the data once.
- **Granular Configuration:** Vinyl gives you the ability to toggle any UI feature or element that you don't want. You can go from the most minimalist indicator for playing music, all the way to a menu bar lyrics display and drop down media controls with blur and album covers to everything in between. You can use Vinyl how YOU want to.

## Credits
Concept inspired by [LYRA](https://github.com/Dai-Ski/LYRA) and [boring.notch](https://github.com/TheBoredTeam/boring.notch).
