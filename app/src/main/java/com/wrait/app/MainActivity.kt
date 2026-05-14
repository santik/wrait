package com.wrait.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.ui.draw.blur
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.fragment.app.FragmentActivity
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.displayNameForLanguage
import com.wrait.app.lock.AppLockAuthCallback
import com.wrait.app.lock.AppLockAuthError
import com.wrait.app.lock.AppLockAuthenticator
import com.wrait.app.lock.AppLockAuthenticatorFactory
import com.wrait.app.lock.AppLockViewModel
import com.wrait.app.ui.entries.EntryDetailScreen
import com.wrait.app.ui.entries.EntryDetailViewModel
import com.wrait.app.ui.entries.EntryListScreen
import com.wrait.app.ui.entries.EntryListViewModel
import com.wrait.app.ui.lock.AppLockScreen
import com.wrait.app.ui.main.LanguageSettingsSheet
import com.wrait.app.ui.main.MainScreen
import com.wrait.app.ui.theme.WrAItTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : FragmentActivity() {
    private val viewModel: MainViewModel by viewModels()
    private val appLockViewModel: AppLockViewModel by viewModels()

    @Inject
    lateinit var appLockAuthenticatorFactory: AppLockAuthenticatorFactory

    private var appLockAuthenticator: AppLockAuthenticator? = null

    private val processLifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) {
            appLockAuthenticator?.availability()?.let(appLockViewModel::onProcessStart)
        }

        override fun onStop(owner: LifecycleOwner) {
            appLockViewModel.onProcessStop()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appLockAuthenticator = appLockAuthenticatorFactory.create(
            host = this,
            callback = object : AppLockAuthCallback {
                override fun onAuthenticationSucceeded(method: com.wrait.app.lock.AppLockAuthMethod) {
                    appLockViewModel.onUnlockSucceeded()
                }

                override fun onAuthenticationFailed() = Unit

                override fun onAuthenticationError(error: AppLockAuthError) {
                    when (error) {
                        AppLockAuthError.Cancelled -> appLockViewModel.onUnlockCancelled()
                        AppLockAuthError.SecuritySetupRequired -> appLockViewModel.onSecuritySetupRequired()
                        AppLockAuthError.TemporarilyUnavailable ->
                            appLockViewModel.onAuthenticationTemporarilyUnavailable()
                    }
                }
            },
        )
        ProcessLifecycleOwner.get().lifecycle.addObserver(processLifecycleObserver)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        enableEdgeToEdge()
        setContent {
            WrAItTheme {
                val context = LocalContext.current
                val activity = this@MainActivity
                val lifecycleOwner = LocalLifecycleOwner.current
                var showBlockedMessage by remember { mutableStateOf(false) }
                var hasRequestedPermission by remember { mutableStateOf(false) }
                val recordingState by viewModel.recordingState.collectAsState()
                val shakeErrorKey by viewModel.shakeErrorKey.collectAsStateWithLifecycle()
                val stats by viewModel.entryStats.collectAsStateWithLifecycle()
                val selectedLanguage by viewModel.selectedLanguage.collectAsStateWithLifecycle()
                val hasEverRecorded by viewModel.hasEverRecorded.collectAsStateWithLifecycle()
                val showSettingsPanel by viewModel.showSettingsPanel.collectAsStateWithLifecycle()
                val privacyMode by viewModel.privacyMode.collectAsStateWithLifecycle()
                val appLockUiState by appLockViewModel.uiState.collectAsStateWithLifecycle()
                val lifecycleState by lifecycleOwner.lifecycle.currentStateFlow.collectAsState()
                val languageSummary = remember(selectedLanguage) {
                    displayNameForLanguage(selectedLanguage)
                }
                val canLaunchAuthPrompt = lifecycleState == Lifecycle.State.RESUMED

                LaunchedEffect(appLockUiState.promptRequestNonce, appLockUiState.isPromptPending, canLaunchAuthPrompt) {
                    if (appLockUiState.isPromptPending && canLaunchAuthPrompt) {
                        runCatching {
                            appLockViewModel.onPromptShown()
                            appLockAuthenticator?.authenticate()
                                ?: appLockViewModel.onAuthenticationTemporarilyUnavailable()
                        }.onFailure {
                            appLockViewModel.onAuthenticationTemporarilyUnavailable()
                        }
                    }
                }

                LaunchedEffect(recordingState.isActive) {
                    val keepScreenOnFlagSet = activity.window.attributes.flags and
                        android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0
                    when (keepScreenOnCommand(recordingState.isActive, keepScreenOnFlagSet)) {
                        KeepScreenOnCommand.AddFlag -> {
                            activity.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        KeepScreenOnCommand.ClearFlag -> {
                            activity.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        KeepScreenOnCommand.None -> Unit
                    }
                }

                val isPermissionGranted = remember {
                    mutableStateOf(
                        ContextCompat.checkSelfPermission(
                            context,
                            android.Manifest.permission.RECORD_AUDIO,
                        ) == PackageManager.PERMISSION_GRANTED,
                    )
                }

                val requestPermissionLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestPermission(),
                ) { granted ->
                    isPermissionGranted.value = granted
                    if (granted) {
                        showBlockedMessage = false
                        hasRequestedPermission = false
                    } else {
                        val permanentlyDenied = isMicrophonePermissionPermanentlyDenied(
                            hasRequestedPermission = hasRequestedPermission,
                            shouldShowRationale = ActivityCompat.shouldShowRequestPermissionRationale(
                                activity,
                                android.Manifest.permission.RECORD_AUDIO,
                            ),
                        )
                        viewModel.onMicrophonePermissionResult(
                            granted = false,
                            permanentlyDenied = permanentlyDenied,
                        )
                        if (permanentlyDenied) {
                            showBlockedMessage = true
                        }
                    }
                }

                LaunchedEffect(canLaunchAuthPrompt, context) {
                    if (canLaunchAuthPrompt) {
                        isPermissionGranted.value = ContextCompat.checkSelfPermission(
                            context,
                            android.Manifest.permission.RECORD_AUDIO,
                        ) == PackageManager.PERMISSION_GRANTED
                    }
                }

                DisposableEffect(Unit) {
                    onDispose {
                        activity.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                }

                LaunchedEffect(isPermissionGranted.value) {
                    if (!isPermissionGranted.value) {
                        viewModel.onPermissionRevoked()
                    } else {
                        showBlockedMessage = false
                        hasRequestedPermission = false
                    }
                }

                LaunchedEffect(context) {
                    viewModel.userMessage.collect { message ->
                        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                    }
                }

                val onStatusLineTap: () -> Unit = {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", context.packageName, null),
                    )
                    context.startActivity(intent)
                }

                val navController = rememberNavController()

                AppNavHost(
                    navController = navController,
                    recordingState = recordingState,
                    showBlockedMessage = showBlockedMessage,
                    shakeErrorKey = shakeErrorKey,
                    stats = stats,
                    selectedLanguage = selectedLanguage,
                    languageSummary = languageSummary,
                    hasEverRecorded = hasEverRecorded,
                    showSettingsPanel = showSettingsPanel,
                    privacyMode = privacyMode,
                    onOpenSettings = viewModel::onOpenSettings,
                    onPrivacyModeToggle = viewModel::onPrivacyModeToggle,
                    onSettingsPanelDismiss = viewModel::onSettingsPanelDismiss,
                    onStatusCleared = { viewModel.resetToIdle() },
                    onStatusLineTap = onStatusLineTap,
                    onTapToRead = { id ->
                        viewModel.resetToIdle()
                        navController.navigate("entry/$id") { launchSingleTop = true }
                    },
                    onLanguageSelected = viewModel::setLanguage,
                    onMainButtonTapped = {
                        if (recordingState is RecordingState.Error &&
                            (recordingState as RecordingState.Error).error == RecognizerError.InsufficientPermissions
                        ) {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", context.packageName, null),
                            )
                            context.startActivity(intent)
                            return@AppNavHost
                        }

                        if (isPermissionGranted.value) {
                            showBlockedMessage = false
                            viewModel.onMainButtonTapped()
                            return@AppNavHost
                        }

                        val permanentlyDenied = isMicrophonePermissionPermanentlyDenied(
                            hasRequestedPermission = hasRequestedPermission,
                            shouldShowRationale = ActivityCompat.shouldShowRequestPermissionRationale(
                                activity,
                                android.Manifest.permission.RECORD_AUDIO,
                            ),
                        )

                        if (permanentlyDenied) {
                            showBlockedMessage = true
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", context.packageName, null),
                            )
                            context.startActivity(intent)
                        } else {
                            hasRequestedPermission = true
                            viewModel.onMicrophonePermissionRequested()
                            requestPermissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                        }
                    },
                    modifier = Modifier
                        .fillMaxSize()
                        .blur(if (appLockUiState.shouldBlockContent) 20.dp else 0.dp),
                )

                if (appLockUiState.shouldBlockContent) {
                    Box(modifier = Modifier.fillMaxSize()) {
                        AppLockScreen(
                            uiState = appLockUiState,
                            onUnlock = {
                                appLockViewModel.onUnlockRequested()
                            },
                            onOpenSecuritySettings = {
                                appLockAuthenticator?.openSecuritySettings()
                                    ?: appLockViewModel.onAuthenticationTemporarilyUnavailable()
                            },
                        )
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        ProcessLifecycleOwner.get().lifecycle.removeObserver(processLifecycleObserver)
        if (isFinishing) {
            appLockAuthenticator?.cancel()
        }
        appLockAuthenticator = null
        super.onDestroy()
    }
}

internal enum class KeepScreenOnCommand {
    AddFlag,
    ClearFlag,
    None,
}

internal fun keepScreenOnCommand(
    isRecordingActive: Boolean,
    keepScreenOnFlagSet: Boolean,
): KeepScreenOnCommand {
    return when {
        isRecordingActive && !keepScreenOnFlagSet -> KeepScreenOnCommand.AddFlag
        !isRecordingActive && keepScreenOnFlagSet -> KeepScreenOnCommand.ClearFlag
        else -> KeepScreenOnCommand.None
    }
}

internal fun isMicrophonePermissionPermanentlyDenied(
    hasRequestedPermission: Boolean,
    shouldShowRationale: Boolean,
): Boolean = hasRequestedPermission && !shouldShowRationale

@Composable
private fun AppNavHost(
    navController: NavHostController,
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    stats: com.wrait.app.domain.model.EntryStats,
    selectedLanguage: String,
    languageSummary: String,
    hasEverRecorded: Boolean,
    showSettingsPanel: Boolean,
    privacyMode: PrivacyMode,
    onOpenSettings: () -> Unit,
    onPrivacyModeToggle: (Boolean) -> Unit,
    onSettingsPanelDismiss: () -> Unit,
    onStatusCleared: () -> Unit,
    onStatusLineTap: () -> Unit,
    onTapToRead: (Long) -> Unit,
    onMainButtonTapped: () -> Unit,
    onLanguageSelected: (String) -> Unit,
    modifier: Modifier = Modifier,
    onStatsLineTap: () -> Unit = {
        navController.navigate("entries") { launchSingleTop = true }
    },
) {
    NavHost(
        navController = navController,
        startDestination = "main",
        modifier = modifier.fillMaxSize(),
    ) {
        composable("main") {
            var languageSettingsRequested by remember { mutableStateOf(false) }
            val showLanguageSettings = languageSettingsRequested &&
                privacyMode == PrivacyMode.MODE_OFFLINE

            LaunchedEffect(privacyMode) {
                if (privacyMode != PrivacyMode.MODE_OFFLINE && languageSettingsRequested) {
                    languageSettingsRequested = false
                }
            }

            MainScreen(
                recordingState = recordingState,
                showBlockedMessage = showBlockedMessage,
                shakeErrorKey = shakeErrorKey,
                stats = stats,
                languageSummary = languageSummary,
                hasEverRecorded = hasEverRecorded,
                showSettingsPanel = showSettingsPanel,
                privacyMode = privacyMode,
                onButtonTap = onMainButtonTapped,
                onLanguagesTap = {
                    if (privacyMode == PrivacyMode.MODE_OFFLINE) {
                        languageSettingsRequested = true
                    }
                },
                onSwipeUp = onStatsLineTap,
                onOpenSettings = onOpenSettings,
                onPrivacyModeToggle = onPrivacyModeToggle,
                onSettingsPanelDismiss = onSettingsPanelDismiss,
                onStatusCleared = onStatusCleared,
                onTapToRead = onTapToRead,
                onStatusLineTap = onStatusLineTap,
                onStatsLineTap = onStatsLineTap,
                modifier = Modifier.fillMaxSize(),
            )

            if (showLanguageSettings) {
                LanguageSettingsSheet(
                    selectedLanguage = selectedLanguage,
                    onLanguageSelected = { code ->
                        onLanguageSelected(code)
                        languageSettingsRequested = false
                    },
                    onDismiss = { languageSettingsRequested = false },
                )
            }
        }
        composable("entries") {
            val entryListViewModel: EntryListViewModel = hiltViewModel()
            val entryListUiState by entryListViewModel.uiState.collectAsStateWithLifecycle()
            LaunchedEffect(Unit) {
                entryListViewModel.onEntriesListOpened(entryListUiState.entries.size)
            }
            EntryListScreen(
                uiState = entryListUiState,
                onEntryClick = { id -> navController.navigate("entry/$id") },
                onBack = { navController.popBackStack() },
                onDeleteInitiated = entryListViewModel::onDeleteInitiated,
                onDeleteEntry = entryListViewModel::deleteEntry,
            )
        }
        composable(
            route = "entry/{entryId}",
            arguments = listOf(navArgument("entryId") { type = NavType.LongType }),
        ) {
            val detailViewModel: EntryDetailViewModel = hiltViewModel()
            val entry by detailViewModel.entry.collectAsStateWithLifecycle()
            val showDeleteDialog by detailViewModel.showDeleteDialog.collectAsStateWithLifecycle()
            val editedText by detailViewModel.editedText.collectAsStateWithLifecycle()
            EntryDetailScreen(
                entryResult = entry,
                showDeleteDialog = showDeleteDialog,
                editedText = editedText,
                onTextChanged = detailViewModel::onTextChanged,
                showDevDraft = BuildConfig.DEV,
                onBack = { detailViewModel.flushEdit(); navController.popBackStack() },
                onShareSucceeded = detailViewModel::onShareSucceeded,
                onDeleteTapped = detailViewModel::onDeleteTapped,
                onDeleteCancelled = detailViewModel::onDeleteCancelled,
                onDeleteConfirmed = {
                    detailViewModel.confirmDelete {
                        navController.navigate("entries") {
                            popUpTo("entries") { inclusive = true }
                        }
                    }
                },
            )
        }
    }
}
