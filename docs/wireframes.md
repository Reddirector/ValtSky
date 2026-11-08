# ValtSky: "Ink & Paper" Low-Fi Wireframes & Information Map

**Design Concept:** Monochrome Editorial Minimalism ("Ink & Paper")  
**Target Stack:** Flutter (Cross-platform Android, iOS, Windows, macOS, Web)  
**Document Purpose:** Phase 1 Design Specification & Architectural Wireframes prior to implementation.

---

## 1. One-Page Information Architecture & Control Map

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 VALTSKY APPLICATION                                    │
│                     (Global Scaffold with Living Background Canvas)                     │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                            │
                     ┌──────────────────────┴──────────────────────┐
                     ▼                                             ▼
        [Mobile & Tablet Viewport (<1024dp)]           [Desktop Viewport (>=1024dp)]
                     │                                             │
      ┌──────────────┴──────────────┐                              │
      ▼                             ▼                              ▼
[Collapsing Cap Slab]     [Floating Ink Dock]          [Left Ink Navigation Rail]
(Dark Header Slab, r=40)  (Pill, r=999, Paper Dot)     (Dark Rounded Drawer, r=24)
      │                             │                              │
      └──────────────────────┬──────┴──────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
     [DASHBOARD VIEW]  [ACTIVITY VIEW]  [SETTINGS VIEW]
            │                │                │
            ├─► Cap Slab     ├─► Cap Slab     ├─► Cap Slab
            │   Header Row   │   Header Row   │   Header Row
            │   Logo/Brand   │   Screen Title │   Screen Title
            │   Help Icon    │                │
            │   Sync Icon    ├─► Straddle     ├─► Straddle
            │   Theme Toggle │   Summary Card │   Telegram Card
            │   Lossless Tag │   (Media/Sync) │   (Direct Login)
            │                │                │
            ├─► Straddle     ├─► Filter Pills ├─► 7 Section Cards
            │   Hero Card    │   ALL / QUEUED │   1. Telegram Login
            │   Sync Ring %  │   SYNCED / >2GB│   2. Lossless Engine
            │   Count Ratio  │   Failed/Stash │   3. Performance
            │   Setup Button │                │   4. Network Rules
            │                ├─► 2x2 Telemetry│   5. Permissions
            │├─► 2x2 Stats   │   Photo Queue  │   6. Setup Guide
            │   Total Media  │   Video Queue  │   7. Danger Zone
            │   Synced       │   Photo Synced │
            │   In Queue     │   Video Synced ├─► Footer
            │   Failed       │                │   Version Info
            │                ├─► Action Deck  │   Build Metadata
            │├─► 2x2 Quick   │   Scan Gallery │
            │   Controls     │   Clear Queue  │
            │   Pause/Resume │   Telegram Link│
            │   Scan Gallery │                │
            │   Stop Process ├─► Media List   │
            │   Diagnostics  │   Oversized Tab│
            │                │   Item Status  │
            │└─► Pinned CTA  │   Retry/Action │
            │   Action Bar   │                │
            │   (Above Dock) └────────────────┴────────────────
            └──────────────────────────────────────────────────
