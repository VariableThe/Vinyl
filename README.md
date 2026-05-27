# Menu Bar Lyrics

A native, lightweight macOS menu bar app that displays synchronized scrolling lyrics for **Apple Music** and **Spotify**.

## Features
- 🎵 **Dual Player Support:** Seamlessly detects whether Apple Music or Spotify is playing.
- 📜 **Native & LRCLIB Support:** Queries Apple Music natively for lyrics or falls back to `lrclib.net` to automatically fetch synchronized lyrics (`[mm:ss.xx]`).
- ✨ **Smooth Marquee Scrolling:** Dynamically and smoothly scrolls long lyric lines within your menu bar without jittering or overflowing into the notch.
- 🌓 **Adaptive Icon:** Uses a native SF Symbol (`music.note`) that automatically adapts to macOS Light and Dark modes.
- 🔋 **Efficient Polling:** Minimal CPU footprint utilizing native `NSAppleScript` bridging and AppKit `NSStatusItem`.

## Installation & Build

You will need the Swift toolchain installed (comes with Xcode Command Line Tools).

1. Clone the repository:
   ```bash
   git clone <your-repo-url>
   cd menu-bar-lyrics
   ```

2. Build and bundle the app using the provided `Makefile`:
   ```bash
   make app
   ```

3. The command will output a `MenuBarLyrics.app` folder. Simply drag this to your `Applications/` folder and double-click to run!

> **Note:** Upon first run, macOS will prompt you to grant `Terminal`/`MenuBarLyrics` permission to control "System Events" and "Music"/"Spotify". Please click **Allow** so the app can fetch currently playing metadata.

## Development

To run the app directly from source in development mode:
```bash
swift run
```

## Credits
Concept inspired by [LYRA](https://github.com/Dai-Ski/LYRA) and [boring.notch](https://github.com/TheBoredTeam/boring.notch).
