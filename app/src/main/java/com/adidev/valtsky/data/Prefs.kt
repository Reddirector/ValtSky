package com.adidev.valtsky.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit

/**
 * Thin wrapper around SharedPreferences.
 * NOTE: We purposely use plain SharedPreferences here so the app is easy to
 * debug and extend.  When you publish, consider migrating botToken to
 * EncryptedSharedPreferences for extra security.
 */
object Prefs {

    private const val FILE = "vs_prefs"

    internal const val KEY_BOT_TOKEN   = "bot_token"
    internal const val KEY_CHANNEL_ID  = "channel_id"
    internal const val KEY_ENABLED     = "monitoring_enabled"
    internal const val KEY_LAST_SYNCED = "last_synced_ts"
    internal const val KEY_ORIGINAL_QUALITY = "use_original_quality"
    internal const val KEY_CONFIG_LOCKED = "config_locked"
    internal const val KEY_NETWORK_TYPE = "network_type"
    internal const val KEY_BOT_NAME = "bot_name"
    internal const val KEY_CHANNEL_NAME = "channel_name"
    internal const val KEY_SELECTED_THEME = "selected_theme"
    internal const val KEY_SAVED_CHANNEL_ID = "saved_channel_id"
    internal const val KEY_RESET_FLAG = "reset_flag"
    internal const val KEY_FRESH_START = "fresh_start_flag"
    internal const val KEY_RESET_IN_PROGRESS = "reset_in_progress"

    enum class NetworkTypeChoice { WIFI, MOBILE, BOTH }
    enum class ThemeChoice { LIGHT, DARK }

