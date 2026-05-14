package com.wrait.app.lock

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import javax.inject.Inject

class AndroidAppLockAuthenticatorFactory @Inject constructor() : AppLockAuthenticatorFactory {
    override fun create(
        host: FragmentActivity,
        callback: AppLockAuthCallback,
    ): AppLockAuthenticator {
        return AndroidAppLockAuthenticator(host, callback)
    }
}

private class AndroidAppLockAuthenticator(
    private val host: FragmentActivity,
    private val callback: AppLockAuthCallback,
) : AppLockAuthenticator {
    private enum class AuthRoute {
        BiometricCombined,
        BiometricWithDeviceCredentialFallback,
        DeviceCredentialOnly,
        SecuritySetupRequired,
        TemporarilyUnavailable,
    }

    private val keyguardManager: KeyguardManager =
        host.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
    private val biometricManager = BiometricManager.from(host)
    private var prompt: BiometricPrompt? = null

    private val credentialLauncher =
        host.registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == Activity.RESULT_OK) {
                callback.onAuthenticationSucceeded(AppLockAuthMethod.DeviceCredential)
            } else {
                callback.onAuthenticationError(AppLockAuthError.Cancelled)
            }
        }

    override fun availability(): AppLockAvailability {
        return when (resolveAuthRoute()) {
            AuthRoute.BiometricCombined,
            AuthRoute.BiometricWithDeviceCredentialFallback,
            AuthRoute.DeviceCredentialOnly -> AppLockAvailability.Ready
            AuthRoute.SecuritySetupRequired -> AppLockAvailability.SecuritySetupRequired
            AuthRoute.TemporarilyUnavailable -> AppLockAvailability.TemporarilyUnavailable
        }
    }

    override fun authenticate() {
        when (resolveAuthRoute()) {
            AuthRoute.BiometricCombined -> biometricPrompt().authenticate(promptInfoApi30Plus())
            AuthRoute.BiometricWithDeviceCredentialFallback -> {
                when {
                    Build.VERSION.SDK_INT == Build.VERSION_CODES.Q -> {
                        biometricPrompt().authenticate(promptInfoApi29())
                    }
                    else -> biometricPrompt().authenticate(promptInfoPre29())
                }
            }
            AuthRoute.DeviceCredentialOnly -> {
                if (!launchDeviceCredential()) {
                    callback.onAuthenticationError(AppLockAuthError.SecuritySetupRequired)
                }
            }
            AuthRoute.SecuritySetupRequired ->
                callback.onAuthenticationError(AppLockAuthError.SecuritySetupRequired)
            AuthRoute.TemporarilyUnavailable ->
                callback.onAuthenticationError(AppLockAuthError.TemporarilyUnavailable)
        }
    }

    override fun cancel() {
        prompt?.cancelAuthentication()
    }

    override fun openSecuritySettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                putExtra(
                    Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                    BIOMETRIC_STRONG or DEVICE_CREDENTIAL,
                )
            }
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }

        val fallbackIntent = Intent(Settings.ACTION_SETTINGS)
        val launchIntent = if (intent.resolveActivity(host.packageManager) != null) {
            intent
        } else if (fallbackIntent.resolveActivity(host.packageManager) != null) {
            fallbackIntent
        } else {
            callback.onAuthenticationError(AppLockAuthError.TemporarilyUnavailable)
            return
        }
        runCatching {
            host.startActivity(launchIntent)
        }.onFailure {
            callback.onAuthenticationError(AppLockAuthError.TemporarilyUnavailable)
        }
    }

    private fun isDeviceSecure(): Boolean = keyguardManager.isDeviceSecure

    private fun resolveAuthRoute(): AuthRoute {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return when (biometricManager.canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)) {
                BiometricManager.BIOMETRIC_SUCCESS -> AuthRoute.BiometricCombined
                BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> AuthRoute.TemporarilyUnavailable
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED,
                BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> {
                    if (isDeviceSecure()) {
                        AuthRoute.DeviceCredentialOnly
                    } else {
                        AuthRoute.SecuritySetupRequired
                    }
                }
                else -> {
                    if (isDeviceSecure()) {
                        AuthRoute.DeviceCredentialOnly
                    } else {
                        AuthRoute.SecuritySetupRequired
                    }
                }
            }
        }

        val biometricStatus = biometricManager.canAuthenticate(BIOMETRIC_STRONG)
        return when {
            biometricStatus == BiometricManager.BIOMETRIC_SUCCESS ->
                AuthRoute.BiometricWithDeviceCredentialFallback
            isDeviceSecure() -> AuthRoute.DeviceCredentialOnly
            biometricStatus == BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
                AuthRoute.TemporarilyUnavailable
            else -> AuthRoute.SecuritySetupRequired
        }
    }

    private fun biometricPrompt(): BiometricPrompt {
        val existingPrompt = prompt
        if (existingPrompt != null) return existingPrompt

        return BiometricPrompt(
            host,
            ContextCompat.getMainExecutor(host),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON && launchDeviceCredential()) {
                        return
                    }

                    callback.onAuthenticationError(
                        when (errorCode) {
                            BiometricPrompt.ERROR_CANCELED,
                            BiometricPrompt.ERROR_USER_CANCELED,
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON -> AppLockAuthError.Cancelled
                            BiometricPrompt.ERROR_HW_UNAVAILABLE,
                            BiometricPrompt.ERROR_LOCKOUT,
                            BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
                            BiometricPrompt.ERROR_TIMEOUT -> AppLockAuthError.TemporarilyUnavailable
                            BiometricPrompt.ERROR_NO_BIOMETRICS,
                            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> AppLockAuthError.SecuritySetupRequired
                            else -> AppLockAuthError.TemporarilyUnavailable
                        }
                    )
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    val method = when (result.authenticationType) {
                        BiometricPrompt.AUTHENTICATION_RESULT_TYPE_DEVICE_CREDENTIAL ->
                            AppLockAuthMethod.DeviceCredential
                        else -> AppLockAuthMethod.Biometric
                    }
                    callback.onAuthenticationSucceeded(method)
                }

                override fun onAuthenticationFailed() {
                    callback.onAuthenticationFailed()
                }
            },
        ).also { prompt = it }
    }

    private fun launchDeviceCredential(): Boolean {
        if (!isDeviceSecure()) return false

        val intent = keyguardManager.createConfirmDeviceCredentialIntent(
            host.getString(com.wrait.app.R.string.app_lock_title),
            host.getString(com.wrait.app.R.string.app_lock_message),
        ) ?: return false

        credentialLauncher.launch(intent)
        return true
    }

    private fun promptInfoApi30Plus(): BiometricPrompt.PromptInfo {
        return BiometricPrompt.PromptInfo.Builder()
            .setTitle(host.getString(com.wrait.app.R.string.app_lock_title))
            .setSubtitle(host.getString(com.wrait.app.R.string.app_lock_message))
            .setConfirmationRequired(false)
            .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            .build()
    }

    private fun promptInfoApi29(): BiometricPrompt.PromptInfo {
        return BiometricPrompt.PromptInfo.Builder()
            .setTitle(host.getString(com.wrait.app.R.string.app_lock_title))
            .setSubtitle(host.getString(com.wrait.app.R.string.app_lock_message))
            .setConfirmationRequired(false)
            .setDeviceCredentialAllowed(true)
            .build()
    }

    private fun promptInfoPre29(): BiometricPrompt.PromptInfo {
        return BiometricPrompt.PromptInfo.Builder()
            .setTitle(host.getString(com.wrait.app.R.string.app_lock_title))
            .setSubtitle(host.getString(com.wrait.app.R.string.app_lock_message))
            .setConfirmationRequired(false)
            .setNegativeButtonText(host.getString(com.wrait.app.R.string.app_lock_use_device_credential))
            .build()
    }
}
