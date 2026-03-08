package com.savia.mobile.ui.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.savia.mobile.R

/**
 * Settings screen for app configuration and status display.
 *
 * Displays:
 * - Bridge connection status (connected/disconnected with host:port)
 * - User profile link
 * - Theme selection
 * - Language selection
 * - About app information
 *
 * Features:
 * - Clickable Bridge status card triggers disconnect confirmation dialog
 * - Color-coded status: green for connected, red for disconnected
 * - All settings are placeholders for future implementation
 *
 * Clean Architecture Role: UI Layer (Presentation)
 * - SettingsViewModel provides Bridge connection state
 * - SettingsScreen renders UI based on state
 * - No business logic, pure UI with minimal state
 *
 * @param viewModel SettingsViewModel providing Bridge status state
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showDisconnectDialog by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.nav_settings)) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.surface
            )
        )

        Column(modifier = Modifier.padding(top = 8.dp)) {
            // Bridge connection status
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .clickable { if (uiState.isBridgeConnected) showDisconnectDialog = true },
                colors = CardDefaults.cardColors(
                    containerColor = if (uiState.isBridgeConnected)
                        MaterialTheme.colorScheme.primaryContainer
                    else
                        MaterialTheme.colorScheme.errorContainer
                )
            ) {
                ListItem(
                    headlineContent = {
                        Text(
                            stringResource(R.string.settings_bridge),
                            style = MaterialTheme.typography.titleMedium
                        )
                    },
                    supportingContent = {
                        Text(
                            text = if (uiState.isBridgeConnected)
                                stringResource(
                                    R.string.settings_bridge_connected,
                                    uiState.bridgeHost,
                                    uiState.bridgePort
                                )
                            else
                                stringResource(R.string.settings_bridge_not_connected),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    },
                    leadingContent = {
                        Icon(
                            Icons.Default.Cloud,
                            contentDescription = null,
                            tint = if (uiState.isBridgeConnected)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.error
                        )
                    }
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // User profile
            SettingsItem(
                icon = { Icon(Icons.Default.Person, contentDescription = null) },
                title = stringResource(R.string.settings_profile),
                subtitle = stringResource(R.string.settings_profile_desc)
            )

            // Theme
            SettingsItem(
                icon = { Icon(Icons.Default.DarkMode, contentDescription = null) },
                title = stringResource(R.string.settings_theme),
                subtitle = stringResource(R.string.settings_theme_desc)
            )

            // Language
            SettingsItem(
                icon = { Icon(Icons.Default.Language, contentDescription = null) },
                title = stringResource(R.string.settings_language),
                subtitle = stringResource(R.string.settings_language_desc)
            )

            // About
            SettingsItem(
                icon = { Icon(Icons.Default.Info, contentDescription = null) },
                title = stringResource(R.string.settings_about),
                subtitle = stringResource(R.string.settings_about_desc)
            )
        }
    }

    // Disconnect confirmation dialog
    if (showDisconnectDialog) {
        AlertDialog(
            onDismissRequest = { showDisconnectDialog = false },
            title = { Text(stringResource(R.string.settings_disconnect)) },
            text = { Text(stringResource(R.string.settings_disconnect_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.disconnectBridge()
                    showDisconnectDialog = false
                }) {
                    Text(stringResource(R.string.settings_disconnect))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDisconnectDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun SettingsItem(
    icon: @Composable () -> Unit,
    title: String,
    subtitle: String
) {
    ListItem(
        headlineContent = { Text(title, style = MaterialTheme.typography.titleMedium) },
        supportingContent = {
            Text(subtitle, style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        },
        leadingContent = icon
    )
}
