package com.adidev.valtsky.data.db

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "media_items",
    indices = [Index(value = ["fileHash"], unique = true)]
)
data class MediaItem(
    @PrimaryKey
    val filePath: String,
    var fileHash: String? = null,
    val mimeType: String,
    val dateTaken: Long,
    val fileSize: Long,
    var status: String,
    var telegramMessageId: Long? = null,
    var errorReason: String? = null,
    var retryCount: Int = 0,
    var updatedAt: Long = System.currentTimeMillis()
) {
    companion object {
        const val STATUS_PENDING = "PENDING"
        const val STATUS_UPLOADING = "UPLOADING"
        const val STATUS_DONE = "DONE"
        const val STATUS_FAILED = "FAILED"
    }
}
