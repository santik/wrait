package com.wrait.app.lock

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

internal const val APP_LOCK_PROMPT_TIMEOUT_MS = 30_000L

class AppLockViewModel : ViewModel() {
    private val coordinator = AppLockCoordinator()
    private var promptTimeoutJob: Job? = null

    private val _uiState = MutableStateFlow(coordinator.state)
    val uiState: StateFlow<AppLockUiState> = _uiState.asStateFlow()

    fun onProcessStart(availability: AppLockAvailability) {
        updateState(coordinator.onProcessStart(availability))
    }

    fun onProcessStop() {
        updateState(coordinator.onProcessStop())
    }

    fun onUnlockRequested() {
        updateState(coordinator.onUnlockRequested())
    }

    fun onPromptShown() {
        updateState(coordinator.onPromptShown())
    }

    fun onUnlockSucceeded() {
        updateState(coordinator.onUnlockSucceeded())
    }

    fun onUnlockCancelled() {
        updateState(coordinator.onUnlockCancelled())
    }

    fun onSecuritySetupRequired() {
        updateState(coordinator.onSecuritySetupRequired())
    }

    fun onAuthenticationTemporarilyUnavailable() {
        updateState(coordinator.onAuthenticationTemporarilyUnavailable())
    }

    private fun updateState(newState: AppLockUiState) {
        _uiState.value = newState
        promptTimeoutJob?.cancel()
        if (newState.status != AppLockStatus.Prompting) return

        promptTimeoutJob = viewModelScope.launch {
            delay(APP_LOCK_PROMPT_TIMEOUT_MS)
            _uiState.value = coordinator.onPromptTimeout()
        }
    }

    override fun onCleared() {
        promptTimeoutJob?.cancel()
        super.onCleared()
    }
}
