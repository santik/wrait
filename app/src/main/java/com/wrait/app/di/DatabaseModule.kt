package com.wrait.app.di

import android.content.Context
import android.util.Base64
import androidx.core.content.edit
import androidx.room.Room
import com.google.crypto.tink.Aead
import com.google.crypto.tink.aead.AeadConfig
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import com.wrait.app.data.EntryDao
import com.wrait.app.data.WraitDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import net.sqlcipher.database.SQLiteDatabase
import net.sqlcipher.database.SupportFactory
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
        try {
            AeadConfig.register()

            val keysetHandle = AndroidKeysetManager.Builder()
                .withSharedPref(context, "tink_keyset", PREFS_NAME)
                .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
                .withMasterKeyUri("android-keystore://$KEY_ALIAS")
                .build()
                .keysetHandle

            val aead: Aead = keysetHandle.getPrimitive(Aead::class.java)
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
                val passwordString = Base64.encodeToString(encryptedBytes, Base64.NO_WRAP)
                sharedPreferences.edit {
                    putString(DB_PASSWORD_KEY, passwordString)
                }
                password
            }
        } catch (e: Exception) {
            throw IllegalStateException("Failed to initialize Tink or retrieve database password", e)
        }
    }

    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context,
        databasePassword: ByteArray
    ): WraitDatabase {
        // Initialize SQLCipher native libraries
        SQLiteDatabase.loadLibs(context)

        val factory = SupportFactory(databasePassword)
        return Room.databaseBuilder(
            context,
            WraitDatabase::class.java,
            DB_NAME
        )
            .openHelperFactory(factory)
            .fallbackToDestructiveMigration()
            .build()
    }

    @Provides
    fun provideEntryDao(database: WraitDatabase): EntryDao {
        return database.entryDao()
    }
}
