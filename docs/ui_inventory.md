# ValtSky UI Inventory & Frozen Copy Baseline

**Generated at Phase 0 Baseline (Ink & Paper Redesign)**  
This document establishes the single source of truth for all user-visible strings, controls, state bindings, handlers, test identifiers, and logo-derived palette tokens for the "Ink & Paper" editorial minimalism redesign.

## 0. Logo-Derived Color Sampling & Palette Mapping

Sampled from authentic repository assets (`valtsky_flutter/assets/images/valtsky_logo.svg` and `valtsky_logo.png`):
- **Logo Cloud Gradient Start**: `#4F75FF` (RGB 79, 117, 255)
- **Logo Cloud Gradient End**: `#3652D9` (RGB 54, 82, 217)
- **Logo Chevron Accent**: `#4F75FF`
- **Logo Paper Plane Arrow**: `#FFFFFF` (Paper White)
- **Logo Dark Container**: `#0D0D0F` (RGB 13, 13, 15)

### Token Mapping ("Ink & Paper" Concept):

#### LIGHT "PAPER" THEME
- **Canvas**: `#F2F2F0` (warm textured paper base)
- **Surface**: `#FFFFFF` (floating white card)
- **Surface-2**: `#EAEAE7` (secondary card / pill fill)
- **Surface-3**: `#DADAD6` (recessed track / dividers)
- **Hairline**: `#D4D4D0` (1px subtle border)
- **Ink (Text Primary & Primary CTA)**: `#0E0E10` (17.5:1 AAA contrast on surface)
- **Text-2 (Secondary)**: `#55555B` (6.81:1 AA contrast on canvas)
- **Text-3 (Tertiary / Min Allowed)**: `#66666C` (5.12:1 AA contrast on canvas)
- **Cap Slab**: `#0E0E10` with text `#F1F1EE` (17.5:1 AAA contrast)
- **Accent (Logo Indigo adjusted for white text)**: `#4650D6` (6.15:1 AA contrast with white text)
- **Status Synced**: `#1F7A52` (muted deep forest sage)
- **Status Failed**: `#C23838` (restrained editorial crimson)

#### DARK "INK" THEME
- **Canvas**: `#0A0A0B` (deep matte ink canvas)
- **Surface**: `#141416` (quiet dark card)
- **Surface-2**: `#1C1C1F` (secondary dark card / slab)
- **Surface-3**: `#26262A` (recessed tracks / dividers)
- **Hairline**: `#2C2C30` (1px hairline outline)
- **Text Primary**: `#F1F1EE` (16.9:1 AAA contrast on canvas)
- **Text-2 (Secondary)**: `#A3A3A8` (8.1:1 AAA contrast on canvas)
- **Text-3 (Tertiary / Dimmest Allowed)**: `#8A8A90` (5.6:1 AA contrast on canvas)
- **Cap Slab**: `#1C1C1F` with faint 5% inner top highlight
- **Accent (Logo Indigo brightened for ink text)**: `#8C99FF` (7.66:1 AAA contrast with `#0A0A0B` ink text)
- **Status Synced**: `#6FD3A5` (soft mint sage)
- **Status Failed**: `#FF8A8A` (soft editorial coral)

#### ACCENT BUDGET & DESIGN RULES
- **Accent Budget**: Max ~5% of pixels (ring arc + glowing head dot, active-transfer pulse dot, keyboard focus ring, selected micro-dot).
- **CTA Buttons**: Ink fill (`#0E0E10`) with paper text in Light; Paper fill (`#F1F1EE`) with ink text in Dark.
- **Status Indicators**: Always paired with icon + text (never color alone).
- **Typography**: Display/Titles in `Outfit` (Light 300 numerals, SemiBold 600 titles), Body in `Inter` (400/500/600).
- **Cap Slab**: Solid ink header slab with bottom radius 40. Floating hero card straddles the slab edge. Wire swirl (~6% opacity) drawn in code behind paper body.

## 1. Architectural Scope & File Boundaries

