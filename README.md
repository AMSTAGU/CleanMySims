<p align="center">
  <img src="logo.png" alt="CleanMySims Logo" width="128">
</p>

<h1 align="center">CleanMySims</h1>

<p align="center">
  <img src="preview.png" alt="CleanMySims Preview" width="800">
</p>

<p align="center">
  <strong>A beautiful native macOS app to reclaim disk space from Xcode development artifacts</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#building-from-source">Building from Source</a> •
  <a href="#license">License</a>
</p>

---

## Overview

**CleanMySims** is a native macOS application built with SwiftUI that helps developers reclaim disk space by cleaning up Xcode-related development artifacts. It provides a beautiful, user-friendly interface to scan, visualize, and delete various types of developer cache and simulator data.

If you're an iOS/macOS developer, you know how quickly Xcode can consume disk space with simulators, derived data, caches, and device support files. CleanMySims gives you a clear overview of what's taking up space and lets you safely clean it up with just a few clicks.

## Features

### Overview

- **Total recoverable space**, with the free space left on your Mac
- **Treemap** of every category: each tile's area is proportional to its size, click one to open it
- **Clean safe items** in one click: data Xcode and Gradle recreate on their own (test clones, previews, caches, builds)
- **Light and dark mode**, following the system or forced from View > Appearance

### Live scan

- All categories are scanned **in parallel**
- The total counts up as files are measured, with the folder being read right now
- The sidebar turns into a checklist and the treemap tiles grow as sizes come in
- Sizes are the **space actually used on disk**, not the logical file size

### Categories

| Category           | What it is                                                                         | Safe |
| ------------------ | ---------------------------------------------------------------------------------- | :--: |
| **Test Clones**    | Simulator clones created by Xcode for parallel testing (`XCTestDevices`)           |  ✓   |
| **Runtimes**       | Simulator OS versions (sizes and removal through `simctl runtime`)                 |      |
| **Builds**         | DerivedData, grouped into apps, Flutter/React Native runners and Xcode caches      |  ✓   |
| **Device Support** | Symbols for the iOS, watchOS, tvOS and visionOS devices you plugged in             |      |
| **Previews**       | Simulators used by SwiftUI previews                                                |  ✓   |
| **Caches**         | Simulator caches and Xcode's own cache                                             |  ✓   |
| **Archives**       | `.xcarchive` bundles from Product > Archive (they hold the dSYMs for crash reports) |      |
| **Simulators**     | Simulators listed in Xcode                                                         |      |
| **Android SDK**    | Platforms, build tools and system images                                           |      |
| **Emulators**      | Android virtual devices (`~/.android/avd`)                                         |      |
| **Gradle**         | Gradle caches and wrapper distributions                                            |  ✓   |
| **Android Studio** | Android Studio caches and indexes                                                  |  ✓   |

### Safe deletion

- **Confirmation** before anything is removed
- Files and folders are **moved to the Trash**
- Simulators, test clones and previews are deleted with `xcrun simctl delete`, runtimes with `xcrun simctl runtime delete`, so Xcode stays consistent

## Installation

### Download Release

Download the latest release from the [Releases](https://github.com/amstagu/CleanMySims/releases) page:

- **CleanMySims.app** - Ready-to-use application, just drag to your Applications folder
- **Source archive** - For building from source

## Requirements

- **macOS 26** (Tahoe) or later
- **Xcode** (for the app to have something to clean!)

## Usage

1. **Launch CleanMySims**: the scan starts on its own
2. Look at the **treemap** to see what takes the most space
3. Click **Clean safe items**, or open a category to pick what to delete
4. Hover a row to **reveal it in Finder** or **delete** it, or use **Clean All**

### Keyboard Shortcuts

| Shortcut  | Action                |
| --------- | --------------------- |
| `Cmd + R` | Rescan all categories |
| `Esc`     | Stop the running scan |

## Building from Source

### Prerequisites

- Xcode 26 or later
- macOS 26 (Tahoe) or later

### Steps

1. **Clone the repository**

```bash
git clone https://github.com/amstagu/CleanMySims.git
cd CleanMySims
```

2. **Open in Xcode**

```bash
open CleanMySims.xcodeproj
```

3. **Build and run**

- Select the `CleanMySims` scheme
- Press `Cmd + R` to build and run

### Command Line Build

```bash
xcodebuild -project CleanMySims.xcodeproj \
  -scheme CleanMySims \
  -configuration Release \
  -derivedDataPath build
```

The built app will be in `build/Build/Products/Release/CleanMySims.app`.

## Architecture

```
CleanMySims/
├── CleanMySimsApp.swift          # App entry point, menus (Rescan, Appearance)
├── ContentView.swift             # Sidebar + detail layout, cleaning overlay
├── Models/
│   └── CleanableItem.swift       # Categories and items
├── Logic/
│   ├── DiskScanner.swift         # Finds and measures items, removes them
│   ├── SimulatorManager.swift    # Observable state: parallel scan, progress, cleaning
│   ├── Shell.swift               # Runs xcrun simctl
│   └── IconThumbnailCache.swift  # App and file icons
└── Views/
    ├── Theme.swift               # Light/dark color tokens, appearance
    ├── SidebarView.swift         # Categories with sizes, scan checklist
    ├── OverviewView.swift        # Total, treemap, clean safe items
    ├── DetailListView.swift      # Items of one category
    └── Components/               # TreemapView, CategoryIcon, AsyncIconView
```

### Technologies Used

- **SwiftUI** and **Observation**
- **Swift concurrency**: one task per category, progress streamed with `AsyncStream`
- **FileManager** allocated sizes for real disk usage
- **xcrun simctl** for simulators, device sets and runtimes

## Privacy

CleanMySims:

- **Does not collect any data**
- **Does not connect to the internet**
- **Does not have analytics or tracking**
- **Works entirely offline**

All operations are performed locally on your machine.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the need for a simple, beautiful tool to manage Xcode disk usage
- Built with love using SwiftUI and modern macOS technologies

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/amstagu">AMSTAGU</a>
</p>
