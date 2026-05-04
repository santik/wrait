package com.wrait.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.LanguagePreferences
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.ui.entries.EntryDetailScreen
import com.wrait.app.ui.entries.EntryDetailViewModel
import com.wrait.app.ui.entries.EntryListScreen
import com.wrait.app.ui.entries.EntryListViewModel
import com.wrait.app.ui.main.LanguageSettingsSheet
import com.wrait.app.ui.main.MainScreen
import com.wrait.app.ui.theme.WrAItTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
                val languagePreferences by viewModel.languagePreferences.collectAsStateWithLifecycle()
                val shouldPromptForLanguages by viewModel.shouldPromptForLanguages.collectAsStateWithLifecycle()
                val hasEverRecorded by viewModel.hasEverRecorded.collectAsStateWithLifecycle()
                val showSettingsPanel by viewModel.showSettingsPanel.collectAsStateWithLifecycle()
                val privacyMode by viewModel.privacyMode.collectAsStateWithLifecycle()
                val languageSummary = remember(languagePreferences) {
                    languageSummaryFor(languagePreferences)
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
                            android.Manifest.permission.RECORD_AUDIO
                        ) == PackageManager.PERMISSION_GRANTED
                    )
                }

                val requestPermissionLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestPermission()
                ) { granted ->
                    isPermissionGranted.value = granted
                    if (granted) {
                        showBlockedMessage = false
                        hasRequestedPermission = false
                    } else {
                        val permanentlyDenied = hasRequestedPermission &&
                            !ActivityCompat.shouldShowRequestPermissionRationale(
                                activity,
                                android.Manifest.permission.RECORD_AUDIO
                            )
                        if (permanentlyDenied) {
                            showBlockedMessage = true
                        }
                    }
                }

                LaunchedEffect(Unit) {
                    isPermissionGranted.value = ContextCompat.checkSelfPermission(
                        context,
                        android.Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                }

                DisposableEffect(lifecycleOwner, context) {
                    val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
                        if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
                            isPermissionGranted.value = ContextCompat.checkSelfPermission(
                                context,
                                android.Manifest.permission.RECORD_AUDIO
                            ) == PackageManager.PERMISSION_GRANTED
                        }
                    }
                    lifecycleOwner.lifecycle.addObserver(observer)
                    onDispose {
                        lifecycleOwner.lifecycle.removeObserver(observer)
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
                        Uri.fromParts("package", context.packageName, null)
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
                    languagePreferences = languagePreferences,
                    languageSummary = languageSummary,
                    shouldPromptForLanguages = shouldPromptForLanguages,
                    hasEverRecorded = hasEverRecorded,
                    showSettingsPanel = showSettingsPanel,
                    privacyMode = privacyMode,
                    onSwipeDown = viewModel::onSwipeDown,
                    onPrivacyModeToggle = viewModel::onPrivacyModeToggle,
                    onSettingsPanelDismiss = viewModel::onSettingsPanelDismiss,
                    onStatusCleared = { viewModel.resetToIdle() },
                    onStatusLineTap = onStatusLineTap,
                    onTapToRead = { id ->
                        viewModel.resetToIdle()
                        navController.navigate("entry/$id") { launchSingleTop = true }
                    },
                    onToggleLanguage = viewModel::toggleLanguage,
                    onSetPrimaryLanguage = viewModel::setPrimaryLanguage,
                    onConfirmLanguagePreferences = viewModel::confirmLanguagePreferences,
                    onMainButtonTapped = {
                        if (recordingState is RecordingState.Error &&
                            (recordingState as RecordingState.Error).error == RecognizerError.InsufficientPermissions
                        ) {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", context.packageName, null)
                            )
                            context.startActivity(intent)
                            return@AppNavHost
                        }

                        if (isPermissionGranted.value) {
                            showBlockedMessage = false
                            viewModel.onMainButtonTapped()
                            return@AppNavHost
                        }

                        val permanentlyDenied = hasRequestedPermission &&
                            !ActivityCompat.shouldShowRequestPermissionRationale(
                                activity,
                                android.Manifest.permission.RECORD_AUDIO
                            )

                        if (permanentlyDenied) {
                            showBlockedMessage = true
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", context.packageName, null)
                            )
                            context.startActivity(intent)
                        } else {
                            hasRequestedPermission = true
                            requestPermissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                        }
                    }
                )
            }
        }
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

