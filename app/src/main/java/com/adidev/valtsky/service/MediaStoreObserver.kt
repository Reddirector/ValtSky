package com.adidev.valtsky.service

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.provider.MediaStore
import com.adidev.valtsky.data.db.AppDatabase
import com.adidev.valtsky.data.db.MediaItem
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MediaStoreObserver(
    private val context: Context,
    handler: Handler,
    private val onNewMedia: () -> Unit
) : ContentObserver(handler) {

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        if (uri == null) return
        CoroutineScope(Dispatchers.IO).launch {
            val projection = arrayOf(
                MediaStore.MediaColumns.DATA,
                MediaStore.MediaColumns.MIME_TYPE,
                MediaStore.MediaColumns.DATE_ADDED,
                MediaStore.MediaColumns.SIZE
            )

            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val path = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA))
                    val dao = AppDatabase.getInstance(context).mediaDao()
                    if (!dao.exists(path)) {
                        val item = MediaItem(
                            filePath = path,
                            mimeType = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)) ?: "image/jpeg",
                            dateTaken = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)) * 1000,
                            fileSize = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)),
                            status = MediaItem.STATUS_PENDING
                        )
                        dao.insert(item)
                        onNewMedia()
                    }
                }
            }
        }
    }
}
