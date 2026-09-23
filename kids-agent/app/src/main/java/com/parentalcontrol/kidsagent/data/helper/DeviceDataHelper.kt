package com.parentalcontrol.kidsagent.data.helper

import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import android.util.Size
import android.webkit.MimeTypeMap
import com.parentalcontrol.kidsagent.data.model.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream

class DeviceDataHelper(private val context: Context) {

    companion object {
        private const val TAG = "DeviceDataHelper"
    }

    // 1. Fetch phone contacts
    fun getContacts(): List<KidContactItem> {
        val contacts = mutableListOf<KidContactItem>()
        try {
            val uri: Uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            val cursor: Cursor? = context.contentResolver.query(
                uri, projection, null, null,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )
            cursor?.use {
                val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                val seen = mutableSetOf<String>()
                while (it.moveToNext()) {
                    val name = if (nameIdx != -1) it.getString(nameIdx) ?: "Unknown" else "Unknown"
                    val number = if (numIdx != -1) it.getString(numIdx) ?: "" else ""
                    val key = "$name|$number"
                    if (number.isNotBlank() && !seen.contains(key)) {
                        seen.add(key)
                        contacts.add(KidContactItem(name = name, phoneNumber = number))
                    }
                }
            }
            Log.d(TAG, "Fetched ${contacts.size} contacts")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get contacts: ${e.message}")
        }
        return contacts
    }

