package com.adidev.valtsky.data.db

import androidx.lifecycle.LiveData
import androidx.room.*

@Dao
interface MediaDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(item: MediaItem): Long

    @Update
    suspend fun update(item: MediaItem)

    @Query("SELECT * FROM media_items WHERE filePath = :path")
    suspend fun getItem(path: String): MediaItem?

    @Query("SELECT * FROM media_items WHERE status = 'PENDING' ORDER BY dateTaken ASC LIMIT 1")
    suspend fun getNextPending(): MediaItem?

    @Query("SELECT * FROM media_items WHERE status = 'PENDING' ORDER BY dateTaken ASC")
    suspend fun getAllPending(): List<MediaItem>

    @Query("UPDATE media_items SET status = 'PENDING' WHERE status = 'UPLOADING'")
    suspend fun resetUploadingToPending()

    @Query("SELECT COUNT(*) FROM media_items")
    fun getTotalCount(): LiveData<Int>

    @Query("SELECT COUNT(*) FROM media_items WHERE status = 'DONE'")
    fun getUploadedCount(): LiveData<Int>

    @Query("SELECT COUNT(*) FROM media_items WHERE status = 'DONE'")
    suspend fun getUploadedCountOnce(): Int

    @Query("SELECT COUNT(*) FROM media_items WHERE status = 'PENDING' OR status = 'UPLOADING'")
    fun getPendingCount(): LiveData<Int>

    @Query("SELECT COUNT(*) FROM media_items WHERE status = 'FAILED'")
    fun getFailedCount(): LiveData<Int>

    @Query("SELECT COUNT(*) FROM media_items WHERE status = 'FAILED'")
    suspend fun getFailedCountOnce(): Int

    @Query("SELECT EXISTS(SELECT 1 FROM media_items WHERE filePath = :path)")
    suspend fun exists(path: String): Boolean

    @Query("SELECT * FROM media_items WHERE fileHash = :hash LIMIT 1")
    suspend fun findByHash(hash: String): MediaItem?

    @Query("UPDATE media_items SET status = 'PENDING', retryCount = 0 WHERE status = 'FAILED'")
    suspend fun retryAllFailed()

    @Query("SELECT * FROM media_items WHERE status = 'FAILED' ORDER BY updatedAt DESC")
    fun getFailedItems(): LiveData<List<MediaItem>>

    @Query("SELECT * FROM media_items")
    suspend fun getAllItemsList(): List<MediaItem>

    @Query("SELECT * FROM media_items WHERE status = 'FAILED'")
    suspend fun getFailedItemsList(): List<MediaItem>

    @Query("UPDATE media_items SET status = 'PENDING', retryCount = 0 WHERE filePath = :path")
    suspend fun retrySingle(path: String)

    @Query("UPDATE media_items SET status = 'DONE', errorReason = 'Manually Uploaded' WHERE filePath IN (:paths)")
    suspend fun markAsManuallyDone(paths: List<String>)

    @Query("DELETE FROM media_items WHERE status = 'FAILED'")
    suspend fun clearFailed()

    @Query("DELETE FROM media_items")
    suspend fun deleteAll()
}
