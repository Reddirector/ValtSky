package com.adidev.valtsky.ui

import android.media.ThumbnailUtils
import android.util.Size
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.adidev.valtsky.R
import com.adidev.valtsky.data.db.MediaItem
import com.adidev.valtsky.databinding.FailedItemRowBinding
import java.io.File
import java.util.Locale

class FailedItemsAdapter(
    private val onRetry: (MediaItem) -> Unit
) : ListAdapter<MediaItem, FailedItemsAdapter.ViewHolder>(DiffCallback()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = FailedItemRowBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    inner class ViewHolder(private val binding: FailedItemRowBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: MediaItem) {
            val file = File(item.filePath)
            binding.tvFileName.text = file.name
            
            val sizeStr = formatFileSize(item.fileSize)
            val reason = item.errorReason ?: "Unknown error"
            binding.tvFileInfo.text = "$sizeStr · $reason"

            val isRetrying = item.status == MediaItem.STATUS_UPLOADING
            binding.pbRetrying.visibility = if (isRetrying) View.VISIBLE else View.GONE
            binding.btnRetryItem.isEnabled = !isRetrying
            binding.btnRetryItem.alpha = if (isRetrying) 0.5f else 1.0f

            // Thumbnail
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                    val thumbnail = if (item.mimeType.startsWith("video")) {
                        ThumbnailUtils.createVideoThumbnail(file, Size(120, 120), null)
                    } else {
                        ThumbnailUtils.createImageThumbnail(file, Size(120, 120), null)
                    }
                    if (thumbnail != null) {
                        binding.ivThumbnail.setImageBitmap(thumbnail)
                        binding.ivThumbnail.imageTintList = null
                    } else {
                        setDefaultIcon(item)
                    }
                } else {
                    setDefaultIcon(item)
                }
            } catch (e: Exception) {
                setDefaultIcon(item)
            }

            binding.btnRetryItem.setOnClickListener { onRetry(item) }
        }

        private fun setDefaultIcon(item: MediaItem) {
            binding.ivThumbnail.setImageResource(if (item.mimeType.startsWith("video")) R.drawable.ic_video else R.drawable.ic_photo)
        }

        private fun formatFileSize(size: Long): String {
            if (size <= 0) return "0 B"
            val units = arrayOf("B", "KB", "MB", "GB", "TB")
            val digitGroups = (Math.log10(size.toDouble()) / Math.log10(1024.0)).toInt()
            return String.format(Locale.getDefault(), "%.1f %s", size / Math.pow(1024.0, digitGroups.toDouble()), units[digitGroups])
        }
    }

    class DiffCallback : DiffUtil.ItemCallback<MediaItem>() {
        override fun areItemsTheSame(oldItem: MediaItem, newItem: MediaItem): Boolean {
            return oldItem.filePath == newItem.filePath
        }
        override fun areContentsTheSame(oldItem: MediaItem, newItem: MediaItem): Boolean {
            return oldItem == newItem
        }
    }
}
