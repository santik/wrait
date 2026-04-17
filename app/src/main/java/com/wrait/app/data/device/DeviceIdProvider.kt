package com.wrait.app.data.device

import android.annotation.SuppressLint
import android.content.Context
import android.provider.Settings
import android.util.Base64
import android.util.Log
import androidx.core.content.edit
import com.google.crypto.tink.Aead
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.RegistryConfiguration
import com.google.crypto.tink.aead.AeadConfig
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import com.wrait.app.data.WraitStorageConfig
import dagger.hilt.android.qualifiers.ApplicationContext
import java.security.GeneralSecurityException
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeviceIdProvider @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    init {
        try {
            AeadConfig.register()
        } catch (e: GeneralSecurityException) {
            Log.e(TAG, "Tink AEAD registration failed — device ID may not work", e)
        }
    }

    /**
     * Returns the stored device ID if one has already been persisted (decrypted from
     * SharedPreferences), otherwise derives it fresh, encrypts it with AES256-GCM, stores it,
     * and returns it.
     *
     * The device ID is SHA-256 of "${ANDROID_ID}wrait-v1" encoded as lowercase hex (64 chars).
     * If ANDROID_ID is empty (e.g. some emulators), the input degrades to "wrait-v1" which
     * still produces a stable per-instance value.
     */
    @Synchronized
    @SuppressLint("HardwareIds")
    fun getOrStore(): String {
        val prefs = context.getSharedPreferences(WraitStorageConfig.PREFS_NAME, Context.MODE_PRIVATE)
        val aead = buildAead()

        val stored = prefs.getString(WraitStorageConfig.KEY_DEVICE_ID, null)
        val cachedId: String? = stored?.let {
            try {
                val decrypted = String(
                    aead.decrypt(Base64.decode(it, Base64.NO_WRAP), null),
                    Charsets.UTF_8
                )
                if (decrypted.matches(Regex("^[0-9a-f]{64}$"))) decrypted else null
            } catch (_: Exception) {
                null
            }
        }.also { valid ->
            if (valid == null && stored != null) {
                prefs.edit { remove(WraitStorageConfig.KEY_DEVICE_ID) }
            }
        }
        if (cachedId != null) return cachedId

        val androidId = Settings.Secure.getString(
            context.contentResolver, Settings.Secure.ANDROID_ID
        ) ?: ""
        val deviceId = sha256Hex("${androidId}wrait-v1")

        val encrypted = aead.encrypt(deviceId.toByteArray(Charsets.UTF_8), null)
        prefs.edit {
            putString(WraitStorageConfig.KEY_DEVICE_ID, Base64.encodeToString(encrypted, Base64.NO_WRAP))
        }
        return deviceId
    }

    private fun buildAead(): Aead {
        val keysetHandle = AndroidKeysetManager.Builder()
            .withSharedPref(context, WraitStorageConfig.KEYSET_NAME, WraitStorageConfig.PREFS_NAME)
            .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
            .withMasterKeyUri("android-keystore://${WraitStorageConfig.KEY_ALIAS}")
            .build()
            .keysetHandle
        return keysetHandle.getPrimitive(RegistryConfiguration.get(), Aead::class.java)
    }

    private fun sha256Hex(input: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private companion object {
        const val TAG = "DeviceIdProvider"
    }
}
