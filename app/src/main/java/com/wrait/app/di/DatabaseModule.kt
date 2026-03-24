package com.wrait.app.di

import android.content.Context
import androidx.core.content.edit
import androidx.room.Room
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
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

    @Suppress("DEPRECATION")
    @Provides
    @Singleton
    fun provideDatabasePassword(@ApplicationContext context: Context): ByteArray {
        try {
            val masterKey = MasterKey.Builder(context, KEY_ALIAS)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val sharedPreferences = EncryptedSharedPreferences.create(
                context,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            val storedPassword = sharedPreferences.getString(DB_PASSWORD_KEY, null)
            return if (storedPassword != null) {
                val passwordBytes = storedPassword.toByteArray(Charsets.ISO_8859_1)
                if (passwordBytes.size != 32) {
                    throw IllegalStateException("Stored database password has invalid length: ${passwordBytes.size}")
                }
                passwordBytes
            } else {
                val password = ByteArray(32).apply { SecureRandom().nextBytes(this) }
                val passwordString = password.toString(Charsets.ISO_8859_1)
                sharedPreferences.edit {
                    putString(DB_PASSWORD_KEY, passwordString)
                }
                password
            }
        } catch (e: Exception) {
            throw IllegalStateException("Failed to initialize Keystore or retrieve database password", e)
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
