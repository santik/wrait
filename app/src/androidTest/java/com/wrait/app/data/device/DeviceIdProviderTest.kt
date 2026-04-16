package com.wrait.app.data.device

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.WraitStorageConfig
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DeviceIdProviderTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Before
    fun clearStoredId() {
        // Remove any previously stored device ID so each test starts clean.
        context.getSharedPreferences(WraitStorageConfig.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(WraitStorageConfig.KEY_DEVICE_ID)
            .apply()
    }

    @Test
    fun getOrStore_returns64CharLowercaseHex() {
        val provider = DeviceIdProvider(context)

        val id = provider.getOrStore()

        assertTrue(
            "Device ID must be 64 lowercase hex chars, got: $id",
            id.matches(Regex("^[0-9a-f]{64}$"))
        )
    }

    @Test
    fun getOrStore_isIdempotent() {
        val provider = DeviceIdProvider(context)

        val first = provider.getOrStore()
        val second = provider.getOrStore()

        assertTrue("Both calls must return the same device ID", first == second)
    }

    @Test
    fun getOrStore_storesEncryptedValue() {
        val provider = DeviceIdProvider(context)

        val plainId = provider.getOrStore()

        val stored = context
            .getSharedPreferences(WraitStorageConfig.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(WraitStorageConfig.KEY_DEVICE_ID, null)

        assertTrue("wrait_prefs must contain device_id after getOrStore()", stored != null)
        assertNotEquals(
            "Stored value must be ciphertext, not the plain device ID",
            plainId,
            stored
        )
    }
}