    // 2. Fetch SMS messages (Inbox and Sent)
    fun getSmsMessages(limit: Int = 100): List<KidSmsItem> {
        val messages = mutableListOf<KidSmsItem>()
        try {
            val uri = Uri.parse("content://sms")
            val projection = arrayOf("_id", "address", "body", "date", "type")
            val cursor: Cursor? = context.contentResolver.query(
                uri, projection, null, null, "date DESC"
            )
            cursor?.use {
                val addrIdx = it.getColumnIndex("address")
                val bodyIdx = it.getColumnIndex("body")
                val dateIdx = it.getColumnIndex("date")
                val typeIdx = it.getColumnIndex("type")
                var count = 0
                while (it.moveToNext() && count < limit) {
                    val sender = if (addrIdx != -1) it.getString(addrIdx) ?: "Unknown" else "Unknown"
                    val body = if (bodyIdx != -1) it.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx != -1) it.getLong(dateIdx) else System.currentTimeMillis()
                    val type = if (typeIdx != -1) it.getInt(typeIdx) else 1 // 1 = inbox, 2 = sent
                    messages.add(
                        KidSmsItem(
                            sender = sender,
                            body = body,
                            isIncoming = (type == 1),
                            timestamp = date
                        )
                    )
                    count++
                }
            }
            Log.d(TAG, "Fetched ${messages.size} SMS messages")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get SMS messages: ${e.message}")
        }
        return messages
    }

    // 3. Fetch recent Media & Photos from MediaStore with real Base64 thumbnails
    fun getRecentFiles(limit: Int = 50): List<KidFileItem> {
        val files = mutableListOf<KidFileItem>()
        try {
            // A. Query Images
            val imageUri: Uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val imageProjection = arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATA,
                MediaStore.Images.Media.SIZE,
                MediaStore.Images.Media.MIME_TYPE,
                MediaStore.Images.Media.DATE_ADDED
            )
            val imageCursor: Cursor? = context.contentResolver.query(
                imageUri, imageProjection, null, null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC"
            )
            imageCursor?.use {
                val idIdx = it.getColumnIndex(MediaStore.Images.Media._ID)
                val nameIdx = it.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
                val dataIdx = it.getColumnIndex(MediaStore.Images.Media.DATA)
                val sizeIdx = it.getColumnIndex(MediaStore.Images.Media.SIZE)
                val mimeIdx = it.getColumnIndex(MediaStore.Images.Media.MIME_TYPE)
                val dateIdx = it.getColumnIndex(MediaStore.Images.Media.DATE_ADDED)
                var count = 0
                while (it.moveToNext() && count < (limit * 0.8).toInt()) {
                    val id = if (idIdx != -1) it.getLong(idIdx) else 0L
                    val name = if (nameIdx != -1) it.getString(nameIdx) ?: "Image" else "Image"
                    val path = if (dataIdx != -1) it.getString(dataIdx) ?: "" else ""
                    val size = if (sizeIdx != -1) it.getLong(sizeIdx) else 0L
                    val mime = if (mimeIdx != -1) it.getString(mimeIdx) ?: "image/jpeg" else "image/jpeg"
                    val dateAdded = if (dateIdx != -1) it.getLong(dateIdx) * 1000L else System.currentTimeMillis()

                    val contentUri = ContentUris.withAppendedId(imageUri, id)
                    val thumbBase64 = createThumbnailBase64(contentUri, mime, 180)

                    files.add(
                        KidFileItem(
                            fileName = name,
                            filePath = if (path.isNotBlank()) path else contentUri.toString(),
                            fileSize = size,
                            mimeType = mime,
                            thumbnailBase64 = thumbBase64,
                            timestamp = dateAdded
                        )
                    )
                    count++
                }
            }

            // B. Query Videos
            val videoUri: Uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            val videoProjection = arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.DATA,
                MediaStore.Video.Media.SIZE,
                MediaStore.Video.Media.MIME_TYPE,
                MediaStore.Video.Media.DATE_ADDED
            )
            val videoCursor: Cursor? = context.contentResolver.query(
                videoUri, videoProjection, null, null,
                "${MediaStore.Video.Media.DATE_ADDED} DESC"
            )
            videoCursor?.use {
                val idIdx = it.getColumnIndex(MediaStore.Video.Media._ID)
                val nameIdx = it.getColumnIndex(MediaStore.Video.Media.DISPLAY_NAME)
                val dataIdx = it.getColumnIndex(MediaStore.Video.Media.DATA)
                val sizeIdx = it.getColumnIndex(MediaStore.Video.Media.SIZE)
                val mimeIdx = it.getColumnIndex(MediaStore.Video.Media.MIME_TYPE)
                val dateIdx = it.getColumnIndex(MediaStore.Video.Media.DATE_ADDED)
                var count = 0
                while (it.moveToNext() && count < (limit * 0.2).toInt()) {
                    val id = if (idIdx != -1) it.getLong(idIdx) else 0L
                    val name = if (nameIdx != -1) it.getString(nameIdx) ?: "Video" else "Video"
                    val path = if (dataIdx != -1) it.getString(dataIdx) ?: "" else ""
                    val size = if (sizeIdx != -1) it.getLong(sizeIdx) else 0L
                    val mime = if (mimeIdx != -1) it.getString(mimeIdx) ?: "video/mp4" else "video/mp4"
                    val dateAdded = if (dateIdx != -1) it.getLong(dateIdx) * 1000L else System.currentTimeMillis()

                    val contentUri = ContentUris.withAppendedId(videoUri, id)
                    val thumbBase64 = createThumbnailBase64(contentUri, mime, 180)

                    files.add(
                        KidFileItem(
                            fileName = name,
                            filePath = if (path.isNotBlank()) path else contentUri.toString(),
                            fileSize = size,
                            mimeType = mime,
                            thumbnailBase64 = thumbBase64,
                            timestamp = dateAdded
                        )
                    )
                    count++
                }
            }

            files.sortByDescending { it.timestamp }
            Log.d(TAG, "Fetched ${files.size} media items with thumbnails")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get media files: ${e.message}")
        }
        return files
    }

    private fun createThumbnailBase64(uri: Uri, mime: String, sizePx: Int): String? {
        return try {
            var bmp: Bitmap? = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                bmp = try {
                    context.contentResolver.loadThumbnail(uri, Size(sizePx, sizePx), null)
                } catch (_: Throwable) {
                    null
                }
            }
            if (bmp == null) {
                context.contentResolver.openInputStream(uri)?.use { stream ->
                    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeStream(stream, null, opts)
                    var inSample = 1
                    while (opts.outWidth / (inSample * 2) >= sizePx && opts.outHeight / (inSample * 2) >= sizePx) {
                        inSample *= 2
                    }
                    val decodeOpts = BitmapFactory.Options().apply { inSampleSize = inSample }
                    context.contentResolver.openInputStream(uri)?.use { s2 ->
                        bmp = BitmapFactory.decodeStream(s2, null, decodeOpts)
                    }
                }
            }
            bmp?.let { b ->
                val scaled = if (b.width > sizePx || b.height > sizePx) {
                    val ratio = Math.min(sizePx.toFloat() / b.width, sizePx.toFloat() / b.height)
                    Bitmap.createScaledBitmap(b, (b.width * ratio).toInt().coerceAtLeast(1), (b.height * ratio).toInt().coerceAtLeast(1), true)
                } else b
                val baos = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, 65, baos)
                if (scaled != b) b.recycle()
                scaled.recycle()
                Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
            }
        } catch (_: Throwable) {
            null
        }
    }

    // 4. Fetch Call Logs
    fun getCallLogs(limit: Int = 50): List<com.parentalcontrol.kidsagent.data.model.KidCallLogItem> {
        val calls = mutableListOf<com.parentalcontrol.kidsagent.data.model.KidCallLogItem>()
        try {
            val uri: Uri = android.provider.CallLog.Calls.CONTENT_URI
            val projection = arrayOf(
                android.provider.CallLog.Calls.NUMBER,
                android.provider.CallLog.Calls.CACHED_NAME,
                android.provider.CallLog.Calls.TYPE,
                android.provider.CallLog.Calls.DURATION,
                android.provider.CallLog.Calls.DATE
            )
            val cursor = context.contentResolver.query(
                uri, projection, null, null,
                "${android.provider.CallLog.Calls.DATE} DESC"
            )
            cursor?.use {
                val numIdx = it.getColumnIndex(android.provider.CallLog.Calls.NUMBER)
                val nameIdx = it.getColumnIndex(android.provider.CallLog.Calls.CACHED_NAME)
                val typeIdx = it.getColumnIndex(android.provider.CallLog.Calls.TYPE)
                val durIdx = it.getColumnIndex(android.provider.CallLog.Calls.DURATION)
                val dateIdx = it.getColumnIndex(android.provider.CallLog.Calls.DATE)
                var count = 0
                while (it.moveToNext() && count < limit) {
                    val number = if (numIdx != -1) it.getString(numIdx) ?: "" else ""
                    val name = if (nameIdx != -1) it.getString(nameIdx) else null
                    val typeVal = if (typeIdx != -1) it.getInt(typeIdx) else android.provider.CallLog.Calls.INCOMING_TYPE
                    val duration = if (durIdx != -1) it.getInt(durIdx) else 0
                    val date = if (dateIdx != -1) it.getLong(dateIdx) else System.currentTimeMillis()

                    val callType = when (typeVal) {
                        android.provider.CallLog.Calls.INCOMING_TYPE -> "INCOMING"
                        android.provider.CallLog.Calls.OUTGOING_TYPE -> "OUTGOING"
                        android.provider.CallLog.Calls.MISSED_TYPE -> "MISSED"
                        android.provider.CallLog.Calls.REJECTED_TYPE -> "REJECTED"
                        else -> "INCOMING"
                    }

                    calls.add(
                        com.parentalcontrol.kidsagent.data.model.KidCallLogItem(
                            number = number,
                            name = name,
                            callType = callType,
                            durationSeconds = duration,
                            timestamp = date
                        )
                    )
                    count++
                }
            }
            Log.d(TAG, "Fetched ${calls.size} call logs")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get call logs: ${e.message}")
        }
        return calls
    }

    // 5. Read file data and return complete FileDataResultPayload
    fun getFileData(filePath: String, maxDimension: Int = 1920): FileDataResultPayload {
        try {
            var inputStream: InputStream? = null
            var fileName = File(filePath).name
            var fileSize = 0L
            var mimeType = "application/octet-stream"

            if (filePath.startsWith("content://")) {
                val uri = Uri.parse(filePath)
                inputStream = context.contentResolver.openInputStream(uri)
                context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameCol = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                        val sizeCol = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
                        val mimeCol = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
                        if (nameCol != -1) fileName = cursor.getString(nameCol) ?: fileName
                        if (sizeCol != -1) fileSize = cursor.getLong(sizeCol)
                        if (mimeCol != -1) mimeType = cursor.getString(mimeCol) ?: mimeType
                    }
                }
            } else {
                val file = File(filePath)
                fileName = file.name
                fileSize = if (file.exists()) file.length() else 0L
                val ext = file.extension.lowercase()
                mimeType = getMimeType(ext)

                if (file.exists() && file.canRead()) {
                    inputStream = file.inputStream()
                } else {
                    // Try to resolve via MediaStore for Scoped Storage compatibility
                    val projection = arrayOf(
                        MediaStore.MediaColumns._ID,
                        MediaStore.MediaColumns.DISPLAY_NAME,
                        MediaStore.MediaColumns.SIZE,
                        MediaStore.MediaColumns.MIME_TYPE
                    )
                    val cursor = context.contentResolver.query(
                        MediaStore.Files.getContentUri("external"),
                        projection,
                        "${MediaStore.MediaColumns.DATA} = ?",
                        arrayOf(filePath),
                        null
                    )
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val id = it.getLong(it.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                            val contentUri = ContentUris.withAppendedId(MediaStore.Files.getContentUri("external"), id)
                            inputStream = context.contentResolver.openInputStream(contentUri)
                            val nameCol = it.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                            val sizeCol = it.getColumnIndex(MediaStore.MediaColumns.SIZE)
                            val mimeCol = it.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
                            if (nameCol != -1) fileName = it.getString(nameCol) ?: fileName
                            if (sizeCol != -1) fileSize = it.getLong(sizeCol)
                            if (mimeCol != -1) mimeType = it.getString(mimeCol) ?: mimeType
                        }
                    }
                }
            }

            val stream = inputStream
            if (stream == null) {
                return FileDataResultPayload(
                    filePath = filePath,
                    fileBase64 = null,
                    fileName = fileName,
                    fileSize = fileSize,
                    mimeType = mimeType,
                    error = "تعذر الوصول للملف أو قراءته من الذاكرة (يرجى التأكد من صلاحية الوصول لكافة الملفات)"
                )
            }

            val isImage = mimeType.startsWith("image/") || fileName.endsWith(".jpg", true) || fileName.endsWith(".png", true) || fileName.endsWith(".jpeg", true) || fileName.endsWith(".webp", true)

            val base64Data: String? = if (isImage) {
                val bytes = stream.use { it.readBytes() }
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)

                var sampleSize = 1
                var w = options.outWidth
                var h = options.outHeight
                while (w > maxDimension || h > maxDimension) {
                    sampleSize *= 2
                    w /= 2
                    h /= 2
                }
                val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, decodeOpts)
                if (bitmap != null) {
                    val baos = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 75, baos)
                    bitmap.recycle()
                    Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
                } else {
                    Base64.encodeToString(bytes, Base64.NO_WRAP)
                }
            } else {
                // Non-image file (PDF, Docs, Audio, Video, Zip) - read up to 15MB
                val maxBytes = 15 * 1024 * 1024 // 15MB
                val bytes = stream.use { s ->
                    val buffer = ByteArray(8192)
                    val baos = ByteArrayOutputStream()
                    var totalRead = 0
                    var read: Int
                    while (s.read(buffer).also { read = it } != -1) {
                        baos.write(buffer, 0, read)
                        totalRead += read
                        if (totalRead >= maxBytes) break
                    }
                    baos.toByteArray()
                }
                Base64.encodeToString(bytes, Base64.NO_WRAP)
            }

            return FileDataResultPayload(
                filePath = filePath,
                fileBase64 = base64Data,
                fileName = fileName,
                fileSize = if (fileSize > 0) fileSize else (base64Data?.length?.toLong() ?: 0L),
                mimeType = mimeType,
                error = if (base64Data == null) "فشل ترميز محتوى الملف" else null
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Error reading file $filePath: ${e.message}", e)
            return FileDataResultPayload(
                filePath = filePath,
                fileBase64 = null,
                fileName = File(filePath).name,
                error = "خطأ أثناء قراءة الملف: ${e.message}"
            )
        }
    }

    // Keep getFileBase64 for backward compatibility
    fun getFileBase64(filePath: String, maxDimension: Int = 1280): String? {
        return getFileData(filePath, maxDimension).fileBase64
    }

    // 6. List directory contents for File Explorer & Transfer
    fun listDirectory(dirPath: String?): DirectoryListResultPayload {
        val rootPath = Environment.getExternalStorageDirectory().absolutePath
        val targetPath = if (dirPath.isNullOrBlank() || dirPath == "/" || dirPath == ".") rootPath else dirPath
        val dir = File(targetPath)

        if (!dir.exists()) {
            return DirectoryListResultPayload(
                currentPath = targetPath,
                parentPath = null,
                items = emptyList(),
                error = "المجلد المحدد غير موجود: $targetPath"
            )
        }

        if (!dir.isDirectory) {
            return DirectoryListResultPayload(
                currentPath = targetPath,
                parentPath = dir.parentFile?.absolutePath,
                items = emptyList(),
                error = "المسار المحدد ليس مجلداً"
            )
        }

        val rawFiles = dir.listFiles()
        if (rawFiles == null) {
            return DirectoryListResultPayload(
                currentPath = targetPath,
                parentPath = if (targetPath == rootPath) null else dir.parentFile?.absolutePath,
                items = emptyList(),
                error = "تعذر قراءة محتويات المجلد (يرجى منح إذن إدارة كافة الملفات All Files Access)"
            )
        }

        val items = rawFiles.map { f ->
            val isDir = f.isDirectory
            val size = if (isDir) 0L else f.length()
            val ext = if (isDir) "" else f.extension.lowercase()
            val mime = if (isDir) "directory" else getMimeType(ext)
            FileExplorerItem(
                name = f.name,
                path = f.absolutePath,
                isDirectory = isDir,
                size = size,
                lastModified = f.lastModified(),
                extension = ext,
                mimeType = mime
            )
        }.sortedWith(compareBy({ !it.isDirectory }, { it.name.lowercase() }))

        val parent = if (targetPath == rootPath || targetPath == "/" || dir.parentFile == null) null else dir.parentFile?.absolutePath

        return DirectoryListResultPayload(
            currentPath = targetPath,
            parentPath = parent,
            items = items,
            error = null
        )
    }

    private fun getMimeType(extension: String): String {
        if (extension.isBlank()) return "application/octet-stream"
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: when (extension) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "mp4" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "pdf" -> "application/pdf"
            "txt" -> "text/plain"
            "zip" -> "application/zip"
            "apk" -> "application/vnd.android.package-archive"
            else -> "application/octet-stream"
        }
    }
}