### Presentation-Only Files (Permitted to be refactored visually):
- `valtsky_flutter/lib/ui/home_page.dart` (App bar, navigation dock/rail, lock modal)
- `valtsky_flutter/lib/ui/views/dashboard_view.dart` (Dashboard page layout)
- `valtsky_flutter/lib/ui/widgets/vault_storage_card.dart` (Monolithic vault card / hero cut-out)
- `valtsky_flutter/lib/ui/widgets/vault_metric_deck.dart` (2x2 stats metrics)
- `valtsky_flutter/lib/ui/widgets/dashboard_control_deck.dart` (Quick controls: Pause & Stop Process)
- `valtsky_flutter/lib/ui/widgets/dashboard_status_banner.dart` (Offline/rate limit alerts)
- `valtsky_flutter/lib/ui/widgets/failed_item_card.dart` (Failed item card & retry)
- `valtsky_flutter/lib/ui/views/activity_view.dart` (Queue & Activity view, filter pills, summary, telemetry)
- `valtsky_flutter/lib/ui/widgets/media_item_card.dart` (Media item list element)
- `valtsky_flutter/lib/ui/widgets/manual_upload_assistant_sheet.dart` (>2GB upload assistant sheet)
- `valtsky_flutter/lib/ui/views/settings_view.dart` (7 settings cards & footer)
- `valtsky_flutter/lib/ui/widgets/telegram_phone_login_widget.dart` (Phone MTProto login)
- `valtsky_flutter/lib/ui/widgets/telegram_profile_card.dart` (Connected account card)
- `valtsky_flutter/lib/ui/widgets/app_walkthrough_guide.dart` (Step guide modal)
- `valtsky_flutter/lib/ui/widgets/troubleshooting_sheet.dart` (Troubleshooting modal)
- `valtsky_flutter/lib/util/theme.dart` (Design tokens, themes, typography)

### Frozen Core & Logic Files (STRICTLY FORBIDDEN to modify business logic/state):
- `valtsky_flutter/lib/ui/view_models/dashboard_view_model.dart` (No state logic modifications)
- `valtsky_flutter/lib/services/*` (Sync engine, upload isolates, MTProto auth, background services)
- `valtsky_flutter/lib/data/*` (DatabaseHelper, models, preferences)

## 2. Interactive Control Parity Master Matrix

