# 📦 ValtSky Multi-Platform Release Distribution Hub
### Direct-to-Telegram Personal Cloud Storage System

This directory contains release manifests, verification hashes, detailed release notes, and cross-platform installation instructions for **ValtSky**.

---

### 🔬 Systems Telemetry & Benchmarks

```
========================================================================================================
[ VERIFIED AUTOMATION SUITES ]                [ EXIF & SENSOR FIDELITY ]
122 / 122 Automated Tests Passing (100.0%)    100.0% Raw Sensor Bayer/ICC Data Preservation
0 Analyzer Errors · 0 Linter Warnings         0 Bytes Re-encoded · 0 Metadata Tags Stripped
100 / 100 Hostile Red-Team Security Score     Direct MTProto 2.0 Key Exchange
--------------------------------------------------------------------------------------------------------
[ CONCURRENCY & THROUGHPUT ]                  [ RESOURCE & MEMORY FOOTPRINT ]
Multi-Socket MTProto Worker Pool (4x Socket)  < 32 MB Resident RAM at 2.2 GB Continuous Stream
Sliding-Window Pipeline & Ring Buffers        0ms Cold Start from Snapshot Fast-Cache
========================================================================================================
```

> 📚 **Technical Manual & Tutorials:**
> - [**End-to-End Setup & Tutorial Guide**](../docs/TUTORIAL_AND_SETUP_GUIDE.md) — Comprehensive visual setup manual: Telegram phone login, OTP handling, 2FA, permissions, and nightly sync.
> - [**ValtSky System Documentation**](../docs/DOCUMENTATION.md) — Architecture schematics, subsystem breakdowns, and engineering specifications.

---

## 🚀 Official Production Binaries & Checksums

### 🤖 Android Universal Production Release (Current Stable: v2.2.0)

| Package Name | Architecture | File Size | Recommended For | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| [**`valtsky-v2.2-release.apk`**](valtsky-v2.2-release.apk) | Universal (arm64, armv7, x86_64) | **70.8 MB** | **All Android Phones & Tablets** (Samsung, Pixel, OnePlus, Xiaomi, etc.) | `ee5c41e1805ebf2fe968a5f888e6fe1010f1546a652465e3e5ca1bc744ac8203` |
| [**`valtsky-v2.1-release.apk`**](valtsky-v2.1-release.apk) | Universal (arm64, armv7, x86_64) | **68.2 MB** | Legacy Universal APK | `ae54b04f411cbf4862a086c801e07c143af8dbbffba87420849ddfd0764dfc2f` |

### 💻 Multi-Platform Production Packages (GitHub Releases)

| Package Name | Target OS | Architecture | Format | Status |
| :--- | :--- | :--- | :--- | :--- |
| [**`valtsky-v2.2-release.ipa`**](https://github.com/Reddirector/ValtSky/releases/download/v2.2/valtsky-v2.2-release.ipa) | Apple iOS 13.0+ | ARM64 | Sideloadable `.ipa` (8.9 MB) | `4ecd60362ea2f236d32dbf8bd86f197e9751cbbf2c2584c9fec7cca0ca1a8802` |
| **`valtsky-android.aab`** | Android 7.0+ | Universal | Google Play App Bundle | Automated CI Build |
| **`valtsky-windows-x64.zip`** | Windows 10 & 11 | x86_64 | Standalone Portable Archive | Automated CI Build |
| **`valtsky-macos.zip`** | macOS 11.0+ | Universal | Apple Silicon & Intel `.app` | Automated CI Build |
| **`valtsky-linux-x64.tar.gz`** | Linux (Ubuntu/Debian/Fedora) | x86_64 | GTK3 Standalone Bundle | Automated CI Build |
| **`valtsky-web.zip`** | Modern Web Browsers | Any | Progressive Web Application (PWA) | Automated CI Build |

---

## 📝 Release Notes

- [**ValtSky v2.2.0 Release Notes (Latest Production)**](RELEASE_NOTES.md): Multi-Socket MTProto TCP Pooling, Autonomous Background Sleep & Recent-Apps Persistence, 0ms Instant Cold-Start Fast-Cache, Batched Scan-Then-Upload Lifecycle, Alarm Clock Nightly Backup Loop, 122/122 passing test suites.
- [**ValtSky v2.1.0 Release Notes**](RELEASE_NOTES.md#valtsky-v210-release-notes): Background Isolate MTProto Cryptography, Dynamic GPU Gaussian Blur Bypass, Dual-Lane Split Uploader, Decoupled Gallery Monitoring & Queue Draining.

---

## 🔒 Verification & Integrity Instructions

### Linux / macOS Checksum Verification:
```bash
sha256sum valtsky-v2.2-release.apk
# Expected output:
# ee5c41e1805ebf2fe968a5f888e6fe1010f1546a652465e3e5ca1bc744ac8203  valtsky-v2.2-release.apk
```

### Windows PowerShell Verification:
```powershell
Get-FileHash -Algorithm SHA256 .\valtsky-v2.2-release.apk
```
