package com.savia.mobile.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.savia.mobile.R

/**
 * AlertDialog for configuring Bridge connection settings.
 *
 * Manages user input for Host, Port, and Token with real-time validation.
 * Shows loading state during health check and displays errors if connection fails.
 * Supports password visibility toggle for the token field.
 *
 * Features:
 * - Input validation: Host (non-empty), Port (1-65535), Token (non-empty)
 * - Health check via OkHttp to verify Bridge connectivity
 * - Retry mechanism on failure
 * - Modal dialog prevents dismissal during connection
 *
 * @param onDismiss callback when dialog is closed
 * @param onConnected callback when connection succeeds
 * @param viewModel SettingsViewModel providing state and actions
 */
@Composable
fun BridgeSetupDialog(
    onDismiss: () -> Unit,
    onConnected: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    var hostInput by remember { mutableStateOf("") }
    var portInput by remember { mutableStateOf("8922") }
    var tokenInput by remember { mutableStateOf("") }
    var showTokenPassword by remember { mutableStateOf(false) }

    // Track connection state locally
    val isConnecting = uiState.isConnecting
    val connectionError = uiState.connectionError

    // Auto-dismiss on successful connection
    LaunchedEffect(uiState.isBridgeConnected) {
        if (uiState.isBridgeConnected && !isConnecting && connectionError == null) {
            onConnected()
            onDismiss()
        }
    }

    val isHostValid = hostInput.isNotBlank()
    val isPortValid = portInput.isNotBlank() && portInput.toIntOrNull()?.let { it in 1..65535 } ?: false
    val isTokenValid = tokenInput.isNotBlank()
    val allFieldsValid = isHostValid && isPortValid && isTokenValid
    val canConnect = allFieldsValid && !isConnecting

    AlertDialog(
        onDismissRequest = {
            if (!isConnecting) {
                viewModel.clearConnectionError()
                onDismiss()
            }
        },
        title = {
            Text(stringResource(R.string.setup_bridge_description))
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Host field
                OutlinedTextField(
                    value = hostInput,
                    onValueChange = { hostInput = it },
                    label = { Text(stringResource(R.string.bridge_host_label)) },
                    placeholder = { Text("192.168.x.x") },
                    singleLine = true,
                    enabled = !isConnecting,
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii),
                    isError = hostInput.isNotBlank() && !isHostValid
                )

                // Port field
                OutlinedTextField(
                    value = portInput,
                    onValueChange = { portInput = it },
                    label = { Text(stringResource(R.string.bridge_port_label)) },
                    singleLine = true,
                    enabled = !isConnecting,
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    isError = portInput.isNotBlank() && !isPortValid
                )

                // Token field with visibility toggle
                OutlinedTextField(
                    value = tokenInput,
                    onValueChange = { tokenInput = it },
                    label = { Text(stringResource(R.string.bridge_token_label)) },
                    singleLine = true,
                    enabled = !isConnecting,
                    modifier = Modifier.fillMaxWidth(),
                    visualTransformation = if (showTokenPassword) {
                        VisualTransformation.None
                    } else {
                        PasswordVisualTransformation()
                    },
                    trailingIcon = {
                        IconButton(
                            onClick = { showTokenPassword = !showTokenPassword },
                            enabled = !isConnecting
                        ) {
                            Icon(
                                imageVector = if (showTokenPassword) {
                                    Icons.Default.VisibilityOff
                                } else {
                                    Icons.Default.Visibility
                                },
                                contentDescription = if (showTokenPassword) {
                                    "Hide token"
                                } else {
                                    "Show token"
                                }
                            )
                        }
                    },
                    isError = tokenInput.isNotBlank() && !isTokenValid
                )

                // Loading state
                if (isConnecting) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .width(32.dp)
                                .height(32.dp),
                            strokeWidth = 3.dp
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = stringResource(R.string.bridge_connecting),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }

                // Error message
                if (connectionError != null) {
                    Text(
                        text = stringResource(R.string.bridge_error, connectionError ?: ""),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val port = portInput.toIntOrNull() ?: 8922
                    viewModel.saveBridgeConfig(hostInput, port, tokenInput)
                },
                enabled = canConnect
            ) {
                Text(stringResource(R.string.connect_to_bridge))
            }
        },
        dismissButton = {
            TextButton(
                onClick = {
                    viewModel.clearConnectionError()
                    onDismiss()
                },
                enabled = !isConnecting
            ) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}