    internal fun sp(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /**
     * Requirement Phase 1: Clear All Local Storage / Persistent State.
     * Preserves Bot Token and Channel ID as requested.
     */
    fun clearAllSyncState(ctx: Context) {
        sp(ctx).edit {
            remove(KEY_LAST_SYNCED)
            remove(KEY_RESET_FLAG)
            remove(KEY_ENABLED)
            // Stored failed uploads and queue are in Database, handled separately
        }
    }
}

// ── Bot token ─────────────────────────────────────────────────────────────
var Context.botToken: String
    get() = Prefs.sp(this).getString(Prefs.KEY_BOT_TOKEN, "") ?: ""
    set(v) = Prefs.sp(this).edit { putString(Prefs.KEY_BOT_TOKEN, v.trim()) }

// ── Channel / chat ID  (e.g. "@mychannel" or "-100123456789") ─────────────
var Context.channelId: String
    get() = Prefs.sp(this).getString(Prefs.KEY_CHANNEL_ID, "") ?: ""
    set(v) {
        val old = Prefs.sp(this).getString(Prefs.KEY_CHANNEL_ID, "") ?: ""
        val new = v.trim()
        if (old != new) {
            // Requirement Step 1: Detect channel change
            this.lastSyncedTs = System.currentTimeMillis() // Default to current time for new channel
            Prefs.sp(this).edit { 
                putString(Prefs.KEY_CHANNEL_ID, new)
                putString(Prefs.KEY_SAVED_CHANNEL_ID, new)
            }
        } else {
            Prefs.sp(this).edit { putString(Prefs.KEY_CHANNEL_ID, new) }
        }
    }

var Context.savedChannelId: String
    get() = Prefs.sp(this).getString(Prefs.KEY_SAVED_CHANNEL_ID, "") ?: ""
    set(v) = Prefs.sp(this).edit { putString(Prefs.KEY_SAVED_CHANNEL_ID, v.trim()) }

var Context.resetFlag: Boolean
    get() = Prefs.sp(this).getBoolean(Prefs.KEY_RESET_FLAG, false)
    set(v) = Prefs.sp(this).edit { putBoolean(Prefs.KEY_RESET_FLAG, v) }

var Context.freshStartFlag: Boolean
    get() = Prefs.sp(this).getBoolean(Prefs.KEY_FRESH_START, false)
    set(v) = Prefs.sp(this).edit { putBoolean(Prefs.KEY_FRESH_START, v) }

var Context.resetInProgress: Boolean
    get() = Prefs.sp(this).getBoolean(Prefs.KEY_RESET_IN_PROGRESS, false)
    set(v) = Prefs.sp(this).edit { putBoolean(Prefs.KEY_RESET_IN_PROGRESS, v) }

internal const val KEY_UPLOAD_PAUSED = "upload_paused"
var Context.uploadPaused: Boolean
    get() = Prefs.sp(this).getBoolean(KEY_UPLOAD_PAUSED, false)
    set(v) = Prefs.sp(this).edit { putBoolean(KEY_UPLOAD_PAUSED, v) }

// ── Is monitoring currently on? ──────────────────────────────────────────
var Context.monitoringEnabled: Boolean
    get() = Prefs.sp(this).getBoolean(Prefs.KEY_ENABLED, false)
    set(v) = Prefs.sp(this).edit { putBoolean(Prefs.KEY_ENABLED, v) }

// ── Use original quality (send as document) ──────────────────────────────
var Context.useOriginalQuality: Boolean
    get() = Prefs.sp(this).getBoolean(Prefs.KEY_ORIGINAL_QUALITY, true)
    set(v) = Prefs.sp(this).edit { putBoolean(Prefs.KEY_ORIGINAL_QUALITY, v) }

// ── Is configuration locked? ─────────────────────────────────────────────
var Context.configLocked: Boolean
    get() = Prefs.sp(this).getBoolean(Prefs.KEY_CONFIG_LOCKED, false)
    set(v) = Prefs.sp(this).edit { putBoolean(Prefs.KEY_CONFIG_LOCKED, v) }

// ── Upload network type ──────────────────────────────────────────────────
var Context.uploadNetworkType: Prefs.NetworkTypeChoice
    get() {
        val name = Prefs.sp(this).getString(Prefs.KEY_NETWORK_TYPE, Prefs.NetworkTypeChoice.BOTH.name)
        return try { Prefs.NetworkTypeChoice.valueOf(name!!) } catch (e: Exception) { Prefs.NetworkTypeChoice.BOTH }
    }
    set(v) = Prefs.sp(this).edit { putString(Prefs.KEY_NETWORK_TYPE, v.name) }

// ── Display names for confirmation ────────────────────────────────────────
var Context.botName: String
    get() = Prefs.sp(this).getString(Prefs.KEY_BOT_NAME, "") ?: ""
    set(v) = Prefs.sp(this).edit { putString(Prefs.KEY_BOT_NAME, v) }

var Context.channelName: String
    get() = Prefs.sp(this).getString(Prefs.KEY_CHANNEL_NAME, "") ?: ""
    set(v) = Prefs.sp(this).edit { putString(Prefs.KEY_CHANNEL_NAME, v) }

// ── Timestamp of the last successful upload ───────────────────────────────
var Context.lastSyncedTs: Long
    get() = Prefs.sp(this).getLong(Prefs.KEY_LAST_SYNCED, 0L)
    set(v) = Prefs.sp(this).edit { putLong(Prefs.KEY_LAST_SYNCED, v) }

// ── Theming ───────────────────────────────────────────────────────────────
var Context.selectedTheme: Prefs.ThemeChoice
    get() {
        val name = Prefs.sp(this).getString(Prefs.KEY_SELECTED_THEME, Prefs.ThemeChoice.LIGHT.name)
        return try { Prefs.ThemeChoice.valueOf(name!!) } catch (e: Exception) { Prefs.ThemeChoice.LIGHT }
    }
    set(v) = Prefs.sp(this).edit { putString(Prefs.KEY_SELECTED_THEME, v.name) }

/** Returns true if both token and channel are configured. */
fun Context.isConfigured(): Boolean =
    botToken.isNotBlank() && channelId.isNotBlank()
