package com.adidev.valtsky.util

import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

object FileUtils {
    /**
     * Computes MD5 hash of a file for deduplication.
     */
    fun getFileHash(file: File): String? {
        return try {
            val md = MessageDigest.getInstance("MD5")
            val fis = FileInputStream(file)
            val buffer = ByteArray(8192)
            var n: Int
            while (fis.read(buffer).also { n = it } != -1) {
                md.update(buffer, 0, n)
            }
            fis.close()
            md.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        }
    }
}
