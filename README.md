# SnapRoute — Link Router for iOS

SnapRoute registers as a default browser on iOS. When you tap any link, instead of opening Safari, SnapRoute presents quick actions:

- **Open in Safari** — continue to Safari normally
- **Send to ShelfRead** — forward the URL to your ShelfRead newsletter-to-EPUB service
- **Save to Obsidian** — create a note in your Obsidian vault with the link

A web preview loads in the bottom half of the screen so you can see what's behind the link before deciding what to do with it.

Written with agent support.

## How It Works

1. Set SnapRoute as your default browser in iOS Settings
2. Tap any link in any app
3. SnapRoute opens instantly with the URL and action buttons
4. Pick an action — the link is routed accordingly

## Building

### Prerequisites

- Xcode 16+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build

```bash
cd snaproute
xcodegen generate
open SnapRoute.xcodeproj
```

Build and run on a simulator or device from Xcode.

### Setting as Default Browser

On your iOS device: Settings > Apps > Default Browser App > SnapRoute

## Configuration

Open SnapRoute and tap **Settings** to configure:

- **ShelfRead Ingest URL** — your Convex deployment URL (e.g. `https://your-deployment.convex.site/ingest`)
- **Obsidian Vault** — the name of your Obsidian vault
- **Obsidian Folder** — the folder to save notes into (default: `Inbox`)

## Architecture

Pure SwiftUI, no external dependencies. ~6 source files:

| File | Purpose |
|------|---------|
| `SnapRouteApp.swift` | App entry point, URL handling |
| `ContentView.swift` | Routes between empty state and action view |
| `ActionView.swift` | Action buttons + web preview |
| `URLRouter.swift` | URL handling logic, action implementations |
| `Settings.swift` | UserDefaults-backed settings model |
| `SettingsView.swift` | Settings UI |

## License

MIT
