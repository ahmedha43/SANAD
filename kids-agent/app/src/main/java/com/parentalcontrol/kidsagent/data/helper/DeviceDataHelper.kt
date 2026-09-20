package com.parentalcontrol.kidsagent.data.helper

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import android.provider.MediaStore
import android.util.Log
import com.parentalcontrol.kidsagent.data.model.KidContactItem
import com.parentalcontrol.kidsagent.data.model.KidFileItem
import com.parentalcontrol.kidsagent.data.model.KidSmsItem

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

    // 3. Fetch recent Media & Photos from MediaStore
    fun getRecentFiles(limit: Int = 50): List<KidFileItem> {
        val files = mutableListOf<KidFileItem>()
        try {
            val uri: Uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val projection = arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATA,
                MediaStore.Images.Media.SIZE,
                MediaStore.Images.Media.MIME_TYPE,
                MediaStore.Images.Media.DATE_ADDED
            )
            val cursor: Cursor? = context.contentResolver.query(
                uri, projection, null, null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC"
            )
            cursor?.use {
                val nameIdx = it.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
                val dataIdx = it.getColumnIndex(MediaStore.Images.Media.DATA)
                val sizeIdx = it.getColumnIndex(MediaStore.Images.Media.SIZE)
                val mimeIdx = it.getColumnIndex(MediaStore.Images.Media.MIME_TYPE)
                val dateIdx = it.getColumnIndex(MediaStore.Images.Media.DATE_ADDED)
                var count = 0
                while (it.moveToNext() && count < limit) {
                    val name = if (nameIdx != -1) it.getString(nameIdx) ?: "Image" else "Image"
                    val path = if (dataIdx != -1) it.getString(dataIdx) ?: "" else ""
                    val size = if (sizeIdx != -1) it.getLong(sizeIdx) else 0L
                    val mime = if (mimeIdx != -1) it.getString(mimeIdx) ?: "image/jpeg" else "image/jpeg"
                    val dateAdded = if (dateIdx != -1) it.getLong(dateIdx) * 1000L else System.currentTimeMillis()

                    files.add(
                        KidFileItem(
                            fileName = name,
                            filePath = path,
                            fileSize = size,
                            mimeType = mime,
                            timestamp = dateAdded
                        )
                    )
                    count++
                }
            }
            Log.d(TAG, "Fetched ${files.size} media files")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get media files: ${e.message}")
        }
        return files
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

    // 5. Read file data and return base64
    fun getFileBase64(filePath: String, maxDimension: Int = 1280): String? {
        try {
            val file = java.io.File(filePath)
            if (!file.exists() || !file.canRead()) {
                Log.w(TAG, "File not readable: $filePath")
                return null
            }

            val options = android.graphics.BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            android.graphics.BitmapFactory.decodeFile(filePath, options)

            var sampleSize = 1
            var w = options.outWidth
            var h = options.outHeight
            while (w > maxDimension || h > maxDimension) {
                sampleSize *= 2
                w /= 2
                h /= 2
            }

            val decodeOpts = android.graphics.BitmapFactory.Options().apply {
                inSampleSize = sampleSize
            }
            val bitmap = android.graphics.BitmapFactory.decodeFile(filePath, decodeOpts) ?: return null
            val baos = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 75, baos)
            val bytes = baos.toByteArray()
            bitmap.recycle()
            return android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.e(TAG, "Error encoding file $filePath: ${e.message}")
            return null
        }
    }
}