```

---

## 2. Global Wireframe Anatomy & Shared Patterns

### The Cap Slab & Floating Straddle Card
Every screen is anchored by a high-contrast ink cap slab at the top. The primary hero card straddles the lower organic boundary of the slab, physically overlapping the boundary between the slab and paper canvas.

```
┌──────────────────────────────────────────────────────────┐  ▲
│  [Logo] ValtSky                 [?]    [Sync]    [Theme] │  │
│                                                          │  │ Solid Ink Cap Slab
│  VAULT SYNC STATUS                    ( Lossless )       │  │ (Dark #0E0E10 on Light)
│                                                          │  │ (Dark #1C1C1F on Dark)
│         ╭──────────────────────────────────────╮         │  │ Radius Bottom = 40dp
├─────────│                                      │─────────┤  ▼
│         │   FLOATING STRADDLE HERO CARD        │         │
│         │   (White Surface #FFFFFF on Paper)   │         │
│         │   (Surface-1 #141416 on Ink)         │         │
│         ╰──────────────────────────────────────╯         │
│                                                          │
│  Paper Canvas (#F2F2F0 on Light / #0A0A0B on Dark)       │
│  (Decorative organic line-art swirl rendered behind body)│
│                                                          │
```

---

## 3. Screen 1: Dashboard View Wireframe

### Mobile Viewport (390 x 844 dp)

```
┌──────────────────────────────────────────────────────────┐
│ [Logo] ValtSky                    (?)    (Sync)    (*)   │ <-- Top App Bar
│                                                          │
│ VAULT SYNC STATUS                    ( Lossless )        │ <-- Section Sub-header
│                                                          │
│      ╭────────────────────────────────────────────╮      │
├──────│                                            │──────┤ <-- Slab Edge (r=40)
│      │  ╭─────────╮   1 of 4 synced               │      │
│      │  │  ╭───╮  │   ──────────────────────────  │      │ <-- Straddle Card
│      │  │  │25%│  │   Not configured              │      │     (120pt Ring,
│      │  │  ╰───╯  │   Configure Telegram backup   │      │      Outfit Light 56,
│      │  ╰─────────╯   [  Setup  ]                 │      │      Live status & Setup)
│      ╰────────────────────────────────────────────╯      │
│                                                          │
│      ╭─────────────────────╮  ╭─────────────────────╮    │
│      │ [Icon]              │  │ [Icon]              │    │
│      │ 4                   │  │ 1                   │    │ <-- 2x2 Bento Stat Tiles
│      │ ──                  │  │ ──                  │    │     (40pt Ink Icon Chip,
│      │ TOTAL MEDIA         │  │ SYNCED              │    │      36pt Light Numeral,
│      ╰─────────────────────╯  ╰─────────────────────╯    │      16x2 Dash Divider,
│      ╭─────────────────────╮  ╭─────────────────────╮    │      Small-Caps Label)
│      │ [Icon]              │  │ [Icon]              │    │
│      │ 2                   │  │ 1                   │    │
│      │ ──                  │  │ ──                  │    │
│      │ IN QUEUE            │  │ FAILED              │    │
│      ╰─────────────────────╯  ╰─────────────────────╯    │
│                                                          │
│      QUICK CONTROLS                                      │ <-- Caps Header
│      ╭─────────────────────╮  ╭─────────────────────╮    │
│      │ (II) Pause          │  │ [>] Scan Gallery    │    │ <-- 2x2 Outlined Cards
│      ╰─────────────────────╯  ╰─────────────────────╯    │     (Min 64pt height,
│      ╭─────────────────────╮  ╭─────────────────────╮    │      Leading Icon Circle,
│      │ [!] Stop Process    │  │ [i] Diagnostics     │    │      Full Title Label)
│      ╰─────────────────────╯  ╰─────────────────────╯    │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ [   CONFIGURE TELEGRAM BACKUP                  (->) ]│ │ <-- Pinned Primary CTA Bar
│ └──────────────────────────────────────────────────────┘ │
│          ╭──────────────────────────────────╮            │
│          │   (o) Cloud   ( ) Queue   ( ) Set│            │ <-- Floating Ink Dock
│          ╰──────────────────────────────────╯            │     (White Circle Indicator)
└──────────────────────────────────────────────────────────┘
```

---

## 4. Screen 2: Queue & Activity View Wireframe

### Mobile Viewport (390 x 844 dp)

```
┌──────────────────────────────────────────────────────────┐
│ [Logo] ValtSky                    (?)    (Sync)    (*)   │
│                                                          │
│ QUEUE & ACTIVITY                                         │ <-- Screen Title in Slab
│                                                          │
│      ╭────────────────────────────────────────────╮      │
├──────│                                            │──────┤ <-- Slab Edge (r=40)
│      │ [Icon] 4 media items (1 synced, 2 pending) │      │ <-- Straddle Summary Card
│      ╰────────────────────────────────────────────╯      │
│                                                          │
│  ( ALL 4 )  [ PENDING 2 ]  [ DONE 1 ]  [ >2GB 0 ] [FAIL] │ <-- Horizontal Filter Chips
│                                                          │     (Active: Ink Pill
│  TELEMETRY BREAKDOWN                                     │      Inactive: Hairline)
│  ╭─────────────────────╮  ╭─────────────────────╮        │
│  │ [Icon] 2            │  │ [Icon] 0            │        │ <-- 2x2 Activity Tiles
│  │ ──                  │  │ ──                  │        │     (Photos/Videos in Queue,
│  │ Photos in Queue (*) │  │ Videos in Queue (*) │        │      Photos/Videos Synced,
│  ╰─────────────────────╯  ╰─────────────────────╯        │      (*) Active pulse dot)
│  ╭─────────────────────╮  ╭─────────────────────╮        │
│  │ [Icon] 1            │  │ [Icon] 0            │        │
│  │ ──                  │  │ ──                  │        │
│  │ Photos Synced       │  │ Videos Synced       │        │
│  ╰─────────────────────╯  ╰─────────────────────╯        │
│                                                          │
│  QUEUE ACTIONS                                           │
│  ╭─────────────────────────────────────────────────────╮ │
│  │ [  Scan Gallery                              (->)  ]│ │ <-- Primary Ink Pill
│  ╰─────────────────────────────────────────────────────╯ │
│  ╭───────────────────────────╮ ╭───────────────────────╮ │
│  │ [  Clear Queue  ]         │ │ [  Telegram Link  ^ ] │ │ <-- Secondary / Outline Pills
│  ╰───────────────────────────╯ ╰───────────────────────╯ │
│                                                          │
│  RECENT ACTIVITY                                         │
│  ╭─────────────────────────────────────────────────────╮ │
│  │ [Thumb]  IMG_20261101_001.jpg            [ DONE ]  │ │ <-- Media Item Rows
│  │          4.2 MB • Photo                  14:32     │ │     (Hairline dividers)
│  ├─────────────────────────────────────────────────────┤ │
│  │ [Thumb]  VID_20261101_002.mp4            [ QUEUE ] │ │
│  │          14.8 MB • Video                 14:33     │ │
│  ╰─────────────────────────────────────────────────────╯ │
│                                                          │
│          ╭──────────────────────────────────╮            │
│          │   ( ) Cloud   (o) Queue   ( ) Set│            │ <-- Floating Ink Dock
│          ╰──────────────────────────────────╯            │
└──────────────────────────────────────────────────────────┘
```

---

## 5. Screen 3: Settings View Wireframe

### Mobile Viewport (390 x 844 dp)

```
┌──────────────────────────────────────────────────────────┐
│ [Logo] ValtSky                    (?)    (Sync)    (*)   │
│                                                          │
│ SETTINGS                                                 │ <-- Screen Title in Slab
│                                                          │
│      ╭────────────────────────────────────────────╮      │
├──────│ DIRECT TELEGRAM LOGIN                      │──────┤ <-- Straddle Login Card
│      │ ──                                         │      │     (Country picker,
│      │ [Country: US (+1)    v]                    │      │      Phone input,
│      │ [ Phone Number: (555) 019-2831     (10/10) ]│      │      Digit counter,
│      │ [ Send Telegram Verification Code     (->) ]│      │      Custom bot toggle)
│      │ [v] Advanced: Use Custom Bot Token & ID    │      │
│      ╰────────────────────────────────────────────╯      │
│                                                          │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ ANY-SIZE LOSSLESS ENGINE                             │ │ <-- Section 2 Card
│ │ ──                                                   │ │
│ │ 100% Bit-for-Bit Lossless Mode             [ (o) ]  │ │ <-- Morphing Toggle
│ │ Smart Multi-Part Chunking                  [ (o) ]  │ │
│ │ Telegram API Server                                  │ │
│ │ [ https://api.telegram.org         ] [ Reset ]       │ │
│ │ Note: Default server supports up to 2,000 MB files.  │ │
│ ╰──────────────────────────────────────────────────────╯ │
│                                                          │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ PERFORMANCE & BATTERY                                │ │ <-- Section 3 Card
│ │ ──                                                   │ │
│ │ ╭──────────────────────╮ ╭─────────────────────────╮ │ │
│ │ │ (o) Eco Mode         │ │ ( ) Smooth Mode 120 FPS │ │ │ <-- Segmented Pill Control
│ │ ╰──────────────────────╯ ╰─────────────────────────╯ │ │
│ ╰──────────────────────────────────────────────────────╯ │
│                                                          │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ NETWORK & SECURITY RULES                             │ │ <-- Section 4 Card
│ │ ──                                                   │ │
│ │ Upload Connection Preference                         │ │
│ │ ╭─────────────╮ ╭─────────────╮ ╭──────────────────╮ │ │
│ │ │ (o) Wi-Fi   │ │ ( ) Both    │ │ ( ) Cellular     │ │ │ <-- 3-Way Recessed Slider
│ │ ╰─────────────╯ ╰─────────────╯ ╰──────────────────╯ │ │
│ │ Lock Configuration                         [ ( ) ]   │ │
│ │ Vault Privacy Lock                         [ ( ) ]   │ │
│ ╰──────────────────────────────────────────────────────╯ │
│                                                          │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ DEVICE PERMISSIONS                                   │ │ <-- Section 5 Card
│ │ ──                                                   │ │
│ │ Photos & Media Access                     (v) Granted│ │ <-- Outlined Rows with
│ │ Background Execution                      (v) Granted│ │     Circular check + text
│ │ Battery Optimization Exclusion            (v) Granted│ │
│ │ Notifications                             (v) Granted│ │
│ │ [ Manage & Grant Permissions                         ]│ │
│ ╰──────────────────────────────────────────────────────╯ │
│                                                          │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ TELEGRAM SETUP GUIDE                                 │ │ <-- Section 6 Card
│ │ ──                                                   │ │
│ │ (1) Option 1: Direct Mobile Login (Recommended)      │ │
│ │ (2) Option 2: Telegram Bot Token Setup               │ │
│ │ [ Open Full App Guide                            (^) ]│ │
│ ╰──────────────────────────────────────────────────────╯ │
│                                                          │
│ ╭─ Danger Zone ────────────────────────────────────────╮ │ <-- Section 7 Card
│ │ [!] Reset All Sync History                           │ │     (Coral hairline 35%,
│ │ Wipes local sync index. Files remain in Telegram.    │ │      Destructive Outline)
│ ╰──────────────────────────────────────────────────────╯ │
│                                                          │
│ ValtSky Mobile • Version 2.1.0 (Bit-for-Bit Lossless)    │ <-- Footer Meta
│ Cloud Storage Gateway for Telegram                     │
│                                                          │
│          ╭──────────────────────────────────╮            │
│          │   ( ) Cloud   ( ) Queue   (o) Set│            │ <-- Floating Ink Dock
│          ╰──────────────────────────────────╯            │
└──────────────────────────────────────────────────────────┘
```

---

## 6. Tablet & Desktop Responsive Layouts

### Tablet Viewport (800 x 1280 dp, Medium 600–1024dp)
- Two-column content layout inside the centered 680–760dp container.
- Left column: Straddle hero card + Quick Controls deck.
- Right column: 2x2 Bento Stat Tiles + Pinned Action Bar.
- Floating ink dock stays centered at the bottom.

### Desktop Viewport (1440 x 900 dp, Expanded >1024dp)
- Navigation transitions from bottom dock to **Left Rounded Ink Drawer / Rail** (width 260dp, radius 24dp).
- Active item displays a soft highlighted rounded row (`surface-2` with 6% white overlay).
- Main content area centers at max-width 1040dp with full keyboard focus indicators (accent ring outline).

```
┌──────────────────┬──────────────────────────────────────────────────────────────────┐
│ [Logo] ValtSky   │ [Search/Breadcrumb]                      (?)   (Sync)   (Theme) │
│ ──────────────── │ ──────────────────────────────────────────────────────────────── │
│                  │                                                                  │
│  ╭─────────────╮ │  ╭────────────────────────────────────────────────────────────╮  │
│  │(o) Dashboard│ │  │ CAP SLAB (r=40)                                            │  │
│  ╰─────────────╯ │  │ VAULT SYNC STATUS                           ( Lossless )   │  │
│  ╭─────────────╮ │  ├────────────────────────────────────────────────────────────┤  │
│  │( ) Activity │ │  │   STRADDLE HERO CARD                   2x2 BENTO STATS     │  │
│  ╰─────────────╯ │  │   [ 120pt Ring 25% ]                   [TOTAL]   [SYNCED]  │  │
│  ╭─────────────╮ │  │   "1 of 4 synced"                      [QUEUE]   [FAILED]  │  │
│  │( ) Settings │ │  │   [ Setup Button ]                                         │  │
│  ╰─────────────╯ │  ╰────────────────────────────────────────────────────────────╯  │
│                  │                                                                  │
│                  │  QUICK CONTROLS (2x2)               PINNED CTA ACTION BAR        │
│                  │  [Pause]       [Scan Gallery]       [ CONFIGURE TELEGRAM BACKUP ]│
│                  │  [Stop]        [Diagnostics]                                     │
│  ────────────────│                                                                  │
│  v2.1.0 Lossless │                                                                  │
└──────────────────┴──────────────────────────────────────────────────────────────────┘
```

---

## 7. Component Interaction & State Matrix

| Component | Default State | Pressed State | Hover State (Desktop) | Disabled State |
|-----------|---------------|---------------|-----------------------|----------------|
| **Primary Ink Pill** | Ink `#0E0E10` fill, Paper `#F1F1EE` text, 48pt height | Scale 0.97, Flash `#2C2C30`, Light haptic | Elevate 2dp, Subtle shadow | Opacity 0.40, Taps ignored |
| **Outlined Card** | Surface `#FFFFFF`, Hairline `#D4D4D0`, r=24 | Scale 0.98, Inset fill `#EAEAE7` | Border `#8C99FF` 1.5dp | Opacity 0.35, Grayed text |
| **Morphing Toggle** | Track `#0E0E10` (ON) / `#DADAD6` (OFF), Thumb 24pt circle | Thumb stretches to 30pt pill on press | Track border highlight | Dimmed track, no stretch |
| **Filter Pill** | Active: Ink pill (`#0E0E10`), Inactive: Hairline outline | Invert flash, Light haptic | Background tint 4% | Non-interactive |
| **Navigation Dock** | Dark pill `#0E0E10`, White glide circle behind active icon | Circle springs toward tap target | Icon opacity +20% | N/A (Always navigatable) |
| **Decorative Swirl** | CustomPainter smooth Bézier Path, 6% opacity | Static | Static | Skipped in Reduce Motion |

---

## 8. Frozen Copy & Parity Compliance Sign-off

- **Frozen Copy Verification:** All 216 strings cataloged in `docs/ui_inventory.md` are mapped 1-to-1 to these wireframe components. No strings are altered, shortened, or reworded.
- **Control Parity Verification:** All handlers (`toggleMonitoring`, `togglePauseUpload`, `handleScanGallery`, `handleStopProcess`, `handleRestartEngine`, `onNavigateToSettings`, `clearFailed`, `clearAll`) retain their exact state bindings.
- **Accessibility Parity:** All interactive targets strictly meet `>= 48 x 48 dp`.
