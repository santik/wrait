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
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.dimensionResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.wrait.app.ui.theme.WraitTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            WraitTheme {
                val context = LocalContext.current
                val activity = context as? Activity
                val lifecycleOwner = LocalLifecycleOwner.current
                var isRecording by remember { mutableStateOf(false) }
                var showBlockedMessage by remember { mutableStateOf(false) }
                var hasRequestedPermission by remember { mutableStateOf(false) }

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
                        isRecording = true
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
                        isRecording = false
                    } else {
                        showBlockedMessage = false
                    }
                }

                MainScreen(
                    modifier = Modifier.fillMaxSize(),
                    isRecording = isRecording,
                    showBlockedMessage = showBlockedMessage,
                    onMainButtonTapped = {
                        if (isPermissionGranted.value) {
                            showBlockedMessage = false
                            isRecording = !isRecording
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
    isRecording: Boolean,
    showBlockedMessage: Boolean,
    onMainButtonTapped: () -> Unit
) {
    val buttonSize = dimensionResource(id = R.dimen.main_button_size)
    val buttonLabel = stringResource(id = R.string.main_button_label)
    val buttonDescription = stringResource(id = R.string.main_button_description)
    val recordingStatus = stringResource(id = R.string.recording_status)
    val blockedMessage = stringResource(id = R.string.mic_blocked_message)

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

            if (isRecording) {
                Text(
                    text = recordingStatus,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 16.dp)
                )
            } else if (showBlockedMessage) {
                Text(
                    text = blockedMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 16.dp)
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun MainButtonPreview() {
    WraitTheme {
        MainScreen(
            isRecording = false,
            showBlockedMessage = false,
            onMainButtonTapped = {}
        )
    }
}
