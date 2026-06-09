# Georgie

> *"We all float down here… and when you're up here with your windows, **they all float too**."*

<p align="center">
  <img src="https://c.tenor.com/2jJuBNJJZygAAAAC/tenor.gif" alt="Pennywise: we all float down here" width="480">
</p>

**Georgie** is a native macOS menu-bar app that puts any content into a **floating, always-on-top window** — a web page, a PDF, an image, a video, a quick note, or your camera. Open as many as you like, dial down their opacity, click straight through them, and keep them in view across every Space.

It's modeled on the content-widget approach of [AlwaysOnTop](https://alwaysontop.app) and the window-floating idea of [Floaty](https://floatytool.com).

---

## What's with the name?

The app is named after **Georgie Denbrough** from Stephen King's *IT* — the boy in the yellow raincoat chasing his paper boat down the gutter. Pennywise's promise from the storm drain, *"they float… they all float down here,"* is the whole pitch: with Georgie, your windows all float. Up here, though, floating is a feature, not a threat. 🎈

---

## Features

- 🌐 **Web** — a real browser window (`WKWebView`) with an address bar, back/forward/reload, and smart input (type a domain → opens it, type anything else → searches).
- 📄 **PDF** — full PDFKit viewer: scroll, zoom, continuous pages.
- 🖼️ **Image** — view files or paste straight from the clipboard; scroll-to-zoom up to 8×.
- 🎬 **Video** — local files and streams via AVKit, including system Picture-in-Picture.
- 📝 **Note** — a floating scratchpad with auto-save; the window title follows your first line.
- 📷 **Camera** — your webcam in a floating window for calls, recordings, or screen-sharing; switch between any connected camera source on the fly.

Every window shares the same floating behavior:

- **Always on top** — three levels: *Normal*, *Always on Top*, *Top Most*.
- **Adjustable opacity** — 20–100 % per window.
- **Click-through** — let mouse clicks pass through the window to whatever's behind it.
- **All Spaces** — windows stay visible as you switch desktops, and alongside full-screen apps.
- **Minimal chrome** — controls appear on hover; drag from anywhere on the title strip.
- **Remembers everything** — size, position, opacity and (optionally) your whole set of open windows are restored on the next launch.

Add content via the menu bar, the **file dialog**, **drag & drop** onto a window, the clipboard, or **"Open With…"** from Finder.

---

## Requirements

- macOS **14.0** (Sonoma) or later
- Apple Silicon or Intel
- Xcode **16+** to build

---

## Build & Run

```bash
git clone <repo-url> Georgie
cd Georgie
open Georgie.xcodeproj
```

Then press **⌘R** in Xcode.

Georgie is a **menu-bar-only app** (`LSUIElement`) — it has no Dock icon and no main window. After launching, look for the **`pip` icon in the macOS menu bar** (top right). Everything starts from there.

> The project uses Xcode's *file-system-synchronized groups*: any `.swift` file added under `Georgie/` is compiled automatically — no `project.pbxproj` editing required.

---

## Usage

Click the menu-bar icon and choose what to float:

| Action | What happens |
|---|---|
| **New Web Window** | Empty browser window; type an address or search term |
| **New Note** | Blank scratchpad, ready to type |
| **Camera** | Webcam preview (asks for permission the first time) |
| **Open PDF / Image / Video…** | File picker for that content type |
| **Image from Clipboard** | Floats whatever image you've copied |
| **Open Windows ▸** | Per-window: bring to front, toggle click-through, close |
| **Close All** | Dismiss every floating window |
| **Settings…** | Default opacity, default level, session restore |
| **Check for Updates…** | Manually check for a new version (Sparkle) |
| **About Georgie** | Version, links, and update preferences |

Hover over any window to reveal its control strip: title/drag-handle, opacity slider, level menu, click-through toggle, close.

> **Tip:** when a window is in click-through mode it ignores *all* mouse events — re-enable interaction from the menu bar under **Open Windows ▸**.

---

## Privacy

Everything runs locally. Georgie does not transmit screen contents or any of your data. The camera feed never leaves your machine.

---

*Inspired by AlwaysOnTop and Floaty. Named, with affection and a healthy fear of storm drains, after Georgie Denbrough.*
