package com.wrait.app.data.device

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Lightweight preflight for whether best mode can reasonably attempt a cloud upload.
 *
 * This intentionally answers only the "obviously offline?" question for record start.
 * It is not a guarantee that upload will succeed, since network conditions may still change
 * during recording or before the actual upload begins.
 */
interface NetworkAvailability {
    fun canAttemptCloudUpload(): Boolean
}

@Singleton
class AndroidNetworkAvailability @Inject constructor(
    @ApplicationContext private val context: Context,
) : NetworkAvailability {

    override fun canAttemptCloudUpload(): Boolean {
        return try {
            val connectivityManager = context.getSystemService(ConnectivityManager::class.java)
                ?: run {
                    Log.d(TAG, "Cloud upload preflight failed: no ConnectivityManager")
                    return false
                }
            val activeNetwork = connectivityManager.activeNetwork ?: run {
                Log.d(TAG, "Cloud upload preflight failed: no active network")
                return false
            }
            val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: run {
                Log.d(TAG, "Cloud upload preflight failed: no network capabilities")
                return false
            }

            val hasInternetCapability =
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            if (!hasInternetCapability) {
                Log.d(TAG, "Cloud upload preflight failed: missing INTERNET capability")
            }

            hasInternetCapability
        } catch (securityException: SecurityException) {
            Log.w(
                TAG,
                "Cloud upload preflight failed: missing ACCESS_NETWORK_STATE permission",
                securityException,
            )
            false
        }
    }

    private companion object {
        private const val TAG = "NetworkAvailability"
    }
}
