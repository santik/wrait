package com.wrait.app.di

import android.content.Context
import android.util.Base64
import androidx.core.content.edit
import androidx.room.Room
import com.google.crypto.tink.Aead
import com.google.crypto.tink.aead.AeadConfig
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import com.google.crypto.tink.RegistryConfiguration
import com.wrait.app.data.EntryDao
import com.wrait.app.data.WraitDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory
import java.security.SecureRandom
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    private const val DB_NAME = "wrait_db"
    private const val PREFS_NAME = "wrait_prefs"
    private const val KEY_ALIAS = "wraite_db_key"
    private const val DB_PASSWORD_KEY = "db_password"

    @Provides
    @Singleton
    fun provideDatabasePassword(@ApplicationContext context: Context): ByteArray {
        return try {
            loadOrCreatePassword(context)
        } catch (e: Exception) {
            // The Android Keystore key is gone (device reset, lock screen removed, etc.).
            // The Tink keyset stored in SharedPreferences can no longer be decrypted.
            // Clear all encrypted state and the database, then start fresh.
            clearEncryptedState(context)
            try {
                loadOrCreatePassword(context)
            } catch (retryException: Exception) {
                throw IllegalStateException(
                    "Failed to initialize database encryption after keystore recovery",
                    retryException
                )
            }
        }
    }

    private fun loadOrCreatePassword(context: Context): ByteArray {
        AeadConfig.register()

        val keysetHandle = AndroidKeysetManager.Builder()
            .withSharedPref(context, "tink_keyset", PREFS_NAME)
            .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
            .withMasterKeyUri("android-keystore://$KEY_ALIAS")
            .build()
            .keysetHandle

        val aead: Aead = keysetHandle.getPrimitive(RegistryConfiguration.get(), Aead::class.java)
        val sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val storedPassword = sharedPreferences.getString(DB_PASSWORD_KEY, null)
        return if (storedPassword != null) {
            val encryptedBytes = Base64.decode(storedPassword, Base64.NO_WRAP)
            val passwordBytes = aead.decrypt(encryptedBytes, null)
            if (passwordBytes.size != 32) {
                throw IllegalStateException("Stored database password has invalid length: ${passwordBytes.size}")
            }
            passwordBytes
        } else {
            val password = ByteArray(32).apply { SecureRandom().nextBytes(this) }
            val encryptedBytes = aead.encrypt(password, null)
            sharedPreferences.edit {
                putString(DB_PASSWORD_KEY, Base64.encodeToString(encryptedBytes, Base64.NO_WRAP))
            }
            password
        }
    }

    private fun clearEncryptedState(context: Context) {
        // Remove the Tink keyset and the encrypted DB password — both are unreadable without the key
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit {
            remove("tink_keyset")
            remove(DB_PASSWORD_KEY)
        }
        // Delete the database; it cannot be opened without the original password
        listOf(DB_NAME, "$DB_NAME-shm", "$DB_NAME-wal").forEach { name ->
            context.getDatabasePath(name).delete()
        }
        // Remove the stale Keystore entry so Tink can create a fresh one
        try {
            val ks = java.security.KeyStore.getInstance("AndroidKeyStore").also { it.load(null) }
            if (ks.containsAlias(KEY_ALIAS)) ks.deleteEntry(KEY_ALIAS)
        } catch (_: Exception) { /* best-effort */ }
    }

    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context,
        databasePassword: ByteArray
    ): WraitDatabase {
        // Initialize SQLCipher native libraries
        System.loadLibrary("sqlcipher")

        val factory = SupportOpenHelperFactory(databasePassword)
        return Room.databaseBuilder(
            context,
            WraitDatabase::class.java,
            DB_NAME
        )
            .openHelperFactory(factory)
            .fallbackToDestructiveMigration(true)
            .build()
    }

    @Provides
    fun provideEntryDao(database: WraitDatabase): EntryDao {
        return database.entryDao()
    }
}
