package com.savia.mobile.ui.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width

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
    viewModel: SettingsViewModel = hiltViewModel(),
    onNavigateToGitConfig: () -> Unit = {},
    onNavigateToTeam: () -> Unit = {},
    onNavigateToCompany: () -> Unit = {},
    onNavigateToProfile: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showDisconnectDialog by remember { mutableStateOf(false) }
    var showBridgeSetupDialog by remember { mutableStateOf(false) }
    var showThemeDialog by remember { mutableStateOf(false) }
    var showLanguageDialog by remember { mutableStateOf(false) }
    var showAboutDialog by remember { mutableStateOf(false) }

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
                    .clickable {
                        if (uiState.isBridgeConnected) showDisconnectDialog = true
                        else showBridgeSetupDialog = true
                    },
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
            ClickableSettingsItem(
                icon = { Icon(Icons.Default.Person, contentDescription = null) },
                title = uiState.userName.ifEmpty { stringResource(R.string.settings_profile) },
                subtitle = uiState.userEmail.ifEmpty { stringResource(R.string.settings_profile_desc) },
                onClick = {
                    if (uiState.userName.isEmpty()) viewModel.refreshProfile()
                    else onNavigateToProfile()
                }
            )

            // Git configuration
            ClickableSettingsItem(
                icon = { Icon(Icons.Default.Code, contentDescription = null) },
                title = stringResource(R.string.settings_git_config),
                subtitle = stringResource(R.string.settings_git_config_desc),
                onClick = onNavigateToGitConfig
            )

            // Team management
            ClickableSettingsItem(
                icon = { Icon(Icons.Default.Group, contentDescription = null) },
                title = stringResource(R.string.settings_team),
                subtitle = stringResource(R.string.settings_team_desc),
                onClick = onNavigateToTeam
            )

            // Company profile
            ClickableSettingsItem(
                icon = { Icon(Icons.Default.Business, contentDescription = null) },
                title = stringResource(R.string.settings_company),
                subtitle = stringResource(R.string.settings_company_desc),
                onClick = onNavigateToCompany
            )

            // Theme selector
            ClickableSettingsItem(
                icon = { Icon(Icons.Default.DarkMode, contentDescription = null) },
                title = stringResource(R.string.settings_theme),
                subtitle = uiState.currentTheme.toString(),
                onClick = { showThemeDialog = true }
            )

            // Language selector
            ClickableSettingsItem(
                icon = { Icon(Icons.Default.Language, contentDescription = null) },
                title = stringResource(R.string.settings_language),
                subtitle = uiState.currentLanguage.toString(),
                onClick = { showLanguageDialog = true }
            )

            // About
            ClickableSettingsItem(
                icon = { Icon(Icons.Default.Info, contentDescription = null) },
                title = stringResource(R.string.settings_about),
                subtitle = "v${uiState.appVersion}",
                onClick = { showAboutDialog = true }
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Check for Updates
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerLow
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            Icons.Default.Download,
                            contentDescription = null,
                            modifier = Modifier.size(24.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = stringResource(R.string.profile_check_updates),
                                style = MaterialTheme.typography.titleSmall
                            )
                            if (uiState.updateAvailable) {
                                Text(
                                    text = stringResource(R.string.profile_new_version),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                        if (uiState.updateCheckingUpdate || uiState.updateDownloading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                        }
                    }

                    if (!uiState.updateCheckingUpdate && !uiState.updateDownloading) {
                        Button(
                            onClick = if (uiState.updateAvailable) {
                                { viewModel.downloadUpdate() }
                            } else {
                                { viewModel.checkForUpdates() }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                if (uiState.updateAvailable) stringResource(R.string.profile_download_update)
                                else stringResource(R.string.profile_check_updates_btn)
                            )
                        }
                    }
                }
            }
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
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }

    // Theme selection dialog
    if (showThemeDialog) {
        AlertDialog(
            onDismissRequest = { showThemeDialog = false },
            title = { Text(stringResource(R.string.settings_select_theme)) },
            text = {
                Column {
                    AppTheme.values().forEach { theme ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(8.dp),
                            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = uiState.currentTheme == theme,
                                onClick = {
                                    viewModel.changeTheme(theme)
                                    showThemeDialog = false
                                }
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(theme.toString())
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showThemeDialog = false }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }

    // Language selection dialog
    if (showLanguageDialog) {
        AlertDialog(
            onDismissRequest = { showLanguageDialog = false },
            title = { Text(stringResource(R.string.settings_select_language)) },
            text = {
                Column {
                    AppLanguage.values().forEach { lang ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(8.dp),
                            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = uiState.currentLanguage == lang,
                                onClick = {
                                    viewModel.changeLanguage(lang)
                                    showLanguageDialog = false
                                }
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(lang.toString())
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showLanguageDialog = false }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }

    // Bridge setup dialog
    if (showBridgeSetupDialog) {
        BridgeSetupDialog(
            onDismiss = { showBridgeSetupDialog = false },
            onConnected = {
                showBridgeSetupDialog = false
                viewModel.refreshProfile()
            },
            viewModel = viewModel
        )
    }

    // About dialog
    if (showAboutDialog) {
        AlertDialog(
            onDismissRequest = { showAboutDialog = false },
            title = { Text(stringResource(R.string.about)) },
            text = {
                Column {
                    Text(stringResource(R.string.settings_app_version, uiState.appVersion))
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(stringResource(R.string.settings_bridge_version, uiState.bridgeVersion.ifEmpty { stringResource(R.string.unknown) }))
                }
            },
            confirmButton = {
                TextButton(onClick = { showAboutDialog = false }) {
                    Text(stringResource(R.string.ok))
                }
            }
        )
    }
}

enum class AppTheme {
    SYSTEM, LIGHT, DARK
}

enum class AppLanguage {
    SYSTEM, ES, EN
}

@Composable
private fun ClickableSettingsItem(
    icon: @Composable () -> Unit,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    ListItem(
        modifier = Modifier.clickable(onClick = onClick),
        headlineContent = { Text(title, style = MaterialTheme.typography.titleMedium) },
        supportingContent = {
            Text(subtitle, style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        },
        leadingContent = icon
    )
}