| Control / Element | Screen / Section | Original Handler / Binding | Enabled / State Condition | Test / Finder Key |
|---|---|---|---|---|
| **ValtSky Logo** | Header | Static Branding | Always visible | Header logo icon |
| **ValtSky Title** | Header | Static Title | Always visible | `find.text('ValtSky')` |
| **Interactive Guide** | Header | `_openGuide()` | Always clickable | Tooltip: `Interactive Guide` |
| **Refresh Live Counts** | Header | `_handleGlobalRefresh()` | Displays spinner while refreshing | Tooltip: `Refresh Live Counts` |
| **Theme Toggle** | Header | `ThemeProvider.toggleTheme()` | Switches Light / Dark mode | Tooltip: `Switch to ... Theme` |
| **Nav: Dashboard** | Bottom Dock / Rail | `_switchPage(0)` | Active when `_currentIndex == 0` | `find.text('Dashboard')` |
| **Nav: Queue & Activity** | Bottom Dock / Rail | `_switchPage(1)` | Active when `_currentIndex == 1` | `find.text('Queue & Activity')` |
| **Nav: Settings** | Bottom Dock / Rail | `_switchPage(2)` | Active when `_currentIndex == 2` | `find.text('Settings')` |
| **Vault Hero Status Tag** | Dashboard: Hero | Bound to `isConfigured` & `isMonitoring` | `Lossless` tag displayed | `find.text('Lossless')` |
| **Vault Hero Progress Count** | Dashboard: Hero | `$uploadedCount of $totalCount synced` | Live reactive state | Matches regex `\d+ of \d+ synced` |
| **Radial Tick Ring / Pct** | Dashboard: Hero | `$percentInt%` | Value: `(progress * 100).toInt()` | Matches `find.text('$percentInt')` |
| **Master Action CTA** | Dashboard: Hero CTA | `onToggleMonitoring` | `CONFIGURE TELEGRAM BACKUP` / `STOP MONITORING` / `START MONITORING` | `find.text('CONFIGURE TELEGRAM BACKUP')` |
| **Metric: Total Media** | Dashboard: Metrics | `onNavigateToActivity('ALL')` | Value: `$totalCount` | `find.text('TOTAL MEDIA')` |
| **Metric: Synced** | Dashboard: Metrics | `onNavigateToActivity('DONE')` | Value: `$uploadedCount` | `find.text('SYNCED')` |
| **Metric: In Queue** | Dashboard: Metrics | `onNavigateToActivity('PENDING')` | Value: `$pendingCount` | `find.text('IN QUEUE')` |
| **Metric: Failed** | Dashboard: Metrics | `onNavigateToActivity('FAILED')` | Value: `$failedCount` | `find.text('FAILED')` |
| **Quick Control: Pause/Resume** | Dashboard: Quick Controls | `onTogglePause` | Enabled only when `isConfigured == true` | `find.text('Pause')` / `find.text('Resume')` |
| **Quick Control: Stop Process** | Dashboard: Quick Controls | `onStopProcess` | Subtle coral icon, stops sync process | `find.text('Stop Process')` |
| **Filter Chip: All** | Queue & Activity: Filters | `setFilter('ALL')` | Badge count: `_breakdown.totalCount` | `find.text('All')` |
| **Filter Chip: Queued** | Queue & Activity: Filters | `setFilter(MediaItem.statusPending)` | Badge count: `_breakdown.totalPending` | `find.text('Queued')` |
| **Filter Chip: Synced** | Queue & Activity: Filters | `setFilter(MediaItem.statusDone)` | Badge count: `_breakdown.totalSynced` | `find.text('Synced')` |
| **Filter Chip: > 2 GB** | Queue & Activity: Filters | `setFilter('OVERSIZED')` | Badge count: `_breakdown.oversizedCount` | `find.text('> 2 GB')` |
| **Filter Chip: Failed** | Queue & Activity: Filters | `setFilter(MediaItem.statusFailed)` | Badge count: `_breakdown.totalFailed` | `find.text('Failed')` |
| **Summary Line** | Queue & Activity: Summary | Live breakdown counts | Format: `total media tracked, pending, synced` | Matches summary text |
| **Block 1: Photos in Queue** | Queue & Activity: Telemetry | Count: `_breakdown.pendingPhotos` | Subtitle: `Pending / In-Flight` | `find.text('PHOTOS IN QUEUE')` |
| **Block 2: Videos in Queue** | Queue & Activity: Telemetry | Count: `_breakdown.pendingVideos` | Subtitle: `Preparing / Wire` | `find.text('VIDEOS IN QUEUE')` |
| **Block 3: Photos Synced** | Queue & Activity: Telemetry | Count: `_breakdown.syncedPhotos` | Subtitle: `100% Lossless` | `find.text('PHOTOS SYNCED')` |
| **Block 4: Videos Synced** | Queue & Activity: Telemetry | Count: `_breakdown.syncedVideos` | Subtitle: `Original Bitrate` | `find.text('VIDEOS SYNCED')` |
| **Action: Clear Queue** | Queue & Activity: Actions | `_handleClearQueue()` | Secondary button with confirmation dialog | `find.text('Clear Queue')` |
| **Action: Open Telegram Channel** | Queue & Activity: Actions | `TelegramLauncher.openChannel()` | Outline action button | `find.text('Open Telegram Channel')` |
| **Direct Phone Login** | Settings: Card 1 | `_authMode == 'phone'` | Phone input + Country selector | `find.text('Direct Telegram Login')` |
| **Country Selector** | Settings: Card 1 | `CountryData.showSelectorModal()` | Displays dial code and flag (default India +91) | `find.text('+91')` |
| **Phone Number Field** | Settings: Card 1 | `_phoneController` | Digit counter `0 / 10 digits` | Digit counter label |
| **Send Code Button** | Settings: Card 1 | `_handleSendPhoneCode()` | Primary CTA | `find.text('SEND TELEGRAM VERIFICATION CODE')` |
| **Bot Mode Switch Link** | Settings: Card 1 | `setState(() => _authMode = ...)` | Switch between Phone and Bot modes | `find.text('Advanced: Use Custom Bot Token & Channel ID')` |
| **Toggle: 100% Lossless** | Settings: Card 2 | `Prefs.useOriginalQuality = val` | Bit-for-bit preserve | `find.text('100% Bit-for-Bit Lossless Mode')` |
| **Toggle: Smart Chunking** | Settings: Card 2 | `Prefs.enableChunking = val` | Files > 50MB | `find.text('Smart Multi-Part Chunking (Files > 50MB)')` |
| **API Server Field** | Settings: Card 2 | `_apiServerController` | Custom endpoint input | `find.text('CUSTOM TELEGRAM API SERVER')` |
| **API Server Reset** | Settings: Card 2 | Reset to `https://api.telegram.org` | Reverts endpoint | `find.text('Reset to Default')` |
| **Toggle: Eco / Smooth Mode** | Settings: Card 3 | `Prefs.highFrameRate = val` | 120 FPS high refresh toggle | `find.text('Eco / Smooth Mode')` & `find.text('120 FPS')` |
| **Segmented: Network Type** | Settings: Card 4 | `Prefs.uploadNetworkType = choice` | Choices: Wi-Fi Only / Both / Cellular Data | Segments: Wi-Fi, Both, Data |
| **Toggle: Lock Configuration** | Settings: Card 4 | `Prefs.configLocked = val` | Locks settings | `find.text('Lock Configuration')` |
| **Toggle: Vault Privacy Lock** | Settings: Card 4 | `Prefs.vaultPinEnabled = val` | Requires 4-digit PIN | `find.text('Vault Privacy Lock')` |
| **Permissions (4 rows)** | Settings: Card 5 | Gallery, Notifications, Location, Battery | Granted status check state | `find.text('Gallery Access')`, etc. |
| **Manage Permissions Button** | Settings: Card 5 | `PermissionManager.openAppSettings()` | Primary button | `find.text('MANAGE & GRANT PERMISSIONS')` |
| **Setup Guide Accordion** | Settings: Card 6 | Collapsible Option 1 & Option 2 steps | Telegram Setup Guide | `find.text('Telegram Setup Guide')` |
| **Open Full App Guide** | Settings: Card 6 | `AppWalkthroughGuide.showWalkthroughSheet()` | Launches guide | `find.text('Open Full App Guide')` |
| **Danger: Reset All History** | Settings: Card 7 | `DatabaseHelper.instance.resetAllSyncHistory()` | Destructive outline with confirmation | `find.text('Reset All Sync History')` |
| **Footer Version Text** | Settings: Footer | Version and architecture lines | Line 1 & Line 2 verbatim | `find.text('ValtSky v2.1 • Zero-lag upload engine')` |