@Composable
private fun AppNavHost(
    navController: NavHostController,
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    stats: com.wrait.app.domain.model.EntryStats,
    languagePreferences: LanguagePreferences,
    languageSummary: String,
    shouldPromptForLanguages: Boolean,
    hasEverRecorded: Boolean,
    showSettingsPanel: Boolean,
    privacyMode: PrivacyMode,
    onSwipeDown: () -> Unit,
    onPrivacyModeToggle: (Boolean) -> Unit,
    onSettingsPanelDismiss: () -> Unit,
    onStatusCleared: () -> Unit,
    onStatusLineTap: () -> Unit,
    onTapToRead: (Long) -> Unit,
    onMainButtonTapped: () -> Unit,
    onToggleLanguage: (String) -> Unit,
    onSetPrimaryLanguage: (String) -> Unit,
    onConfirmLanguagePreferences: suspend () -> Boolean,
    modifier: Modifier = Modifier,
    onStatsLineTap: () -> Unit = {
        navController.navigate("entries") { launchSingleTop = true }
    }
) {
    NavHost(
        navController = navController,
        startDestination = "main",
        modifier = modifier.fillMaxSize()
    ) {
        composable("main") {
            var showLanguageSettings by remember { mutableStateOf(false) }
            val uiScope = rememberCoroutineScope()

            MainScreen(
                recordingState = recordingState,
                showBlockedMessage = showBlockedMessage,
                shakeErrorKey = shakeErrorKey,
                stats = stats,
                languageSummary = languageSummary,
                shouldPromptForLanguages = shouldPromptForLanguages,
                hasEverRecorded = hasEverRecorded,
                showSettingsPanel = showSettingsPanel,
                privacyMode = privacyMode,
                onButtonTap = onMainButtonTapped,
                onLanguagesTap = { showLanguageSettings = true },
                onLanguagePromptTap = { showLanguageSettings = true },
                onSwipeUp = onStatsLineTap,
                onSwipeDown = onSwipeDown,
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
                    languagePreferences = languagePreferences,
                    requireConfirmation = shouldPromptForLanguages,
                    onLanguageToggled = onToggleLanguage,
                    onPrimaryLanguageSelected = onSetPrimaryLanguage,
                    onConfirm = {
                        uiScope.launch {
                            if (onConfirmLanguagePreferences()) {
                                showLanguageSettings = false
                            }
                        }
                    },
                    onDismiss = {
                        if (!shouldPromptForLanguages) {
                            showLanguageSettings = false
                        }
                    },
                )
            }
        }
        composable("entries") {
            val entryListViewModel: EntryListViewModel = hiltViewModel()
            val entryListUiState by entryListViewModel.uiState.collectAsStateWithLifecycle()
            EntryListScreen(
                uiState       = entryListUiState,
                onEntryClick  = { id -> navController.navigate("entry/$id") },
                onBack        = { navController.popBackStack() },
                onDeleteEntry = entryListViewModel::deleteEntry
            )
        }
        composable(
            route     = "entry/{entryId}",
            arguments = listOf(navArgument("entryId") { type = NavType.LongType })
        ) {
            val detailViewModel: EntryDetailViewModel = hiltViewModel()
            val entry            by detailViewModel.entry.collectAsStateWithLifecycle()
            val showDeleteDialog by detailViewModel.showDeleteDialog.collectAsStateWithLifecycle()
            val editedText       by detailViewModel.editedText.collectAsStateWithLifecycle()
            EntryDetailScreen(
                entryResult       = entry,
                showDeleteDialog  = showDeleteDialog,
                editedText        = editedText,
                onTextChanged     = detailViewModel::onTextChanged,
                showDevDraft      = BuildConfig.DEV,
                onBack            = { detailViewModel.flushEdit(); navController.popBackStack() },
                onDeleteTapped    = detailViewModel::onDeleteTapped,
                onDeleteCancelled = detailViewModel::onDeleteCancelled,
                onDeleteConfirmed = {
                    detailViewModel.confirmDelete {
                        navController.navigate("entries") {
                            popUpTo("entries") { inclusive = true }
                        }
                    }
                }
            )
        }
    }
}
