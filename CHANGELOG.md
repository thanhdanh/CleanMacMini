# Changelog

All notable changes to PulseBar are documented in this file. PulseBar follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 - 2026-09-03

### Added

- Compact, translucent CPU and RAM overlay with a memory-usage ring and shortened used/total values, anchored near the top-right of the active display.
- Expandable Processes, Memory, and Clean panels with a configurable gradient appearance.
- Live CPU and memory sampling with rolling five-minute history charts.
- Grouped application processes, background-service visibility, search, resource sorting, and protected quit or force-stop actions.
- Detailed memory pressure, freeable cached memory, app, wired, compressed, cached, swap, and free readings.
- RAM history plus an All/Apps top-consumers list covering applications and background processes.
- Separate memory actions: Free Up requests reclamation of cached memory without quitting apps, while Quit Apps supports selecting, confirming, and closing multiple applications and removes successful quits from the live lists immediately.
- Device temperature in the compact view, with graceful fallback when a Mac does not expose a compatible sensor.
- Disk cleanup scanning for user caches, logs, Trash, Xcode DerivedData, and large files.
- Configurable metric and process refresh intervals with Low Power Mode-aware sampling.
- Double-click switching between compact and expanded modes, click-and-drag repositioning from either header, reset positioning, and Open at Login support.
- Clean window-only expansion and minimization that keeps the compact header fixed at the top-right without fading or scaling it.
- An in-panel version label and a full-width expanded-panel drag handle.
- Release packaging plus Developer ID signing, Apple notarization, stapling, and GitHub Release automation.
