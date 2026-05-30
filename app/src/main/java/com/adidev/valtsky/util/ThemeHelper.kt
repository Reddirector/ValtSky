package com.adidev.valtsky.util

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import com.adidev.valtsky.data.Prefs.ThemeChoice
import com.adidev.valtsky.data.selectedTheme

object ThemeHelper {

    fun applyTheme(context: Context) {
        val theme = context.selectedTheme
        when (theme) {
            ThemeChoice.LIGHT -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
            ThemeChoice.DARK -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        }
    }
}
