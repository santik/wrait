package com.wrait.app

import android.app.Activity
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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.res.dimensionResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.ui.theme.WraitTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            WraitTheme {
                val context = LocalContext.current
                val activity = context as? Activity
                val lifecycleOwner = LocalLifecycleOwner.current
                var showBlockedMessage by remember { mutableStateOf(false) }
                var hasRequestedPermission by remember { mutableStateOf(false) }
                val recordingState by viewModel.recordingState.collectAsState()
                val entries by viewModel.entries.collectAsState()

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
                    } else {
                        val permanentlyDenied = hasRequestedPermission && activity != null &&
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
                    }
                }

                MainScreen(
                    modifier = Modifier.fillMaxSize(),
                    recordingState = recordingState,
                    entries = entries,
                    showBlockedMessage = showBlockedMessage,
                    onMainButtonTapped = {
                        if (isPermissionGranted.value) {
                            showBlockedMessage = false
                            viewModel.onMainButtonTapped()
                            return@MainScreen
                        }

                        val permanentlyDenied = hasRequestedPermission && activity != null &&
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
fun MainScreen(
    modifier: Modifier = Modifier,
    recordingState: RecordingState,
    entries: List<EntrySummary>,
    showBlockedMessage: Boolean,
    onMainButtonTapped: () -> Unit
) {
    val buttonSize = dimensionResource(id = R.dimen.main_button_size)
    val buttonLabel = stringResource(id = R.string.main_button_label)
    val buttonDescription = stringResource(id = R.string.main_button_description)
    val listeningStatus = stringResource(id = R.string.listening_status)
    val processingStatus = stringResource(id = R.string.processing_status)
    val savedStatus = stringResource(id = R.string.saved_status)
    val noMatchStatus = stringResource(id = R.string.error_no_match)
    val tooShortStatus = stringResource(id = R.string.error_too_short)
    val networkStatus = stringResource(id = R.string.error_network)
    val notAvailableStatus = stringResource(id = R.string.error_not_available)
    val permissionStatus = stringResource(id = R.string.error_permission)
    val genericErrorStatus = stringResource(id = R.string.error_generic)
    val blockedMessage = stringResource(id = R.string.mic_blocked_message)
    val savedTitle = stringResource(id = R.string.saved_transcripts_title)
    val emptyTitle = stringResource(id = R.string.no_transcripts_yet)

    Box(modifier = modifier) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Button(
                onClick = onMainButtonTapped,
                shape = CircleShape,
                modifier = Modifier
                    .size(buttonSize)
                    .semantics { contentDescription = buttonDescription }
            ) {
                Text(
                    text = buttonLabel,
                    style = MaterialTheme.typography.headlineMedium
                )
            }

            val statusText = when {
                showBlockedMessage -> blockedMessage
                recordingState is RecordingState.Listening -> listeningStatus
                recordingState is RecordingState.Processing -> processingStatus
                recordingState is RecordingState.Saved -> savedStatus
                recordingState is RecordingState.Error -> {
                    when (recordingState.error) {
                        RecognizerError.NoMatch -> noMatchStatus
                        RecognizerError.TooShort -> tooShortStatus
                        RecognizerError.Network -> networkStatus
                        RecognizerError.NotAvailable -> notAvailableStatus
                        RecognizerError.InsufficientPermissions -> permissionStatus
                        else -> genericErrorStatus
                    }
                }
                else -> null
            }

            if (statusText != null) {
                Text(
                    text = statusText,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 16.dp)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = savedTitle,
                style = MaterialTheme.typography.titleMedium
            )

            LazyColumn(
                modifier = Modifier
                    .padding(top = 8.dp)
                    .height(240.dp)
            ) {
                if (entries.isEmpty()) {
                    item {
                        Text(
                            text = emptyTitle,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                } else {
                    items(entries, key = { it.id }) { entry ->
                        Text(
                            text = entry.transcript,
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.padding(vertical = 4.dp)
                        )
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun MainButtonPreview() {
    WraitTheme {
        MainScreen(
            recordingState = RecordingState.Idle,
            entries = emptyList(),
            showBlockedMessage = false,
            onMainButtonTapped = {}
        )
    }
}