## 3. Frozen Copy Verbatim String Inventory

This list contains every user-visible string extracted from the presentation layer source code with its exact file and line number.

### `valtsky_flutter/lib/ui/home_page.dart` (10 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 239 | Text | `ValtSky` |
| 255 | tooltip | `Interactive Guide` |
| 263 | tooltip | `Refresh Live Counts` |
| 334 | label | `Dashboard` |
| 339 | label | `Queue & Activity` |
| 344 | label | `Settings` |
| 435 | Text | `Vault Privacy Lock` |
| 444 | Text | `Enter 4-digit security PIN to access cloud media` |
| 472 | hintText | `••••` |
| 506 | Text | `UNLOCK VAULT` |

### `valtsky_flutter/lib/ui/views/dashboard_view.dart` (5 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 185 | Text | `${_viewModel.failedCount} Failed Uploads` |
| 210 | Dialog/SnackBar | `$count failed items queued for retry` |
| 212 | Text | `$count failed items queued for retry` |
| 234 | Text | `Retry All` |
| 242 | Text | `View All` |

### `valtsky_flutter/lib/ui/widgets/vault_storage_card.dart` (4 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 120 | Text | `Lossless` |
| 172 | Text | `$uploadedCount of $totalCount synced` |
| 209 | Text | `$percentInt` |
| 219 | Text | `%` |

### `valtsky_flutter/lib/ui/widgets/vault_metric_deck.dart` (4 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 38 | title | `TOTAL MEDIA` |
| 50 | title | `SYNCED` |
| 66 | title | `IN QUEUE` |
| 78 | title | `FAILED` |

### `valtsky_flutter/lib/ui/widgets/dashboard_control_deck.dart` (2 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 37 | Text | `QUICK CONTROLS` |
| 57 | title | `Stop Process` |

