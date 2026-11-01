<div align="center">

# ☁️ ValtSky Multiplatform

### Turn your private Telegram channel into unlimited, zero-loss, free cloud storage.

[![Download Android APK](https://img.shields.io/badge/Android_APK-v2.0_Release-10B981?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Reddirector/ValtSky/releases/latest)
[![Download iOS Runner](https://img.shields.io/badge/iOS-Sideload_Runner-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Reddirector/ValtSky/releases/latest)
[![Download Windows](https://img.shields.io/badge/Windows-x64_Release-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/Reddirector/ValtSky/releases/latest)
[![Download macOS](https://img.shields.io/badge/macOS-Universal-grey?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Reddirector/ValtSky/releases/latest)
[![Download Linux](https://img.shields.io/badge/Linux-x64_Bundle-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://github.com/Reddirector/ValtSky/releases/latest)

<br/>

[![Security & QA Score](https://img.shields.io/badge/Security_&_QA-98%2F100_Strict-10B981?style=flat-square&logo=shield)](valtsky_flutter/test/security_and_stress_test.dart)
[![Lossless Quality](https://img.shields.io/badge/Quality-100%25_EXIF_Preserved-blue?style=flat-square)](https://github.com/Reddirector/ValtSky)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Web-orange?style=flat-square)](https://github.com/Reddirector/ValtSky)

</div>

---

## 📖 Overview

**ValtSky** is an open-source, high-performance multiplatform cloud vault designed to turn your private Telegram channel into your personal, unlimited, encrypted cloud backup. 

Unlike traditional cloud providers that charge recurring monthly subscriptions or compress your media, ValtSky automatically uploads every camera roll capture, 4K video, and RAW photo as an uncompressed, bit-for-bit document with **100% EXIF and metadata preservation** — completely free forever.

---

## 📦 Multi-Platform Downloads

| Platform | Format / Package | Compatibility | Download Link |
| :--- | :--- | :--- | :--- |
| **Android (Universal)** | `.apk` (Self-Contained) | Android 7.0+ (API 24–35) | [**Download `valtsky-v2.0-release.apk`**](https://github.com/Reddirector/ValtSky/releases/latest) |
| **Android (Google Play)** | `.aab` (Optimized Bundle) | Android 7.0+ | [**Download `valtsky-android.aab`**](https://github.com/Reddirector/ValtSky/releases/latest) |
| **Apple iOS** | `.zip` (Runner / Sideload) | iOS 13.0+ (iPhone & iPad) | [**Download `valtsky-ios-runner.zip`**](https://github.com/Reddirector/ValtSky/releases/latest) |
| **Windows Desktop** | `.zip` (Standalone Executable) | Windows 10 & 11 (x64) | [**Download `valtsky-windows-x64.zip`**](https://github.com/Reddirector/ValtSky/releases/latest) |
| **macOS Desktop** | `.zip` (Universal Binary) | macOS 11.0 Big Sur+ | [**Download `valtsky-macos.zip`**](https://github.com/Reddirector/ValtSky/releases/latest) |
| **Linux Desktop** | `.tar.gz` (GTK3 Bundle) | Ubuntu, Debian, Fedora, Arch | [**Download `valtsky-linux-x64.tar.gz`**](https://github.com/Reddirector/ValtSky/releases/latest) |
| **Web App** | Single Page Application (SPA) | Chrome, Safari, Firefox, Edge | [**Launch Web Version**](https://reddirector.github.io/ValtSky/) |

---

## ✨ Key Architectural Highlights

### 💎 1. Zero Quality Loss (100% Bit-for-Bit EXIF Preservation)
- Standard photo uploaders send media as compressed images, destroying camera sensor noise, color science, and GPS metadata.
- ValtSky uploads photos and videos strictly as **uncompressed documents** via Telegram's `sendDocument` API.
- All EXIF metadata (camera model, shutter speed, ISO, focal length, GPS geotags, HDR color profiles) is preserved with 100% fidelity.

### ⏳ 2. Monotonic Chronological Sorting (Oldest to Newest)
- Uploads follow strict monotonic ordering (`dateTaken ASC`).
- Oldest photos and historical memories upload first, ensuring that when viewed inside your Telegram channel, your newest captures always stay at the bottom of the feed — matching physical chronology.

### 🚀 3. Oversized Media Vault (> 2 GB) with 4-Click Manual Upload
- The Telegram Bot API imposes a strict **2,147,483,648 byte (2 GB)** hard limit per bot request.
- Background sync daemons automatically skip files $\ge 2\text{ GB}$ so the automated queue never stalls or times out.
- High-bitrate 4K footage and multi-gigabyte masters are routed to the **OVERSIZED VAULT** and can be dispatched to the **exact same Telegram channel** in **exactly 4 clicks**:

```mermaid
flowchart LR
    A["1. Queued Banner / Tab<br/>'1 file > 2GB held'"] -->|Click 1| B["2. Filter '> 2 GB'<br/>Oversized Vault View"]
    B -->|Click 2| C["3. Tap 'UPLOAD ALL OVERSIZED'<br/>Open Assistant Sheet"]
    C -->|Click 3| D["4. Tap 'START 2GB+ UPLOAD'<br/>Multi-Part RAM Stream"]
    D -->|Click 4| E["5. Complete Manifest<br/>Open Telegram Channel"]
```

### 🛠️ 4. 1-Click Self-Healing Diagnostic Center
- Proactive health monitor tracks socket connectivity, Telegram Bot Token validity, channel admin privileges, battery optimization exemptions, and disk permissions.
- When an issue arises, the **Diagnostic Banner** appears with root-cause analysis and a **1-Click Self-Healing button** to fix the failure instantly.

### 🛡️ 5. Hardened Security & Anti-Malware Protection (Score: 98/100)
- **File Header (Magic Bytes) Authentication**: Inspects initial byte signatures for JPEG (`FF D8 FF`), PNG (`89 50 4E`), and MP4 (`ftyp`) to prevent disguised binaries or malicious scripts.
- **EICAR Virus Quarantine**: Blocks standard malware test patterns and quarantined files.
- **Telegram MarkdownV2 Entity Defense**: Escapes reserved markdown characters to prevent bot crashes or malicious hyperlink phishing.
- **SSRF Defense**: Enforces HTTPS and restricts custom API servers to validated local loopbacks.

### 🎨 6. Strict Monochrome Noir Aesthetic with Colored Alerts
- Obsidian charcoal dark theme (`#09090B`) with high-contrast monochrome design.
- Surgical colored accents reserved strictly for functional alerts (Crimson for errors, Amber for oversized warnings, Emerald for verified sync).
- Smooth motion: Micro-interaction press springs (`TactilePress`), passive sine-wave socket monitors (`PassiveTransferWave`), and crossfade transitions.

---

## 📸 Screenshots Showcase

<div align="center">

| 1. Monochrome Dashboard | 2. Oversized Banner Alert | 3. Oversized Media Vault |
| :---: | :---: | :---: |
| <img src="docs/screenshots/01_dashboard_monochrome.png" width="280" /> | <img src="docs/screenshots/02_queued_oversized_banner.png" width="280" /> | <img src="docs/screenshots/03_oversized_vault.png" width="280" /> |
| Real-time telemetry & health status | Proactive banner holding >2GB files | Dedicated vault preventing queue locks |

| 4. 4-Click Assistant Sheet | 5. Live Speed & Wave Stream | 6. Lossless Confirmed Manifest |
| :---: | :---: | :---: |
| <img src="docs/screenshots/04_manual_uploader_modal.png" width="280" /> | <img src="docs/screenshots/05_ram_stream_chunker.png" width="280" /> | <img src="docs/screenshots/06_lossless_confirmed.png" width="280" /> |
| Step tracker & target channel review | Live `⚡ XX MB/s` streaming chunks | Bit-for-bit verified delivery manifest |

</div>

---

## 📲 3-Minute Telegram Setup Guide

### Step 1: Create Your Bot 🤖
1. Open Telegram and search for **`@BotFather`** (verified with a blue checkmark ✅).
2. Send the message: `/newbot`.
3. Provide a friendly name (e.g., `My Vault Bot`) and a username ending with `bot` (e.g., `my_valtsky_bot`).
4. Copy the **Bot Token** generated (formatted like `7123456789:AAFabcDEFghIjkLmNoPqRsTuVwXyZ`).

### Step 2: Create Your Private Channel 📢
1. In Telegram, create a **New Channel**.
2. Set the channel type to **Private** (no members need to be added).
3. Go to **Channel Settings** $\rightarrow$ **Administrators** $\rightarrow$ **Add Administrator**.
4. Search for your bot username and grant it **Post Messages** permission.

### Step 3: Find Your Channel ID 🔑
1. Send any temporary test message inside your newly created channel.
2. Forward that message to **`@userinfobot`** in Telegram.
3. The bot will respond with your channel's unique ID (e.g., `-1001234567890`).
> *Note: Always include the minus sign `-` and prefix `100`.*

### Step 4: Configure ValtSky 🚀
1. Open ValtSky on Android, iOS, Windows, Mac, or Linux.
2. Navigate to **Settings** and paste your **Bot Token** and **Channel ID**.
3. Tap **Test & Save Connection**. Once you receive the green confirmation, monitoring and sync start automatically!

---

## 🛠️ Building & Developing From Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+ recommended, tested on 3.44.2 stable)
- [Android SDK](https://developer.android.com/studio) (for Android builds)
- [Xcode](https://developer.apple.com/xcode/) (for iOS and macOS builds on Mac)
- Visual Studio with "Desktop development with C++" (for Windows builds)
- Clang, CMake, Ninja, GTK 3 (for Linux builds: `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev`)

### Quick Start
```bash
# Clone the repository
git clone https://github.com/Reddirector/ValtSky.git
cd ValtSky/valtsky_flutter

# Install dependencies
flutter pub get

# Run tests and security audit suite (14/14 tests)
flutter test
flutter analyze

# Run on your connected device or desktop
flutter run
```

### Compiling Multi-Platform Binaries

```bash
# 🤖 Android Release APK & AppBundle
flutter build apk --release
flutter build appbundle --release

# 🍎 iOS Release (Xcode / AltStore sideload)
flutter build ios --release --no-codesign

# 🪟 Windows Desktop
flutter build windows --release

# 🍏 macOS Desktop
flutter build macos --release

# 🐧 Linux Desktop
flutter build linux --release

# 🌐 Web App
flutter build web --release
```

---

## 🏗️ Repository Architecture

```
ValtSky/
├── .github/workflows/
│   ├── build_and_release.yml     # Multi-platform CI/CD (Android, iOS, Win, Mac, Linux, Web)
│   └── build_apk.yml             # Fast automated PR & commit build validation
├── docs/
│   └── screenshots/              # High-resolution UI showcase and 4-click flow
├── index.html                    # Modern web download portal & showcase
├── releases/
│   └── valtsky-v2.0-release.apk  # Official compiled Android production release binary
├── app/                          # Native Android Kotlin Engine (Room, ContentObserver)
└── valtsky_flutter/              # Flutter Multiplatform Client
    ├── lib/
    │   ├── data/
    │   │   ├── db/database_helper.dart      # SQLite & memory store with 2GB+ filtering
    │   │   ├── models/media_item.dart       # Media entity with state machine
    │   │   └── prefs.dart                   # Secure preference storage
    │   ├── services/
    │   │   ├── sync_engine.dart             # Monotonic chronological upload worker
    │   │   └── telegram_api.dart            # Lossless document transmission & chunking
    │   ├── ui/
    │   │   ├── views/activity_view.dart     # Queue, Synced, Failed, & Oversized Vault
    │   │   ├── views/dashboard_view.dart    # Telemetry, slideshow reel & diagnostics
    │   │   ├── views/settings_view.dart     # Telegram credentials & lossless toggles
    │   │   └── widgets/
    │   │       ├── manual_upload_assistant_sheet.dart  # 4-Click 2GB+ manual uploader
    │   │       ├── health_status_banner.dart           # Diagnostic self-healing banner
    │   │       ├── media_item_card.dart                # High-contrast file card
    │   │       ├── media_slideshow_reel.dart           # Auto-cycling preview carousel
    │   │       └── passive_elements.dart               # Sine wave socket transfer meter
    │   └── util/
    │       ├── file_security_guard.dart     # Magic bytes inspection & EICAR defense
    │       ├── media_scanner.dart           # PhotoKit & MediaStore device scanner
    │       └── theme.dart                   # Monochrome Noir design tokens
    └── test/
        ├── security_and_stress_test.dart    # 12 Hostile security & stress attack tests
        └── widget_test.dart                 # Navigation & 4-Click Oversized flow tests
```

---

## 🛡️ Security & Privacy Guarantee

- **Zero Cloud Intermediaries**: ValtSky has **no central server**, no database owned by us, and no tracking. All network traffic travels directly between your device and the official Telegram servers (`api.telegram.org`).
- **Encrypted Telegram Channels**: Your private Telegram channel is protected by Telegram's multi-datacenter distributed infrastructure and two-factor authentication (2FA).
- **Your Data Stays Yours**: You own your bot, your channel, and your files. Delete or migrate them anytime without vendor lock-in.

---

## 📄 License

ValtSky is released under the **MIT License**. See [LICENSE](LICENSE) for details.

<div align="center">

**ValtSky — Your gallery. Your channel. Your storage.**

</div>
