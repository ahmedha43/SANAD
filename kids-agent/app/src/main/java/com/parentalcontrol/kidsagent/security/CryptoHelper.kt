package com.parentalcontrol.kidsagent.security

import android.util.Base64
import android.util.Log
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

object CryptoHelper {

    private const val TAG = "CryptoHelper"
    private const val ALGORITHM = "AES/GCM/NoPadding"
    private const val GCM_TAG_LENGTH = 128
    private const val IV_LENGTH = 12
    private const val ITERATIONS = 100000
    private const val KEY_LENGTH = 256
    private val SALT = "ParentalControlSalt2026".toByteArray(Charsets.UTF_8)
    private const val PREFIX = "enc:v1:"

    // Default family passphrase (matches parent dashboard default, can be overridden)
    var familyPassphrase = "ParentSecretPassphrase2026"
    private var cachedKey: SecretKey? = null

    @Synchronized
    private fun getOrCreateKey(): SecretKey {
        if (cachedKey != null) return cachedKey!!
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val spec = PBEKeySpec(familyPassphrase.toCharArray(), SALT, ITERATIONS, KEY_LENGTH)
        val tmp = factory.generateSecret(spec)
        val key = SecretKeySpec(tmp.encoded, "AES")
        cachedKey = key
        return key
    }

    @Synchronized
    fun updatePassphrase(newPassphrase: String) {
        if (newPassphrase.isNotBlank() && newPassphrase != familyPassphrase) {
            familyPassphrase = newPassphrase
            cachedKey = null
            Log.d(TAG, "E2EE family passphrase updated")
        }
    }

    fun encrypt(plaintext: String): String {
        if (plaintext.isBlank()) return plaintext
        return try {
            val key = getOrCreateKey()
            val cipher = Cipher.getInstance(ALGORITHM)
            val iv = ByteArray(IV_LENGTH).apply { SecureRandom().nextBytes(this) }
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.ENCRYPT_MODE, key, spec)

            val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
            val ivB64 = Base64.encodeToString(iv, Base64.NO_WRAP)
            val cipherB64 = Base64.encodeToString(ciphertext, Base64.NO_WRAP)

            "$PREFIX$ivB64:$cipherB64"
        } catch (e: Exception) {
            Log.e(TAG, "Encryption failed: ${e.message}")
            plaintext // Fallback to plaintext if error
        }
    }

    fun decrypt(encryptedText: String): String {
        if (!encryptedText.startsWith(PREFIX)) return encryptedText
        return try {
            val parts = encryptedText.removePrefix(PREFIX).split(":")
            if (parts.size != 2) return encryptedText

            val iv = Base64.decode(parts[0], Base64.NO_WRAP)
            val ciphertext = Base64.decode(parts[1], Base64.NO_WRAP)

            val key = getOrCreateKey()
            val cipher = Cipher.getInstance(ALGORITHM)
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, spec)

            val plainBytes = cipher.doFinal(ciphertext)
            String(plainBytes, Charsets.UTF_8)
        } catch (e: Exception) {
            Log.e(TAG, "Decryption failed: ${e.message}")
            encryptedText
        }
    }
}