### `valtsky_flutter/lib/ui/widgets/dashboard_status_banner.dart` (3 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 39 | Text | `${rateLimitRemaining}s remaining` |
| 53 | Text | `Retry` |
| 75 | Text | `Sign In` |

### `valtsky_flutter/lib/ui/widgets/failed_item_card.dart` (9 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 41 | Dialog/SnackBar | `Smart Chunking enabled. Item queued for re-upload.` |
| 42 | Text | `Smart Chunking enabled. Item queued for re-upload.` |
| 126 | Text | `WHAT WENT WRONG:` |
| 130 | Text | `HOW TO FIX IT:` |
| 138 | Text | `DISMISS` |
| 216 | Text | `•` |
| 240 | Text | `Tap for diagnosis & 1-click fix` |
| 251 | tooltip | `Stash file` |
| 263 | tooltip | `Retry upload` |

### `valtsky_flutter/lib/ui/views/activity_view.dart` (33 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 26 | Variable (_selectedFilter) | `ALL` |
| 93 | Text | `Clear Upload Queue?` |
| 94 | Text | `This will remove all pending photos and videos from the active upload queue. Your local files will not be deleted.` |
| 101 | Text | `Cancel` |
| 110 | Text | `Clear Queue` |
| 125 | Dialog/SnackBar | `Cleared $removed items from upload queue` |
| 127 | Text | `Cleared $removed items from upload queue` |
| 250 | Text | `${_breakdown.oversizedCount} oversized files (> 2 GB) held for manual upload` |
| 266 | Text | `Review Vault` |
| 296 | title | `PHOTOS IN QUEUE` |
| 308 | title | `VIDEOS IN QUEUE` |
| 325 | title | `PHOTOS SYNCED` |
| 327 | subtitle | `100% Lossless` |
| 336 | title | `VIDEOS SYNCED` |
| 338 | subtitle | `Original Bitrate` |
| 407 | Text | `$count` |
| 501 | Text | `Clear Queue` |
| 530 | Dialog/SnackBar | `$retried failed items requeued` |
| 532 | Text | `$retried failed items requeued` |
| 542 | Text | `Retry ${_breakdown.totalFailed} Failed Transfers` |
| 561 | Text | `Open Telegram Channel` |
| 665 | Dialog/SnackBar | `$count failed items queued for retry` |
| 667 | Text | `$count failed items queued for retry` |
| 685 | Text | `RETRY ALL` |
| 724 | Text | `$badgeCount` |
| 795 | Text | `OVERSIZED VAULT (> 2 GB)` |
| 799 | Text | `Exceeds standard automated Bot limits` |
| 816 | Text | `$_oversizedCount Files` |
| 847 | Text | `UPLOAD ALL OVERSIZED` |
| 881 | Text | `Open Channel` |
| 922 | Text | `Oversized Vault Clear` |
| 927 | Text | `No media files exceed the 2 GB threshold` |

### `valtsky_flutter/lib/ui/widgets/media_item_card.dart` (11 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 170 | Text | `UPLOAD NOW` |
| 188 | Text | `RETRY UPLOAD` |
| 209 | Text | `OPEN IN VAULT` |
| 228 | Text | `DELETE` |
| 244 | Text | `Copy File Path` |
| 248 | Dialog/SnackBar | `File path copied to clipboard` |
| 249 | Text | `File path copied to clipboard` |
| 359 | Text | `${_formatFileSize(item.fileSize)}  •  $dateStr` |
| 459 | Text | `UPLOAD` |
| 494 | Text | `RETRY` |
| 530 | Text | `DELETE` |

