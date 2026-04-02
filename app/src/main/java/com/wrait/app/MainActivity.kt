package com.wrait.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
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
import com.wrait.app.ui.entries.EntryDetailScreen
import com.wrait.app.ui.entries.EntryDetailViewModel
import com.wrait.app.ui.entries.EntryListScreen
import com.wrait.app.ui.entries.EntryListViewModel
import com.wrait.app.ui.main.LanguagePickerSheet
import com.wrait.app.ui.main.MainScreen
import com.wrait.app.ui.theme.WrAItTheme
import dagger.hilt.android.AndroidEntryPoint

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
                val selectedLanguage by viewModel.selectedLanguage.collectAsStateWithLifecycle()

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

                LaunchedEffect(isPermissionGranted.value) {
                    if (!isPermissionGranted.value) {
                        viewModel.onPermissionRevoked()
                    } else {
                        showBlockedMessage = false
                        hasRequestedPermission = false
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
                    selectedLanguage = selectedLanguage,
                    onEntriesDeleted = { count -> viewModel.onEntriesDeleted(count) },
                    onStatusCleared = { viewModel.onMainButtonTapped() },
                    onStatusLineTap = onStatusLineTap,
                    onTapToRead = { id ->
                        navController.navigate("entry/$id") { launchSingleTop = true }
                    },
                    onSaveLanguage = { code -> viewModel.saveLanguage(code) },
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

@Composable
private fun AppNavHost(
    navController: NavHostController,
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    stats: com.wrait.app.domain.model.EntryStats,
    selectedLanguage: String,
    onEntriesDeleted: (Int) -> Unit,
    onStatusCleared: () -> Unit,
    onStatusLineTap: () -> Unit,
    onTapToRead: (Long) -> Unit,
    onStatsLineTap: () -> Unit = {
        navController.navigate("entries") { launchSingleTop = true }
    },
    onMainButtonTapped: () -> Unit,
    onSaveLanguage: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    NavHost(
        navController = navController,
        startDestination = "main",
        modifier = modifier.fillMaxSize()
    ) {
        composable("main") {
            var showLanguagePicker by remember { mutableStateOf(false) }

            MainScreen(
                recordingState = recordingState,
                showBlockedMessage = showBlockedMessage,
                shakeErrorKey = shakeErrorKey,
                stats = stats,
                selectedLanguage = selectedLanguage,
                onButtonTap = onMainButtonTapped,
                onLanguageTap = { showLanguagePicker = true },
                onSwipeUp = onStatsLineTap,
                onStatusCleared = onStatusCleared,
                onTapToRead = onTapToRead,
                onStatusLineTap = onStatusLineTap,
                onStatsLineTap = onStatsLineTap,
                modifier = Modifier.fillMaxSize(),
            )

            if (showLanguagePicker) {
                LanguagePickerSheet(
                    selectedLanguage   = selectedLanguage,
                    onLanguageSelected = { code -> onSaveLanguage(code) },
                    onDismiss          = { showLanguagePicker = false },
                )
            }
        }
        composable("entries") {
            val entryListViewModel: EntryListViewModel = hiltViewModel()
            val entryListUiState by entryListViewModel.uiState.collectAsStateWithLifecycle()
            EntryListScreen(
                uiState           = entryListUiState,
                onEntryClick      = { id -> navController.navigate("entry/$id") },
                onBack            = {
                    val deleted = entryListUiState.lastDeletedCount
                    if (deleted > 0) {
                        onEntriesDeleted(deleted)
                        entryListViewModel.clearDeletedCount()
                    }
                    navController.popBackStack()
                },
                onLongPress       = entryListViewModel::enterSelectionMode,
                onToggleSelection = entryListViewModel::toggleSelection,
                onSelectAll       = {
                    entryListViewModel.selectAll(entryListUiState.entries.map { it.id })
                },
                onDeselectAll     = entryListViewModel::deselectAll,
                onExitSelection   = entryListViewModel::exitSelectionMode,
                onDeleteTapped    = entryListViewModel::onDeleteButtonTapped,
                onDeleteCancelled = entryListViewModel::onDeleteCancelled,
                onDeleteConfirmed = entryListViewModel::confirmDelete
            )
        }
        composable(
            route = "entry/{entryId}",
            arguments = listOf(navArgument("entryId") { type = NavType.LongType })
        ) {
            val detailViewModel: EntryDetailViewModel = hiltViewModel()
            val entry by detailViewModel.entry.collectAsStateWithLifecycle()
            EntryDetailScreen(
                entryResult = entry,
                onBack      = { navController.popBackStack() }
            )
        }
    }
}
