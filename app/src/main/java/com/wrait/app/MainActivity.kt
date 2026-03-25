package com.wrait.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.res.dimensionResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import com.wrait.app.ui.theme.WraitTheme
import dagger.hilt.android.AndroidEntryPoint
import androidx.compose.foundation.shape.CircleShape

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            WraitTheme {
                val snackbarHostState = remember { SnackbarHostState() }
                val tappedMessage = stringResource(id = R.string.button_tapped_message)
                LaunchedEffect(viewModel) {
                    viewModel.uiEvent.collect { event ->
                        when (event) {
                            MainUiEvent.ShowButtonTappedMessage -> {
                                snackbarHostState.showSnackbar(
                                    message = tappedMessage
                                )
                            }
                        }
                    }
                }

                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    snackbarHost = { SnackbarHost(snackbarHostState) }
                ) { innerPadding ->
                    MainButton(
                        modifier = Modifier.padding(innerPadding),
                        onTapped = {
                            viewModel.onMainButtonClicked()
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun MainButton(
    modifier: Modifier = Modifier,
    onTapped: () -> Unit
) {
    val buttonSize = dimensionResource(id = R.dimen.main_button_size)
    val buttonLabel = stringResource(id = R.string.main_button_label)
    val buttonDescription = stringResource(id = R.string.main_button_description)

    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Button(
            onClick = onTapped,
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
    }
}

@Preview(showBackground = true)
@Composable
fun MainButtonPreview() {
    WraitTheme {
        MainButton(onTapped = {})
    }
}