### `valtsky_flutter/lib/ui/widgets/manual_upload_assistant_sheet.dart` (17 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 174 | Text | `Manual 2GB+ Lossless Uploader` |
| 187 | Text | `4-CLICK FLOW` |
| 258 | Text | `TARGET TELEGRAM CHANNEL` |
| 263 | Text | `$channelName (via $botName)` |
| 277 | Text | `READY` |
| 294 | Text | `FILES TO TRANSMIT (${widget.items.length})` |
| 303 | Text | `Total: ${_formatSize(_totalBytes)}` |
| 371 | Text | `SELECT TRANSMISSION ROUTE` |
| 383 | title | `In-App Smart RAM Chunker (Recommended)` |
| 391 | title | `Direct Telegram Native Share Sheet` |
| 420 | Text | `Streaming to Channel...` |
| 467 | Text | `${(_uploadProgress * 100).toInt()}%` |
| 499 | Text | `Lossless Backup Confirmed` |
| 510 | Text | `All ${_formatSize(_totalBytes)} transmitted as bit-for-bit uncompressed documents to $channelName.` |
| 540 | Text | `START 2GB+ LOSSLESS UPLOAD (${_formatSize(_totalBytes)})` |
| 568 | Text | `Dismiss` |
| 586 | Text | `Open Telegram Channel` |

### `valtsky_flutter/lib/ui/views/settings_view.dart` (64 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 76 | Text | `Please enter both Bot Token and Channel ID` |
| 90 | Text | `🛡️ Security Warning: ${urlValidation.error}` |
| 132 | Text | `Verified: @$botName in $channelName` |
| 145 | Text | `Channel not found or Bot is not an Administrator` |
| 157 | Text | `Invalid Bot Token — could not authenticate with Telegram API` |
| 176 | Text | `Deep Reset?` |
| 179 | Text | `Wipes local sync history. Files in Telegram will not be deleted.` |
| 185 | Text | `CANCEL` |
| 194 | Text | `CONFIRM RESET` |
| 210 | Text | `Sync history wiped. Ready for fresh backup.` |
| 229 | Text | `Set Vault PIN` |
| 236 | Text | `Enter a 4-digit security PIN to protect your cloud vault:` |
| 246 | hintText | `••••` |
| 257 | Text | `Cancel` |
| 271 | Text | `Set PIN` |
| 283 | Dialog/SnackBar | `✓ Vault Privacy Lock enabled with 4-digit PIN` |
| 284 | Text | `✓ Vault Privacy Lock enabled with 4-digit PIN` |
| 295 | Text | `Confirm PIN to Unlock` |
| 304 | hintText | `Current 4-digit PIN` |
| 313 | Text | `Cancel` |
| 325 | Dialog/SnackBar | `Incorrect PIN!` |
| 326 | Text | `Incorrect PIN!` |
| 330 | Text | `Unlock` |
| 342 | Dialog/SnackBar | `Vault Privacy Lock disabled` |
| 343 | Text | `Vault Privacy Lock disabled` |
| 477 | Text | `Telegram Bot API` |
| 495 | Text | `CONNECTED` |
| 567 | Text | `Switch to Direct Phone Login` |
| 597 | Text | `Any-Size Lossless Engine` |
| 601 | Text | `Zero compression mode` |
| 615 | Text | `100% Bit-for-Bit Lossless Mode` |
| 616 | Text | `Preserves exact camera bytes & EXIF.` |
| 629 | Text | `Smart Multi-Part Chunking (Files > 50MB)` |
| 630 | Text | `Splits files into 48MB parts.` |
| 652 | Text | `RESET` |
| 670 | Text | `Custom endpoint for direct 2GB uploads.` |
| 775 | Text | `Performance & Battery` |
| 779 | Text | `Zero-lag upload engine` |
| 808 | Text | `Eco / Smooth Mode` |
| 851 | Text | `Network & Security Rules` |
| 860 | Text | `Upload Network Preference` |
| 874 | Text | `Wi-Fi` |
| 877 | tooltip | `Wi-Fi only` |
| 883 | Text | `Both` |
| 886 | tooltip | `Wi-Fi and Cellular` |
| 892 | Text | `Data` |
| 895 | tooltip | `Cellular data only` |
| 909 | Text | `Lock Configuration` |
| 910 | Text | `Prevent edits while syncing.` |
| 923 | Text | `Vault Privacy Lock` |
| 962 | Text | `Device Permissions` |
| 966 | Text | `Gallery, Notifications, Location & Battery` |
| 996 | Text | `MANAGE & GRANT PERMISSIONS` |
| 1064 | Text | `Telegram Setup Guide` |
| 1068 | Text | `Short steps to link your cloud vault` |
| 1095 | Text | `Option 1: Phone Login (Fastest)` |
| 1129 | Text | `Option 2: Bot & Channel (Advanced)` |
| 1168 | Text | `OPEN FULL APP GUIDE` |
| 1185 | Text | `$step. ` |
| 1218 | Text | `Danger Zone` |
| 1225 | Text | `Wipes local sync index.` |
| 1239 | Text | `RESET ALL SYNC HISTORY` |
| 1277 | Text | `ValtSky Multiplatform v2.0` |
| 1282 | Text | `Zero-Loss Telegram Cloud Storage • Open Source` |

