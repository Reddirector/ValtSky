# 📦 ValtSky Multi-Platform Release Distribution Hub

This directory contains release manifests, verification hashes, and cross-platform installation instructions for **ValtSky v2.0**.

---

## 🚀 Official Binaries & Checksums

| Package Name | Target Platform | Architecture | SHA-256 Checksum | Download Location |
| :--- | :--- | :--- | :--- | :--- |
| **`valtsky-v2.0-release.apk`** | Android 7.0+ | Universal (ARM64, ARMv7, x86_64) | `453e7dccf73d14e3d78f95ecc36bfe35274a88fc9dd54f71bf88f828bf9026ac` | [GitHub Releases](https://github.com/Reddirector/ValtSky/releases) |
| **`valtsky-android.aab`** | Google Play | Universal Play Bundle | Generated via GitHub Actions | [GitHub Releases](https://github.com/Reddirector/ValtSky/releases) |
| **`valtsky-ios-runner.zip`** | Apple iOS 13+ | iPhone / iPad (ARM64) | Generated via GitHub Actions | [GitHub Releases](https://github.com/Reddirector/ValtSky/releases) |
| **`valtsky-windows-x64.zip`** | Windows 10/11 | x86_64 | Generated via GitHub Actions | [GitHub Releases](https://github.com/Reddirector/ValtSky/releases) |
| **`valtsky-macos.zip`** | macOS 11+ | Universal (Apple Silicon & Intel) | Generated via GitHub Actions | [GitHub Releases](https://github.com/Reddirector/ValtSky/releases) |
| **`valtsky-linux-x64.tar.gz`** | Linux Desktop | x86_64 (GTK3) | Generated via GitHub Actions | [GitHub Releases](https://github.com/Reddirector/ValtSky/releases) |

---

## 📲 Platform Installation Guides

### 🤖 1. Android Installation
1. Download **`valtsky-v2.0-release.apk`** on your Android device.
2. If prompted by your browser, enable **"Allow from this source"** for unknown apps in Android Settings.
3. Tap **Install** and open ValtSky.
4. Or install via USB using ADB:
   ```bash
   adb install -r valtsky-v2.0-release.apk
   ```

### 🍎 2. Apple iOS Installation & Development
Because iOS restricts direct sideloading of unsigned IPAs outside the App Store, you have three options to run ValtSky on iPhone/iPad:

#### Option A: Sideload via AltStore / Sideloadly (No Paid Developer Account Needed)
1. Download **`valtsky-ios-runner.zip`** from [GitHub Releases](https://github.com/Reddirector/ValtSky/releases).
2. Extract the runner archive or package into an `.ipa`.
3. Open [AltStore](https://altstore.io/) or [Sideloadly](https://sideloadly.io/) on your Mac or PC.
4. Drag and drop the app file onto your connected iPhone and enter your Apple ID to sign it for free 7-day sideloading.

#### Option B: Open with Xcode (Developers)
1. Open the project on a Mac:
   ```bash
   cd valtsky_flutter/ios
   open Runner.xcworkspace
   ```
2. Select your development team under **Signing & Capabilities**.
3. Connect your iPhone and press **Run (Cmd+R)** to install the app directly to your device with background fetch and photo library permissions enabled.

---

### 🪟 3. Windows Desktop
1. Download **`valtsky-windows-x64.zip`**.
2. Extract the archive into a folder of your choice (e.g. `C:\Program Files\ValtSky`).
3. Double click **`ValtSky.exe`** to launch.

---

### 🍏 4. macOS Desktop
1. Download **`valtsky-macos.zip`**.
2. Double-click to unzip, then drag **`ValtSky.app`** into your `/Applications` folder.
3. If macOS Gatekeeper alerts you because the binary is open-source, right-click `ValtSky.app` $\rightarrow$ click **Open** $\rightarrow$ click **Open Anyway**.

---

### 🐧 5. Linux Desktop
1. Download **`valtsky-linux-x64.tar.gz`**.
2. Extract and run:
   ```bash
   tar -xvf valtsky-linux-x64.tar.gz
   ./valtsky_flutter
   ```
