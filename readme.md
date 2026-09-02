# PulseBar

PulseBar is a lightweight, native macOS system monitor for keeping CPU and memory activity visible without taking over the desktop. Its translucent compact bar sits near the top-right of the active display and expands downward into a focused resource-control panel.

PulseBar takes inspiration from the convenience of utilities such as CleanMyMac while remaining an independent, on-device project that is not affiliated with MacPaw.

<p align="center">
  <img src="docs/images/pulsebar-compact.png" alt="PulseBar compact CPU monitor with RAM usage ring and used/total value" width="536">
</p>

## Product tour

| Processes | Memory |
| --- | --- |
| <img src="docs/images/pulsebar-processes.png" alt="Grouped process usage and CPU history" width="370"> | <img src="docs/images/pulsebar-memory.png" alt="RAM history and memory relief" width="370"> |

<p align="center">
  <img src="docs/images/pulsebar-settings.png" alt="PulseBar refresh interval and appearance settings" width="370">
</p>

## Features

- **At-a-glance monitoring** — View live CPU percentage, RAM use, and memory pressure from the compact overlay.
- **Top-edge placement** — Keep the bar close to the macOS menu bar, available across Spaces and full-screen apps, or drag it elsewhere.
- **Process inspector** — Inspect apps and background services by CPU or memory; related helper processes are grouped under their owning app.
- **Search and control** — Search by process name or PID, then quit or force-stop allowed processes. PulseBar and critical macOS processes are protected.
- **Performance history** — View a rolling five-minute CPU chart in Processes and RAM chart in Memory.
- **Memory relief** — Review the largest apps, close selected applications, clear URL cache data, and optionally ask macOS to purge inactive memory.
- **Disk cleanup** — Scan caches, logs, Trash, Xcode DerivedData, and large files before choosing exactly what to remove.
- **Configurable behavior** — Choose independent system and process refresh intervals, with slower sampling during Low Power Mode.
- **Custom appearance** — Select Ocean, Aurora, Sunset, or Graphite gradients and adjust the tint over native macOS blur.
- **Open at Login** — Start the signed app automatically after signing in.

## Install

1. Download `PulseBar-1.0.0.zip` from the [latest GitHub Release](https://github.com/thanhdanh/CleanMacMini/releases/latest).
2. Extract `PulseBar.app` and move it to `/Applications`.
3. Open PulseBar. Because release builds are Developer ID signed and notarized, macOS can verify the app before launch.

PulseBar requires macOS 14 Sonoma or later.

## How to use

1. Launch PulseBar; the compact monitor appears near the top-right of the active display.
2. Click the monitor to expand the panel downward.
3. Use **Processes** to inspect grouped apps and services, search, sort, or stop an allowed process.
4. Use **Memory** to review RAM history and select applications for memory relief.
5. Use **Clean** to scan removable files, review every category, and clean only selected items.
6. Open the gear menu to configure refresh intervals, gradient palette, and tint strength.
7. Drag the compact monitor or the handle at the top of the expanded panel to reposition PulseBar.
8. Right-click the monitor to enable **Open at Login**, reset its position, or quit.

Stopping a process can discard unsaved work. Try a normal quit first and force-stop only an unresponsive app. Review cleanup selections carefully because removed files may not be recoverable.

## Build from source

Requirements: macOS 14 or later and Xcode 15/Swift 5.9 or later.

```bash
git clone https://github.com/thanhdanh/CleanMacMini.git
cd CleanMacMini
swift run PulseBar
```

You can also open `Package.swift` in Xcode, select the **PulseBar** scheme, and run it. Open at Login is intended for a signed `.app` bundle and may not persist when PulseBar is run as a Swift package executable.

To create a local `.app` and ZIP archive:

```bash
./scripts/package-app.sh
```

The local script uses ad-hoc signing unless `SIGN_IDENTITY` names an installed Developer ID Application certificate. Official releases are built as universal binaries, signed with the hardened runtime, notarized by Apple, stapled, and uploaded by [the release workflow](.github/workflows/release.yml).

The release workflow requires these GitHub Actions secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE_P12` — base64-encoded Developer ID Application certificate and private key.
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD` — password for the `.p12` file.
- `APPLE_ID` — Apple Developer account email.
- `APPLE_TEAM_ID` — Apple Developer Team ID.
- `APPLE_APP_SPECIFIC_PASSWORD` — app-specific password used by the notary service.

## Versioning

PulseBar follows Semantic Versioning. The release version is stored in `VERSION` and `Resources/Info.plist`, release notes live in `CHANGELOG.md`, and release tags use the `vMAJOR.MINOR.PATCH` format. The first public release is `v1.0.0`.

## Privacy and permissions

PulseBar reads system metrics, process information, and user-selected cleanup locations locally. It does not require an account or transmit this information.

- PulseBar can stop only processes permitted by the current macOS user.
- Protected system processes cannot be stopped from the app.
- Purging inactive memory can show an administrator prompt.
- Files outside accessible user folders may require additional macOS permissions.

Memory relief is not a replacement for macOS memory management. macOS intentionally uses available RAM for useful caches, so lower used memory does not always mean better performance.

## Project structure

```text
Sources/PulseBar/   Application source
Resources/          Bundle metadata
docs/images/        Product screenshots
scripts/            Packaging and notarization tools
.github/workflows/  Signed release automation
```
