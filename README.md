<div align="center">

# ☁️ Valtsky

<div align="center">

[![Download Release APK](https://img.shields.io/badge/Download-Release_APK-4169E1?style=for-the-badge&logo=android)](https://github.com/Reddirector/ValtSky/raw/main/app/build/outputs/apk/release/app-release-unsigned.apk)

### Turn your Telegram channel into unlimited, free, private cloud storage for your photos & videos.

![Android](https://img.shields.io/badge/Android-7.0%2B-brightgreen?logo=android)
![Kotlin](https://img.shields.io/badge/Kotlin-1.9-purple?logo=kotlin)
![Version](https://img.shields.io/badge/Version-1.0.0-blue)
![License](https://img.shields.io/badge/License-MIT-orange)

</div>

---

## 📖 What is Valtsky?

**Valtsky** is a lightweight Android app that automatically syncs your camera roll to a private Telegram channel via a bot — silently, in the background, with zero manual effort. Take a photo, and it appears in your Telegram channel within seconds. It's your personal, unlimited, encrypted cloud backup — completely free.

---

## ✨ Features

### 🔄 Smart Sync
| Feature | Detail |
|---|---|
| 📸 Auto-detect new media | Fires instantly when your camera saves a new photo or video |
| ⏱️ Resume from last upload | Never re-uploads — remembers exactly where it left off |
| 🔁 Timestamp deduplication | Uses file timestamps + hash to prevent any duplicate uploads |
| 🔀 Hash-based deduplication | MD5/SHA hash check prevents uploading the same file twice |
| 🌐 Network preference | Choose Wi-Fi only, Mobile only, or Both |
| ⏸️ Pause & Resume uploads | Pause the upload queue while keeping monitoring active |

### 📊 Dashboard
| Feature | Detail |
|---|---|
| 📈 Live stats | Total, Synced, Queued, and Failed file counts — live |
| 📉 Progress bar | Animated progress bar with percentage |
| ❌ Failed uploads panel | Shows up to 3 failed files — tap "More" to expand all |
| 🔁 Retry failed | Retry all failed files at once or individually |
| 📤 Manual upload | Instantly share all failed files via Android's share sheet |
| 🕐 Last synced time | Shows exact date and time of last successful upload |

### ⚙️ Configuration
| Feature | Detail |
|---|---|
| 🤖 Bot token | Securely stored, hidden by default with Show/Hide toggle |
| 📢 Channel ID | With live validation against the Telegram API |
| 🔒 Config lock | Lock settings to prevent accidental changes during sync |
| 🖼️ Original quality | Toggle between compressed or document (lossless) upload |
| 📶 Sync network | Wi-Fi / Mobile data / Both |

### 🎨 UI & Experience
| Feature | Detail |
|---|---|
| 🌙 Light & Dark theme | Toggle instantly — preference saved across sessions |
| ☰ Side menu | Slide-in drawer with Home and Guide navigation |
| 📖 Built-in guide | Step-by-step setup guide with 3 tabs inside the app |
| 🔔 Smart notifications | Only 2 notifications — sync started & sync complete |
| 🔋 Battery warning | Detects if battery optimisation is active and prompts to fix |
| 💥 RESET button | Full deep reset with two-step confirmation — re-uploads everything |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Language | Kotlin |
| UI | XML Layouts + View Binding |
| Database | Room (SQLite) |
| Background | Foreground Service + ContentObserver |
| Networking | OkHttp3 |
| Async | Kotlin Coroutines |
| Storage | SharedPreferences |
| API | Telegram Bot API |

---

## 📲 Telegram Setup

### Step 1 — Create a Bot 🤖
1. Open Telegram → search **`@BotFather`** (blue checkmark ✅)
2. Send `/newbot`
3. Enter a display name (e.g. `Valtsky Uploader`)
4. Enter a username ending in `bot` (e.g. `valtsky_upload_bot`)
5. Copy the **Bot Token** — looks like `7123456789:AAFabcDEF...`

### Step 2 — Create a Channel 📢
1. Telegram → tap compose icon → **New Channel**
2. Enter a name → set as **Private** → tap Skip (no members needed)

### Step 3 — Add Bot as Admin 👑
1. Open your channel → tap channel name → **Administrators**
2. **Add Administrator** → search your bot → grant **Post Messages** ✅

### Step 4 — Get Your Channel ID 🔑

**Via @userinfobot (easiest):**
> Send any message in your channel → long press → Forward → send to `@userinfobot` → it replies with your ID like `-1001234567890`

**Via browser:**
> Open `https://api.telegram.org/botYOUR_TOKEN/getUpdates` → look for `"chat":{"id": -1001234567890}`

> ⚠️ Always include the full number with the **minus sign** — e.g. `-1001234567890`

---

## 🚀 Building & Running

```bash
# Open in Android Studio
File → Open → select the TelegramBackup folder

# Sync Gradle
Click "Sync Now" when prompted

# Run on device
Connect phone (USB debugging ON) → click Run ▶
```

### Build a Release APK
```
Build → Generate Signed Bundle / APK → APK → select keystore → build Release
```

---

## 📱 Using the App

1. Open **Valtsky**
2. Paste your **Bot Token** → paste your **Channel ID**
3. Tap **Validate** → wait for ✅ confirmation
4. If the 🔋 yellow battery warning shows → tap **Fix Now** → allow exemption
5. Tap **▶ Start Monitoring**
6. Take a photo — it will appear in your Telegram channel within seconds ✅

---

## ⏸️ Pause & Resume Uploads

Valtsky separates monitoring from uploading:

- **Stop Uploading** → pauses the upload queue — monitoring continues, new photos are still detected
- **Continue Uploading** → resumes the queue from exactly where it left off
- **Stop Monitoring** → stops everything including file detection

---

## 🔄 RESET Button

> ⚠️ Use with caution — this is irreversible

The RESET button:
- Wipes all sync history and local database
- Does **not** delete anything from your Telegram channel
- Does **not** clear your Bot Token or Channel ID
- On next **Start Monitoring**, re-uploads your **entire gallery** from the very first photo

Two confirmation dialogs are shown before any action is taken.

---

## 🏗️ Project Structure

```
app/src/main/java/com/adidev/valtsky/
│
├── 📱 ValtSkyApp.kt                  Application class
│
├── 📦 data/
│   ├── Prefs.kt                      SharedPreferences wrapper (all app state)
│   └── db/
│       ├── AppDatabase.kt            Room database instance
│       ├── MediaDao.kt               All database queries
│       └── MediaItem.kt              Media file entity
│
├── 🔁 sync/
│   └── SyncEngine.kt                 Core upload loop with deduplication
│
├── 📡 telegram/
│   └── TelegramApi.kt                Bot API calls via OkHttp
│
├── 🔧 service/
│   ├── PhotoMonitorService.kt        Foreground service (keeps running in bg)
│   └── MediaStoreObserver.kt        ContentObserver for new photos/videos
│
├── 🎨 ui/
│   ├── MainActivity.kt               All UI logic and navigation
│   └── FailedItemsAdapter.kt         RecyclerView adapter for failed uploads
│
└── 🛠️ util/
    ├── FileUtils.kt                  File hash and utility functions
    └── ThemeHelper.kt               Light/Dark theme management
```

---

## 📱 Xiaomi / MIUI Notes

MIUI aggressively kills background apps. Do **all three** of these for Valtsky to work reliably:

| Setting | Where to find |
|---|---|
| 🔋 Disable battery optimisation | Settings → Battery → App battery saver → Valtsky → **No restrictions** |
| ▶️ Enable Autostart | Settings → Apps → Manage apps → Valtsky → Autostart → **ON** |
| ⚙️ Disable MIUI Optimisation | Settings → Developer Options → MIUI optimisation → **OFF** |

> The app shows a yellow banner if battery optimisation is still active.

---

## ⚠️ Known Limitations

- 📁 Photos added by other apps (WhatsApp saves, downloads) are also picked up — the app monitors the entire MediaStore by design. Folder filtering can be added later.
- 📦 Telegram Bot API file size limits: **10 MB** for photos (compressed), **50 MB** for documents. Files over 50 MB that cannot be compressed will appear in the Failed Uploads panel.
- 📸 Very fast burst shots may occasionally miss one frame due to the debounce window on the ContentObserver.
- 🔒 Bot token is stored in plain SharedPreferences — consider migrating to `EncryptedSharedPreferences` for production.

---

## 📋 Play Store Checklist

- [x] `minSdk 24` — covers 97%+ of active Android devices
- [x] `targetSdk 34` — required for new submissions
- [x] Foreground service declared with correct `foregroundServiceType`
- [x] No unused permissions
- [x] `allowBackup="false"` — protects bot token
- [ ] Generate signed APK with your keystore
- [ ] Add Privacy Policy URL in Play Console *(required — app reads media)*
- [ ] Add screenshots for store listing

---

## 🔐 Security Notes

> Never share your Bot Token with anyone. It gives full control over your bot.

- If your token is ever leaked → go to `@BotFather` → `/mybots` → your bot → **Regenerate Token** immediately
- Store your token somewhere safe — a locked notes app or password manager
- Your Telegram channel is private — only your bot can post to it

---

<div align="center">

Made with ❤️ for anyone who wants simple, free, unlimited photo backup.

**Valtsky — Your gallery. Your channel. Your storage.**

</div>