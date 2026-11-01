# 📱 ValtSky Flutter Multiplatform Client

The official cross-platform client for **ValtSky**, providing bit-for-bit lossless media synchronization to private Telegram channels across Android, iOS, Windows, macOS, Linux, and the Web.

---

## 🏛️ System Architecture

ValtSky Flutter follows a clean, modular, layered architecture designed for extreme reliability, zero memory leaks during multi-gigabyte transfers, and seamless multiplatform execution.

```
                    ┌─────────────────────────────────────────┐
                    │               UI Layer                  │
                    │  DashboardView · ActivityView · Settings │
                    │  ValtSkyLogo · HealthBanner · ModalSheet│
                    └────────────────────┬────────────────────┘
                                         │
                    ┌────────────────────▼────────────────────┐
                    │             Service Layer               │
                    │   SyncEngine   ·   TelegramApiClient    │
                    │ (Monotonic Q)     (Lossless Docs/Chunk) │
                    └──────────┬───────────────────┬──────────┘
                               │                   │
        ┌──────────────────────▼──────┐     ┌──────▼──────────────────┐
        │         Data Layer          │     │      Security & Util    │
        │  DatabaseHelper (SQLite/Mem)│     │   FileSecurityGuard     │
        │  MediaItem State Machine    │     │   TelegramLauncher      │
        │  Preferences (Encrypted)    │     │   MediaScanner          │
        └─────────────────────────────┘     └─────────────────────────┘
```

### 1. UI Layer (`lib/ui/`)
- **`DashboardView`**: Real-time storage telemetry, live upload statistics, sync toggles, auto-cycling media slideshow reel, and diagnostic health alerts.
- **`ActivityView`**: Filterable media feed categorized into `All`, `Synced`, `Queued`, `Failed`, and the dedicated `> 2 GB Oversized Vault`. Includes instant filter switching from Dashboard metric cards.
- **`SettingsView`**: Telegram Bot Token and Channel ID configuration with real-time test connectivity and smart `-100` channel ID auto-formatting.
- **Widgets**:
  - `ValtSkyLogo`: Custom-painted scalable vector logo featuring the Royal Blue Cloud & Paper Airplane mark.
  - `ManualUploadAssistantSheet`: 4-click wizard for dispatching $\ge 2\text{ GB}$ files directly to Telegram.
  - `HealthStatusBanner`: Self-healing diagnostic bar that detects network/token/permission faults with 1-click auto-repair.
  - `PassiveTransferWave`: Real-time sine-wave socket activity visualizer.
  - `MediaItemCard`: High-contrast, tactile-press file card with status indicators and thumbnail previews.

### 2. Service Layer (`lib/services/`)
- **`SyncEngine`**: Monotonic worker prioritizing historical media (`dateTaken ASC`) so newest files appear chronologically at the bottom of the Telegram channel. Enforces network condition checks, concurrency limits, and retry backoff.
- **`TelegramApiClient`**: HTTP/2 client communicating directly with `api.telegram.org`. Implements multipart document uploads (`sendDocument`), rate-limit handling (`429 Too Many Requests`), and progress stream tracking.

### 3. Data Layer (`lib/data/`)
- **`DatabaseHelper`**: Dual-backend storage engine using `sqflite` on native platforms (Android, iOS, macOS) and an efficient in-memory indexed database on Web and Windows/Linux.
- **`MediaItem`**: Immutable state model tracking synchronization status (`queued`, `syncing`, `synced`, `failed`), file sizes, byte offsets, and Telegram `message_id` references.
- **`Preferences`**: Key-value store managing bot credentials, channel mappings, and feature toggles.

### 4. Utility & Security Layer (`lib/util/`)
- **`FileSecurityGuard`**:
  - **Magic Bytes Validation**: Inspects headers for JPEG (`FF D8 FF`), PNG (`89 50 4E`), and MP4 (`ftyp`) to prevent disguised scripts or executables.
  - **EICAR Detection**: Quarantines standard anti-malware test strings.
  - **MarkdownV2 Escaper**: Sanitizes Telegram caption strings against injection and entity parsing failures.
  - **SSRF Containment**: Restricts custom API endpoints to valid HTTPS and loopback schemes.
- **`TelegramLauncher`**: Resolves native Telegram deep-links (`tg://resolve?domain=...`) with seamless fallback to web URLs (`https://t.me/...`).
- **`MediaScanner`**: Platform-specific media discovery utilizing `photo_manager` on mobile and directory filesystem scanning on desktop.

---

## 🧪 Testing & Code Quality

ValtSky maintains a comprehensive automated testing suite with **16 passing tests** across unit, widget, navigation, and security attack vectors.

### Run All Tests
```bash
flutter test
```

### Static Analysis
```bash
flutter analyze
```
*Expected output: `No issues found!`*

### Key Test Suites
- **`test/widget_test.dart`**:
  - Core navigation and tab switching smoke tests.
  - Metric tile deep-linking from Dashboard to Activity view filters.
  - 4-Click Oversized Vault manual upload modal and stream simulation.
  - `TelegramLauncher` URI parsing and deep-link generation.
  - Theme switching and monochrome contrast rendering.
- **`test/security_and_stress_test.dart`**:
  - Path traversal and URL-encoded escape prevention.
  - RTL, international Unicode, and emoji caption safety.
  - File header magic bytes spoofing detection.
  - EICAR anti-malware pattern blocking.
  - MarkdownV2 special character entity escaping.
  - High-concurrency database and memory stress validation.

---

## 🛠️ Multiplatform Build Instructions

### Android Build
```bash
# Universal Production APK (for all Android phones: 52 MB)
flutter build apk --release

# Google Play App Bundle
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Apple iOS Build
```bash
flutter build ios --release --no-codesign
```
Open `ios/Runner.xcworkspace` in Xcode to configure code signing and deploy to connected devices or generate IPA packages for AltStore/Sideloadly.

### Windows Desktop Build
```bash
flutter build windows --release
```
Output: `build/windows/x64/runner/Release/`

### macOS Desktop Build
```bash
flutter build macos --release
```
Output: `build/macos/Build/Products/Release/ValtSky.app`

### Linux Desktop Build
```bash
# Requires: clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter build linux --release
```
Output: `build/linux/x64/release/bundle/`

### Web Application Build
```bash
flutter build web --release --base-href "/ValtSky/"
```
Output: `build/web/`
