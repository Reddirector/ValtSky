package com.adidev.valtsky

import android.app.Application
import androidx.work.Configuration

class ValtSkyApp : Application(), Configuration.Provider {

    override fun onCreate() {
        super.onCreate()
        // WorkManager is initialised lazily via the Configuration.Provider interface.
        // No extra init needed here — keep it minimal.
    }

    /**
     * Custom WorkManager configuration — keeps a small thread pool so background
     * uploads don't exhaust the device's thread budget on low-end Xiaomi phones.
     */
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(android.util.Log.INFO)
            .setMaxSchedulerLimit(10)
            .build()
}
