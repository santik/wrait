package com.wrait.app.lock

enum class AppLockAvailability {
    Ready,
    SecuritySetupRequired,
    TemporarilyUnavailable,
}

enum class AppLockMessage {
    TemporarilyUnavailable,
}

enum class AppLockStatus {
    Locked,
    Prompting,
    Unlocked,
    SetupRequired,
}

data class AppLockUiState(
    val status: AppLockStatus = AppLockStatus.Locked,
    val promptRequestNonce: Long = 0L,
    val isPromptPending: Boolean = false,
    val message: AppLockMessage? = null,
) {
    val shouldBlockContent: Boolean
        get() = status != AppLockStatus.Unlocked
}

class AppLockCoordinator {
    private var hasStarted = false
    private var wasBackgrounded = false

    var state: AppLockUiState = AppLockUiState()
        private set

    fun onProcessStart(availability: AppLockAvailability): AppLockUiState {
        return when {
            !hasStarted -> {
                hasStarted = true
                wasBackgrounded = false
                lockForForeground(availability)
            }
            wasBackgrounded -> {
                wasBackgrounded = false
                lockForForeground(availability)
            }
            else -> state
        }
    }

    fun onProcessStop(): AppLockUiState {
        wasBackgrounded = true
        state = when (state.status) {
            AppLockStatus.SetupRequired -> state
            else -> state.copy(
                status = AppLockStatus.Locked,
                isPromptPending = false,
            )
        }
        return state
    }

    fun onUnlockRequested(): AppLockUiState {
        state = requestPrompt()
        return state
    }

    fun onPromptShown(): AppLockUiState {
        if (!state.isPromptPending) return state

        state = state.copy(
            status = AppLockStatus.Prompting,
            isPromptPending = false,
        )
        return state
    }

    fun onUnlockSucceeded(): AppLockUiState {
        state = AppLockUiState(status = AppLockStatus.Unlocked)
        return state
    }

    fun onUnlockCancelled(): AppLockUiState {
        state = AppLockUiState(status = AppLockStatus.Locked)
        return state
    }

    fun onSecuritySetupRequired(): AppLockUiState {
        state = AppLockUiState(status = AppLockStatus.SetupRequired)
        return state
    }

    fun onAuthenticationTemporarilyUnavailable(): AppLockUiState {
        state = AppLockUiState(
            status = AppLockStatus.Locked,
            message = AppLockMessage.TemporarilyUnavailable,
        )
        return state
    }

    fun onPromptTimeout(): AppLockUiState {
        if (state.status != AppLockStatus.Prompting) return state

        return onAuthenticationTemporarilyUnavailable()
    }

    private fun lockForForeground(availability: AppLockAvailability): AppLockUiState {
        state = when (availability) {
            AppLockAvailability.Ready -> requestPrompt()
            AppLockAvailability.SecuritySetupRequired -> AppLockUiState(
                status = AppLockStatus.SetupRequired,
            )
            AppLockAvailability.TemporarilyUnavailable -> AppLockUiState(
                status = AppLockStatus.Locked,
                message = AppLockMessage.TemporarilyUnavailable,
            )
        }
        return state
    }

    private fun requestPrompt(): AppLockUiState {
        return AppLockUiState(
            status = AppLockStatus.Locked,
            promptRequestNonce = state.promptRequestNonce + 1L,
            isPromptPending = true,
        )
    }
}
