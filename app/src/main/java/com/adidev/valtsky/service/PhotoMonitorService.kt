package com.adidev.valtsky.service

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.adidev.valtsky.R
import com.adidev.valtsky.data.db.AppDatabase
import com.adidev.valtsky.data.db.MediaItem
import com.adidev.valtsky.sync.SyncEngine
import com.adidev.valtsky.ui.MainActivity
import com.adidev.valtsky.data.lastSyncedTs
import com.adidev.valtsky.data.resetFlag
import com.adidev.valtsky.data.freshStartFlag
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class PhotoMonitorService : Service() {

    companion object {
        private const val TAG = "PhotoMonitorService"
        private const val CHANNEL_ID = "vs_monitor_channel"
        private const val NOTIFICATION_ID = 1001
        private const val COMPLETE_NOTIFICATION_ID = 1002
        const val ACTION_START = "com.adidev.valtsky.START"
        const val ACTION_STOP = "com.adidev.valtsky.STOP"
        const val ACTION_RETRY = "com.adidev.valtsky.RETRY"
        const val ACTION_REFRESH = "com.adidev.valtsky.REFRESH"
        const val ACTION_PAUSE_UPLOAD = "ACTION_PAUSE_UPLOAD"
        const val ACTION_RESUME_UPLOAD = "ACTION_RESUME_UPLOAD"
        
        @Volatile
        var isInitialScanRunning = false
            private set
    }

    private lateinit var syncEngine: SyncEngine
    private var observer: MediaStoreObserver? = null
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val handler = Handler(Looper.getMainLooper())
    
    private var totalCount = 0
    private var uploadedCount = 0
    private var pendingCount = 0
    private var totalCountObserver: androidx.lifecycle.Observer<Int>? = null
    private var uploadedCountObserver: androidx.lifecycle.Observer<Int>? = null
    private var pendingCountObserver: androidx.lifecycle.Observer<Int>? = null

    private val connectivityManager by lazy {
        getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            Log.d(TAG, "Network available, starting sync")
            syncEngine.startSync()
        }
    }

    override fun onCreate() {
        super.onCreate()
        
        // Requirement Step 6: First-time setup
        if (lastSyncedTs == 0L) {
            lastSyncedTs = System.currentTimeMillis()
            Log.i(TAG, "First launch: setting lastSyncedTs to current time: $lastSyncedTs")
        }

        syncEngine = SyncEngine(this)
        createNotificationChannel()
        
        val notification = buildNotification("Initializing...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        
        serviceScope.launch {
            AppDatabase.getInstance(this@PhotoMonitorService).mediaDao().resetUploadingToPending()
            observeCounts()
        }

        registerNetworkCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_RETRY -> {
                serviceScope.launch(Dispatchers.IO) {
                    AppDatabase.getInstance(this@PhotoMonitorService).mediaDao().retryAllFailed()
                    syncEngine.startSync()
                }
            }
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh action received. Triggering full scan.")
                serviceScope.launch(Dispatchers.IO) {
                    performInitialScan(true)
                }
            }
            ACTION_PAUSE_UPLOAD -> {
                Log.d(TAG, "Pause upload action received")
                // uploadPaused is handled in Prefs, SyncEngine will pick it up
            }
            ACTION_RESUME_UPLOAD -> {
                Log.d(TAG, "Resume upload action received")
                syncEngine.startSync()
            }
            else -> {
                startMonitoring()
                syncEngine.startSync()
                serviceScope.launch(Dispatchers.IO) {
                    performInitialScan()
                }
            }
        }
        return START_STICKY
    }

    private fun observeCounts() {
        val dao = AppDatabase.getInstance(this).mediaDao()
        totalCountObserver = androidx.lifecycle.Observer { count -> totalCount = count ?: 0 }
        uploadedCountObserver = androidx.lifecycle.Observer { count -> uploadedCount = count ?: 0 }
        pendingCountObserver = androidx.lifecycle.Observer { count ->
            val oldPending = pendingCount
            pendingCount = count ?: 0
            if (oldPending > 0 && pendingCount == 0 && !isInitialScanRunning) {
                showCompletionNotification()
            }
        }
        dao.getTotalCount().observeForever(totalCountObserver!!)
        dao.getUploadedCount().observeForever(uploadedCountObserver!!)
        dao.getPendingCount().observeForever(pendingCountObserver!!)
    }

    private suspend fun performInitialScan(forceFullScan: Boolean = false) {
        isInitialScanRunning = true
        try {
            // Requirement Feature 2 & Deep Reset: If resetFlag/freshStartFlag is true, ignore cutoff
            val isFullScan = forceFullScan || freshStartFlag || resetFlag
            val cutoff = if (isFullScan) 0L else lastSyncedTs
            
            Log.d(TAG, "Performing initial scan. FullScan: $isFullScan, Cutoff: $cutoff")
            
            val dao = AppDatabase.getInstance(this).mediaDao()
            val projection = arrayOf(
                MediaStore.MediaColumns.DATA,
                MediaStore.MediaColumns.MIME_TYPE,
                MediaStore.MediaColumns.DATE_ADDED,
                MediaStore.MediaColumns.SIZE
            )
            
            // Query only files added AFTER cutoff (converted to seconds for MediaStore)
            val selection = if (isFullScan) null else "${MediaStore.MediaColumns.DATE_ADDED} > ?"
            val selectionArgs = if (isFullScan) null else arrayOf((cutoff / 1000).toString())

            val uris = arrayOf(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            )

            for (uri in uris) {
                contentResolver.query(uri, projection, selection, selectionArgs, "${MediaStore.MediaColumns.DATE_ADDED} ASC")?.use { cursor ->
                    val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                    val mimeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
                    val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
                    val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)

                    while (cursor.moveToNext()) {
                        val path = cursor.getString(dataIdx)
                        if (!dao.exists(path)) {
                            val item = MediaItem(
                                filePath = path,
                                mimeType = cursor.getString(mimeIdx) ?: "image/jpeg",
                                dateTaken = cursor.getLong(dateIdx) * 1000,
                                fileSize = cursor.getLong(sizeIdx),
                                status = MediaItem.STATUS_PENDING
                            )
                            dao.insert(item)
                        }
                    }
                }
            }
            Log.d(TAG, "Initial scan complete")
        } finally {
            isInitialScanRunning = false
            syncEngine.startSync()
        }
    }

    private fun startMonitoring() {
        if (observer != null) return
        observer = MediaStoreObserver(this, handler) {
            syncEngine.startSync()
        }
        contentResolver.registerContentObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, observer!!)
        contentResolver.registerContentObserver(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true, observer!!)
    }

    private fun registerNetworkCallback() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager.registerNetworkCallback(request, networkCallback)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Gallery Monitor", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun showCompletionNotification() {
        val dao = AppDatabase.getInstance(this).mediaDao()
        serviceScope.launch(Dispatchers.IO) {
            val uploaded = dao.getUploadedCountOnce() // I'll add this to DAO
            val failed = dao.getFailedCountOnce() // I'll add this to DAO
            
            val title = "ValtSky Backup Complete ✓"
            val body = "$uploaded files uploaded successfully. $failed failed."
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            val openIntent = PendingIntent.getActivity(this@PhotoMonitorService, 0, Intent(this@PhotoMonitorService, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            
            val notification = NotificationCompat.Builder(this@PhotoMonitorService, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.drawable.ic_cloud_upload)
                .setContentIntent(openIntent)
                .setAutoCancel(true)
                .build()
                
            notificationManager.notify(COMPLETE_NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        // Requirement Feature 3: Static foreground notification
        val text = "Uploading your media to Telegram..."
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun buildNotification(text: String): Notification {
        val openIntent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ValtSky Backup Started")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_cloud_upload)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        syncEngine.stopSync()
        observer?.let { 
            try {
                contentResolver.unregisterContentObserver(it)
            } catch (_: Exception) {}
        }
        try {
            connectivityManager.unregisterNetworkCallback(networkCallback)
        } catch (_: Exception) {}
        val dao = AppDatabase.getInstance(this).mediaDao()
        totalCountObserver?.let { dao.getTotalCount().removeObserver(it) }
        uploadedCountObserver?.let { dao.getUploadedCount().removeObserver(it) }
        pendingCountObserver?.let { dao.getPendingCount().removeObserver(it) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
