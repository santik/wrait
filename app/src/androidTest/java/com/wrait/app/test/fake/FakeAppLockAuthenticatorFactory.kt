package com.wrait.app.test.fake

import androidx.fragment.app.FragmentActivity
import com.wrait.app.lock.AppLockAuthCallback
import com.wrait.app.lock.AppLockAuthError
import com.wrait.app.lock.AppLockAuthMethod
import com.wrait.app.lock.AppLockAuthenticator
import com.wrait.app.lock.AppLockAuthenticatorFactory
import com.wrait.app.lock.AppLockAvailability
import java.util.concurrent.atomic.AtomicReference
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FakeAppLockAuthenticatorFactory @Inject constructor() : AppLockAuthenticatorFactory {
    data class Behavior(
        val availability: AppLockAvailability = AppLockAvailability.Ready,
        val autoAuthenticate: Boolean = true,
    )

    companion object {
        private val defaultBehaviorRef = AtomicReference(Behavior())

        fun setDefaultBehavior(behavior: Behavior) {
            defaultBehaviorRef.set(behavior)
        }

        fun resetDefaultBehavior() {
            defaultBehaviorRef.set(Behavior())
        }

        private fun defaultBehavior(): Behavior = defaultBehaviorRef.get()
    }

    private val latestAuthenticator = AtomicReference<FakeAppLockAuthenticator?>(null)

    override fun create(
        host: FragmentActivity,
        callback: AppLockAuthCallback,
    ): AppLockAuthenticator {
        return FakeAppLockAuthenticator(
            callback = callback,
            initialBehavior = defaultBehavior(),
        ).also { latestAuthenticator.set(it) }
    }

    fun reset() {
        latestAuthenticator.set(null)
        resetDefaultBehavior()
    }

    fun succeedUnlock() {
        latestAuthenticator.get()?.succeedUnlock()
    }
}

private class FakeAppLockAuthenticator(
    private val callback: AppLockAuthCallback,
    initialBehavior: FakeAppLockAuthenticatorFactory.Behavior,
) : AppLockAuthenticator {
    private var behavior = initialBehavior

    override fun availability(): AppLockAvailability = behavior.availability

    override fun authenticate() {
        when (behavior.availability) {
            AppLockAvailability.Ready -> {
                if (behavior.autoAuthenticate) {
                    callback.onAuthenticationSucceeded(AppLockAuthMethod.Biometric)
                }
            }
            AppLockAvailability.SecuritySetupRequired ->
                callback.onAuthenticationError(AppLockAuthError.SecuritySetupRequired)
            AppLockAvailability.TemporarilyUnavailable ->
                callback.onAuthenticationError(AppLockAuthError.TemporarilyUnavailable)
        }
    }

    override fun cancel() = Unit

    override fun openSecuritySettings() = Unit

    fun succeedUnlock() {
        callback.onAuthenticationSucceeded(AppLockAuthMethod.Biometric)
    }
}
