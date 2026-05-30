package com.adidev.valtsky.sync

import android.content.Context
import android.util.Log
import com.adidev.valtsky.data.botToken
import com.adidev.valtsky.data.channelId
import com.adidev.valtsky.data.useOriginalQuality
import com.adidev.valtsky.data.lastSyncedTs
import com.adidev.valtsky.data.resetFlag
import com.adidev.valtsky.data.freshStartFlag
import com.adidev.valtsky.data.uploadNetworkType
import com.adidev.valtsky.data.uploadPaused
import com.adidev.valtsky.data.Prefs
import com.adidev.valtsky.data.db.AppDatabase
import com.adidev.valtsky.data.db.MediaItem
import com.adidev.valtsky.telegram.TelegramApi
import com.adidev.valtsky.util.FileUtils
import com.adidev.valtsky.service.PhotoMonitorService
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*

class SyncEngine(private val context: Context) {
    private val db = AppDatabase.getInstance(context)
    private val dao = db.mediaDao()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mutex = Mutex()
    private var syncJob: Job? = null

    companion object {
        private const val TAG = "SyncEngine"
        private const val MAX_TELEGRAM_SIZE = 50 * 1024 * 1024L
    }

    fun startSync() {
        if (syncJob?.isActive == true) return
        syncJob = scope.launch {
            try {
                mutex.withLock {
                    processQueue()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Sync process failed", e)
            }
        }
    }

    fun stopSync() {
        syncJob?.cancel()
    }

    private suspend fun processQueue() {
        Log.d(TAG, "Starting processQueue loop")
        var itemsProcessedInThisRun = 0

        while (currentCoroutineContext().isActive) {
            // Requirement Feature 4: Pause check
            while (context.uploadPaused) {
                Log.d(TAG, "Upload paused. Waiting...")
                delay(3000)
            }

            // Check Network Preference
            if (!isNetworkAllowed()) {
                Log.w(TAG, "Network not allowed by preferences. Waiting 30s...")
                delay(30000)
                continue
            }

            val item = dao.getNextPending()
            
            if (item == null) {
                // Requirement Feature 2 & Deep Reset: Only mark as complete if we actually processed some items
                // or if we have waited a bit to ensure the scanner is done.
                if (itemsProcessedInThisRun > 0 || (!context.resetFlag && !context.freshStartFlag && !PhotoMonitorService.isInitialScanRunning)) {
                    if (context.resetFlag) {
                        context.resetFlag = false
                        Log.i(TAG, "Full reset sync complete. Normal sync resuming.")
                    }
                    if (context.freshStartFlag) {
                        context.freshStartFlag = false
                        Log.i(TAG, "Fresh start sync complete. Normal sync resuming.")
                    }
                    Log.d(TAG, "Queue empty and scan finished. Exiting processQueue.")
                    break
                } else {
                    // We are in reset mode or scanning. The scanner might still be working.
                    // Wait a bit and check again.
                    Log.d(TAG, "Queue empty but scan in progress or in Reset mode. Waiting for scanner...")
                    delay(5000)
                    continue
                }
            }
            
            itemsProcessedInThisRun++
            
            // Check if file still exists before attempting anything
            val file = File(item.filePath)
            if (!file.exists()) {
                Log.w(TAG, "File not found: ${item.filePath}. Marking as FAILED.")
                item.status = MediaItem.STATUS_FAILED
                item.errorReason = "File deleted from device"
                dao.update(item)
                continue
            }

            // Requirement Step 5 & Deep Reset: Final safety check
            val isFullScanMode = context.freshStartFlag || context.resetFlag
            if (!isFullScanMode && item.dateTaken <= context.lastSyncedTs) {
                Log.i(TAG, "Skipping stale item: ${item.filePath} (Date: ${item.dateTaken} <= Last: ${context.lastSyncedTs})")
                item.status = MediaItem.STATUS_DONE
                item.errorReason = "Already synced (timestamp check)"
                dao.update(item)
                continue
            }

            // Mark as uploading
            item.status = MediaItem.STATUS_UPLOADING
            item.updatedAt = System.currentTimeMillis()
            dao.update(item)

            // Deduplication: Compute Hash
            val hashStr: String? = FileUtils.getFileHash(file)
            if (hashStr != null) {
                // Save hash for future deduplication even if this is the first time we see it
                item.fileHash = hashStr
                dao.update(item)

                val existing = dao.findByHash(hashStr)
                // If existing is NOT the current item and is already DONE
                if (existing != null && existing.filePath != item.filePath && existing.status == MediaItem.STATUS_DONE) {
                    Log.i(TAG, "Deduplication: Skipping $hashStr (already uploaded via ${existing.filePath})")
                    item.status = MediaItem.STATUS_DONE
                    item.telegramMessageId = existing.telegramMessageId
                    dao.update(item)
                    
                    // Requirement Step 3: Update timestamp even on skip if it's newer
                    if (item.dateTaken > context.lastSyncedTs) {
                        context.lastSyncedTs = item.dateTaken
                    }
                    continue
                }
            }

            val result = try {
                withTimeout(65000) { // Slightly more than 1 min to allow OkHttp to time out first
                    handleLargeAndUpload(item, file)
                }
            } catch (e: TimeoutCancellationException) {
                Log.e(TAG, "Upload timed out for ${item.filePath}")
                TelegramApi.UploadResult.Failure("Upload timeout (> 1 min)")
            } catch (e: Exception) {
                Log.e(TAG, "Upload error for ${item.filePath}", e)
                TelegramApi.UploadResult.Failure("Upload error: ${e.message}")
            }
            
            if (result is TelegramApi.UploadResult.Success) {
                item.status = MediaItem.STATUS_DONE
                item.telegramMessageId = result.telegramMessageId
                item.updatedAt = System.currentTimeMillis()
                dao.update(item)
                
                // Requirement Step 3: Update lastSyncedTimestamp immediately after successful individual upload
                if (item.dateTaken > context.lastSyncedTs) {
                    context.lastSyncedTs = item.dateTaken
                    Log.i(TAG, "Successfully uploaded ${item.filePath}. Updated lastSyncedTs to ${item.dateTaken}")
                }

                // Medium delay to avoid rate limits (Telegram likes 1-2s between messages)
                delay(2500)
            } else {
                Log.e(TAG, "Failed to upload ${item.filePath}: $result")
                if (result is TelegramApi.UploadResult.TelegramError && result.code == 429) {
                    val waitSeconds = result.retryAfterSeconds ?: 30
                    Log.w(TAG, "Rate limited. Waiting $waitSeconds seconds.")
                    // Reset to PENDING so it's picked up again by getNextPending
                    item.status = MediaItem.STATUS_PENDING
                    item.errorReason = "Rate limited"
                    dao.update(item)
                    delay(waitSeconds * 1000L)
                } else {
                    item.status = MediaItem.STATUS_FAILED
                    item.errorReason = when (result) {
                        is TelegramApi.UploadResult.Failure -> result.message
                        is TelegramApi.UploadResult.TelegramError -> "Telegram Error ${result.code}: ${result.description}"
                        else -> "Unknown error"
                    }
                    item.retryCount++
                    item.updatedAt = System.currentTimeMillis()
                    dao.update(item)
                    // Wait before retrying next item
                    delay(5000)
                }
            }
        }
    }

    private suspend fun handleLargeAndUpload(item: MediaItem, file: File): TelegramApi.UploadResult {
        if (file.length() <= MAX_TELEGRAM_SIZE) {
            return uploadItem(item, file)
        }

        Log.i(TAG, "Large file detected: ${file.name} (${file.length()}). Attempting compression...")
        val compressed = compressFile(file, item.mimeType)
        return if (compressed != null && compressed.length() <= MAX_TELEGRAM_SIZE) {
            val res = uploadItem(item, compressed)
            compressed.delete()
            res
        } else {
            Log.e(TAG, "File still too large after compression or compression not possible: ${file.name}")
            TelegramApi.UploadResult.Failure("File too large (> 50MB) and compression failed")
        }
    }

    private fun compressFile(file: File, mimeType: String): File? {
        val tempFile = File(context.cacheDir, "compressed_${file.name}")
        return if (mimeType.startsWith("image/")) {
            compressImage(file, tempFile)
        } else {
            // Video compression removed as requested (previously fallback to split, but split is now removed)
            null
        }
    }

    private fun compressImage(src: File, dst: File): File? {
        return try {
            val bitmap = BitmapFactory.decodeFile(src.absolutePath)
            var quality = 85
            var size = Long.MAX_VALUE
            while (quality > 10 && size > 10 * 1024 * 1024) {
                val out = FileOutputStream(dst)
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                out.close()
                size = dst.length()
                quality -= 10
            }
            dst
        } catch (e: Exception) {
            null
        }
    }

    private fun isNetworkAllowed(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val net = cm.activeNetwork ?: return false
        val cap = cm.getNetworkCapabilities(net) ?: return false
        
        val isWifi = cap.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        val isMobile = cap.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        
        return when (context.uploadNetworkType) {
            Prefs.NetworkTypeChoice.WIFI -> isWifi
            Prefs.NetworkTypeChoice.MOBILE -> isMobile
            Prefs.NetworkTypeChoice.BOTH -> isWifi || isMobile
        }
    }

    private suspend fun uploadItem(item: MediaItem, file: File): TelegramApi.UploadResult {
        val token = context.botToken
        val channel = context.channelId
        if (token.isBlank() || channel.isBlank()) return TelegramApi.UploadResult.Failure("Not configured")

        val dateStr = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.getDefault()).format(Date(item.dateTaken))
        val caption = "${file.name}\nDate: $dateStr"

        Log.d(TAG, "Uploading ${file.name} (Size: ${item.fileSize}) to $channel")

        return try {
            TelegramApi.sendMediaWithCaption(token, channel, file, caption, context.useOriginalQuality)
        } catch (e: Exception) {
            Log.e(TAG, "Upload failed: ${e.message}")
            TelegramApi.UploadResult.Failure(e.message ?: "Unknown error")
        }
    }
}
