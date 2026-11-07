# Changelog

All notable changes to the **ValtSky** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.0] - 2026-11-07

### Added
- **Dual Licensing**: Licensed under both the MIT License and the Apache License 2.0 (`LICENSE-MIT`, `LICENSE-APACHE`, `LICENSE`).
- **Aerospace Standard Documentation (ADE STD 100)**: Full 360-line flight manual detailing ATA chapters, system architecture, normal checklists, Quick Reference Handbook (QRH) non-normal recovery, and BITE diagnostics.
- **Salted SHA-256 Vault Lock**: 4-digit privacy lock salted with a 32-byte cryptographic salt and hashed using SHA-256 with constant-time string comparison.
- **Built-In Test Equipment (BITE)**: Real-time round-trip latency pings directly to Telegram primary datacenters with 1-click self-healing engine restart.
- **1-Tap Debounced "Retry All"**: Added to both Dashboard and Activity views with floating feedback SnackBars and cross-tab synchronization.
- **Interactive Onboarding Walkthrough**: Step-by-step tutorial guide with visual beacons explaining vault connection, gallery indexing, and background sync.
- **Expanded Test Suite (42/42 Passing)**: Added widget tests for walkthrough guides, action button overflow prevention, and queue removal workflows.
- **Standard Community Health Files**: Added `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and `CHANGELOG.md`.

### Changed
- **Infinite Retry Elimination**: Removed unconditional `retryAllFailed()` calls from `startSync()`, ensuring corrupt or deleted files stay in the failed state until explicitly commanded by the user, while interrupted uploads resume safely via `resetUploadingToPending()`.
- **Cancellation & Race Condition Guard**: Guarded `startSync()` with `if (!_isSyncing) return;` after the asynchronous network ping check.
- **Background Lifecycle Resilience**: Wrapped all `BackgroundService.start()` calls in `try/catch` and properly `await`ed them to prevent unhandled platform exceptions on strict Android 14+ background execution constraints.
- **Layout Overflows Elimination**: Re-architected `MediaItemCard` into a two-tier layout with `FittedBox(fit: BoxFit.scaleDown)` bounds, completely eliminating `RenderFlex` overflows on ultra-narrow 320px viewports.
- **SQL Parameterized Chunking**: Batch deletions and bulk operations are chunked into 500-item sublists with parameterized `?` placeholders to defend against SQL injection and SQLite host variable limits (`SQLITE_MAX_VARIABLE_NUMBER`).

---

## [2.0.0] - 2026-11-01

### Added
- **Direct Telegram MTProto 2.0 Authentication**: 10-second setup without @BotFather friction via 2048-bit Diffie-Hellman key exchange.
- **27+ Country Code Searchable Selector**: Native dial code detection with auto-selection for India (+91) with 10-digit counter limit.
- **Live User Profile Synchronization**: Displays user avatar initials, Telegram ID, handle, and verified/premium status badges.
- **4-Click Oversized Media Staging (> 2 GB)**: Automatic diversion of files exceeding Telegram's 2 GB Bot API limits to an out-of-band staging vault.
- **WebSocket-to-TCP Dual-Stack Bridge**: Virtualizes raw socket streaming for sandboxed web browsers.
- **Multiplatform Target Builds**: Support for Android Universal APK, Web PWA, iOS Runner, Windows x64, macOS, and Linux desktop.

---

## [1.0.0] - 2026-10-25

### Added
- Initial proof-of-concept prototype for automated Telegram channel photo & video backup.
- SQLite database integration for local state tracking.
- Zero-loss uncompressed document upload via Telegram Bot API.
