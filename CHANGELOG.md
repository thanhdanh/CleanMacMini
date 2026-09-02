# Changelog

All notable changes to PulseBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Add packaging, signing, notarization, and release automation.

## [0.3.4] - 2026-09-02

### Fixed

- Convert per-process Mach CPU time correctly so active processes no longer incorrectly display `0.0%`.

## [0.3.3] - 2026-09-02

### Fixed

- Align process, CPU, memory, and action columns to one shared full-width grid.

## [0.3.2] - 2026-09-02

### Fixed

- Prevent the process table header from expanding vertically and creating a large empty gap.

## [0.3.1] - 2026-09-02

### Fixed

- Prevent CPU and RAM values from being truncated in the compact view.

## [0.3.0] - 2026-09-02

### Changed

- Add a translucent blue, indigo, purple, and warm gradient to the panel material.
- Improve process list alignment and action-menu styling.

### Fixed

- Render process IDs and metric accessibility values instead of literal placeholders.
- Keep process rows anchored to the top of the available list area.

## [0.2.3] - 2026-09-02

### Fixed

- Add a dedicated drag handle to move PulseBar while its expanded panel is open.

## [0.2.2] - 2026-09-02

### Fixed

- Make compact-overlay dragging smooth by using absolute screen coordinates and avoiding SwiftUI state updates during movement.

## [0.2.1] - 2026-09-02

### Fixed

- Allow dragging the compact chip without expanding it.
- Aggregate helper-process memory into the owning application and sort apps by memory usage.
- Remove the rectangular panel shadow visible outside rounded corners.

## [0.2.0] - 2026-09-02

### Added

- Compact CPU and memory status chip.
- Expanded Processes, Memory, and Clean interface.

### Changed

- Corrected the executable entry point for Swift Package Manager builds.

## [0.1.0] - 2026-09-02

### Added

- Initial macOS Swift package and application lifecycle.
- Transparent floating panel anchored near the top-right of the display.
- CPU, memory, disk, and process sampling services.
- Process search, sorting, quit, and force-stop support with protected processes.
- Memory relief service for closing selected apps and purging inactive memory.
- Disk scanning and cleanup services for caches, logs, Trash, DerivedData, and large files.
- Login item management.
- Project documentation and source-build instructions.

[Unreleased]: https://github.com/thanhdanh/CleanMacMini/compare/v0.3.4...HEAD
[0.3.4]: https://github.com/thanhdanh/CleanMacMini/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/thanhdanh/CleanMacMini/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/thanhdanh/CleanMacMini/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/thanhdanh/CleanMacMini/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/thanhdanh/CleanMacMini/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/thanhdanh/CleanMacMini/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/thanhdanh/CleanMacMini/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/thanhdanh/CleanMacMini/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/thanhdanh/CleanMacMini/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/thanhdanh/CleanMacMini/releases/tag/v0.1.0
