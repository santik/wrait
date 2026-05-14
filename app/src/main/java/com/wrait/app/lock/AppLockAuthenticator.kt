package com.wrait.app.lock

import androidx.fragment.app.FragmentActivity

enum class AppLockAuthMethod {
    Biometric,
    DeviceCredential,
}

enum class AppLockAuthError {
    Cancelled,
    SecuritySetupRequired,
    TemporarilyUnavailable,
}

interface AppLockAuthCallback {
    fun onAuthenticationSucceeded(method: AppLockAuthMethod)
    fun onAuthenticationFailed()
    fun onAuthenticationError(error: AppLockAuthError)
}

interface AppLockAuthenticator {
    fun availability(): AppLockAvailability
    fun authenticate()
    fun cancel()
    fun openSecuritySettings()
}

interface AppLockAuthenticatorFactory {
    fun create(
        host: FragmentActivity,
        callback: AppLockAuthCallback,
    ): AppLockAuthenticator
}