### `valtsky_flutter/lib/ui/widgets/telegram_phone_login_widget.dart` (24 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 105 | Text | `A new verification code has been dispatched via SMS!` |
| 174 | Text | `Please enter your ${_selectedCountry.name} phone number` |
| 186 | Text | `${_selectedCountry.name} numbers require exactly ${_selectedCountry.maxLength} digits (${digits.length}/${_selectedCountry.maxLength} entered)` |
| 224 | Text | `Please enter the 5-digit verification code from Telegram` |
| 236 | Text | `Telegram verification code must be 5 digits` |
| 300 | Text | `Direct Telegram Login` |
| 307 | Text | `Instant setup via Telegram code` |
| 325 | Text | `Telegram Phone Number` |
| 338 | Text | `${_phoneController.text.length} / ${_selectedCountry.maxLength} digits` |
| 422 | Text | `Country: ${_selectedCountry.name} (${_selectedCountry.dialCode}) • Max ${_selectedCountry.maxLength} digits` |
| 451 | Text | `SEND TELEGRAM VERIFICATION CODE` |
| 473 | Text | `Code sent to ${_selectedCountry.dialCode} ${_phoneController.text}` |
| 491 | Text | `Change` |
| 533 | Text | `OPEN TELEGRAM APP TO VIEW CODE` |
| 561 | hintText | `••••••` |
| 603 | Text | `CONNECTING & SYNCING PROFILE...` |
| 620 | Text | `VERIFY & LINK TELEGRAM ACCOUNT` |
| 643 | Text | `Didn\` |
| 656 | Text | `RESEND CODE VIA SMS` |
| 689 | Text | `Real Telegram Account Linked` |
| 714 | Text | `Advanced: Use Custom Bot Token & Channel ID` |
| 806 | Text | `Select Country / Region` |
| 823 | hintText | `Search by country or code (+91, India...)` |
| 865 | Text | `Max ${country.maxLength} digits (e.g. ${country.example})` |

### `valtsky_flutter/lib/ui/widgets/telegram_profile_card.dart` (14 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 38 | Text | `Disconnect Account?` |
| 41 | Text | `Unlinks your session. Files on Telegram are safe.` |
| 48 | Text | `Cancel` |
| 61 | Text | `Disconnect` |
| 164 | Text | `★ PREMIUM` |
| 181 | Text | `@$userHandle` |
| 191 | Text | ` • ` |
| 194 | Text | `ID: $userId` |
| 218 | label | `LINKED PHONE` |
| 224 | label | `PRIVATE VAULT` |
| 231 | label | `CHANNEL ID` |
| 238 | label | `SECURITY ENCRYPTION` |
| 259 | Text | `Open Vault` |
| 283 | Text | `Logout` |

### `valtsky_flutter/lib/ui/widgets/app_walkthrough_guide.dart` (9 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 88 | Text | `ValtSky Quick Guide` |
| 96 | Text | `3 simple steps to start zero-loss backup` |
| 180 | Text | `QUICK START TUTORIAL` |
| 199 | Text | `Dismiss` |
| 222 | title | `Connect Your Vault` |
| 244 | title | `Scan Gallery to Receive Media` |
| 266 | title | `Monitor & Manage Sync` |
| 295 | Text | `INTERACTIVE SPOTLIGHT TOUR` |
| 435 | Text | `• ` |

### `valtsky_flutter/lib/ui/widgets/troubleshooting_sheet.dart` (3 strings)

| Line | Type | Verbatim String |
|---|---|---|
| 187 | Text | `No Issues Detected` |
| 192 | Text | `Your Telegram bot is verified and standing by to sync new photos and videos automatically.` |
| 217 | Text | `DIAGNOSTIC STATUS` |

