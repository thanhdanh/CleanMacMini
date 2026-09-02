# PulseBar

PulseBar is a lightweight macOS system monitor that keeps CPU and memory information visible without taking over your desktop. It lives as a small, transparent overlay in the top-right corner of the screen and expands into a simple control panel when clicked.

The project takes inspiration from the convenience of tools such as CleanMyMac, while focusing on an always-available, low-overhead view of system performance. PulseBar is an independent project and is not affiliated with MacPaw.

> **Project status:** Early-stage prototype. The monitoring and maintenance services are in place, while parts of the expanded user interface are still under development.

## Features

- **At-a-glance monitoring** — See live CPU usage, CPU percentage, memory usage, and memory pressure from a compact overlay.
- **Always within reach** — The floating panel is pinned to the top-right corner, stays available across Spaces and full-screen apps, and can be dragged elsewhere.
- **Process inspector** — Expand PulseBar to view the apps and background processes using the most CPU or memory.
- **Search and sorting** — Find a process by name or PID and sort the list by resource usage.
- **Process control** — Quit or force-stop an unresponsive process directly from the panel. Critical macOS processes and PulseBar itself are protected.
- **Memory relief** — Close selected applications, clear URL cache data, and optionally ask macOS to purge inactive memory.
- **Disk cleanup** — Scan user caches, logs, Trash, Xcode DerivedData, and large files before choosing what to remove.
- **Open at login** — Keep PulseBar ready after signing in to your Mac.
- **Lightweight by design** — Native Swift, SwiftUI, and AppKit with adaptive sampling intervals and slower updates while Low Power Mode is enabled.
- **Native macOS appearance** — A translucent material, compact layout, rounded corners, and subtle animations help the overlay blend into the desktop.

## How to use PulseBar

1. Launch PulseBar. The compact monitor appears near the top-right corner of the active display.
2. Read the live CPU and memory values directly from the compact view.
3. Click the monitor to open the expanded panel.
4. Use **Processes** to inspect high-usage apps and services, search by name or PID, and quit a process when needed.
5. Use **Memory** to select applications to close and request memory relief.
6. Use **Clean** to scan removable files, review the categories and sizes, then clean only the items you select.
7. Drag the panel to reposition it. Right-click it to enable **Open at Login**, reset its position, or quit PulseBar.

Stopping a process can cause unsaved work to be lost. Try a normal quit first and use force stop only when an app is unresponsive. Review cleanup selections carefully because removed files are not guaranteed to be recoverable.

## Run from source

### Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later, or Swift 5.9 or later

### Swift Package Manager

```bash
git clone https://github.com/thanhdanh/PulseBar.git
cd PulseBar
swift run PulseBar
```

You can also open `Package.swift` in Xcode, select the **PulseBar** scheme, and press **Run**.

The login item integration requires PulseBar to be distributed and launched as a properly signed `.app` bundle. It may not persist when the project is run as a command-line Swift package executable.

### Docker

PulseBar cannot be built or run as a macOS app in a standard Docker container. Docker Desktop runs Linux containers, while PulseBar depends on macOS-only frameworks (`AppKit`, `SwiftUI`, and `ServiceManagement`), the macOS SDK, and the macOS window server.

If you do not want to install Swift locally, use a macOS CI runner such as GitHub Actions to build and package the app, then download the resulting `.app` artifact and run it on a Mac. Code signing and notarization additionally require an Apple Developer identity and credentials. Docker can still be useful for portable tooling around the repository, but not for compiling or displaying PulseBar itself.

## Versioning and releases

PulseBar follows [Semantic Versioning](https://semver.org/):

- **Major** versions contain incompatible changes.
- **Minor** versions add backward-compatible features.
- **Patch** versions contain backward-compatible fixes.

The current version is stored in `VERSION` and the app bundle version is stored in `Resources/Info.plist`. Release changes are recorded in `CHANGELOG.md`, and Git tags use the `vMAJOR.MINOR.PATCH` format, such as `v0.1.0`.

For each release:

1. Move completed entries from **Unreleased** into a dated version section in `CHANGELOG.md`.
2. Update `VERSION` and `CFBundleShortVersionString` in `Resources/Info.plist`.
3. Commit the release, create the matching Git tag, and publish a GitHub Release.

## Privacy and permissions

PulseBar reads local system metrics and process information on your Mac. It does not need an account and is designed to keep this information on-device.

Some operations are intentionally limited by macOS:

- PulseBar can stop only processes allowed by the current user's permissions.
- Protected system processes cannot be stopped from the app.
- Purging inactive memory can show a macOS administrator prompt.
- Files outside accessible user folders may require additional macOS permissions.

Memory relief is not a replacement for macOS memory management. macOS uses available RAM for useful caches, so a lower “used memory” value is not always faster or healthier. PulseBar reports the observed result and lets the operating system remain in control.

## Project structure

```text
Sources/PulseBar/
├── Models/       System metrics, processes, disk categories, and formatting
├── Overlay/      Floating panel positioning and SwiftUI root view
├── Services/     Metrics, process, memory, disk, and login-item services
├── AppDelegate.swift
└── main.swift
```

## Roadmap

- Complete and polish the expanded Processes, Memory, and Clean views
- Add CPU and memory history charts
- Add configurable refresh intervals and overlay appearance
- Improve multi-display positioning and saved placement
- Package, sign, notarize, and distribute PulseBar as a macOS app
- Add automated tests for samplers and cleanup safety rules

Contributions and feedback are welcome while PulseBar takes shape.
