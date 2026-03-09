package com.savia.mobile.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.TextButton
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.savia.mobile.R
import com.savia.mobile.ui.common.SaviaLogo
import com.savia.mobile.ui.common.VersionBadge

/**
 * Profile screen for Savia Mobile v0.2.
 *
 * Displays:
 * - User avatar (CircleAvatar with photo or initials)
 * - Name, email, role, organization
 * - Stats row: Sprints | PBIs | Hours (3 columns)
 * - Active Projects section with list of project cards
 * - Project selector: tap project to setSelectedProject
 * - Settings link to existing SettingsScreen
 * - Check for Updates button (ALWAYS visible, even without profile)
 * - App version at bottom (ALWAYS visible)
 *
 * Clean Architecture Role: UI Layer (Presentation)
 * - ProfileViewModel manages profile and project selection
 * - ProfileScreen renders UI based on state
 * - No business logic, pure UI rendering
 *
 * @param viewModel ProfileViewModel providing profile state
 * @param onNavigateToSettings Callback to navigate to Settings screen
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel = hiltViewModel(),
    onNavigateToSettings: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val context = androidx.compose.ui.platform.LocalContext.current

    // Handle one-shot events (install APK intent)
    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is ProfileEvent.InstallApk -> {
                    try {
                        val file = java.io.File(event.apkPath)
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                    } catch (e: Exception) {
                        snackbarHostState.showSnackbar("Error installing: ${e.message}")
                    }
                }
            }
        }
    }

    // Show errors
    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = { SaviaLogo(modifier = Modifier.padding(start = 12.dp)) },
                title = { Text(stringResource(R.string.profile_title)) },
                actions = {
                    VersionBadge()
                    androidx.compose.material3.IconButton(
                        onClick = onNavigateToSettings
                    ) {
                        Icon(
                            Icons.Default.Settings,
                            contentDescription = stringResource(R.string.nav_settings),
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Loading indicator
            if (uiState.isLoading) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(120.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
            }

            val userProfile = uiState.userProfile

            // Profile loaded: show header, stats, projects
            if (userProfile != null) {
                item {
                    UserProfileHeader(profile = userProfile)
                }

                item {
                    StatsRow(profile = userProfile)
                }

                item {
                    Text(
                        text = stringResource(R.string.profile_active_projects),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                }

                items(uiState.projects) { project ->
                    ProjectCard(
                        project = project,
                        isSelected = project.id == uiState.selectedProjectId,
                        onClick = { viewModel.selectProject(project.id) }
                    )
                }
            }

            // Profile not loaded and not loading: show configure/retry
            if (userProfile == null && !uiState.isLoading) {
                item {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp)
                    ) {
                        Icon(
                            Icons.Default.Person,
                            contentDescription = "Profile not configured",
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = stringResource(R.string.profile_configure_bridge),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Button(
                            onClick = onNavigateToSettings,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.profile_go_to_settings))
                        }
                        Button(
                            onClick = { viewModel.loadProfileData() },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.profile_retry))
                        }
                    }
                }
            }

            // Update checker — ALWAYS visible regardless of profile state
            item {
                Spacer(modifier = Modifier.height(8.dp))
            }

            item {
                UpdateChecker(
                    isChecking = uiState.updateCheckingUpdate,
                    isDownloading = uiState.updateDownloading,
                    downloadProgress = uiState.updateDownloadProgress,
                    updateAvailable = uiState.updateAvailable,
                    updateDownloaded = uiState.updateDownloaded,
                    pendingUpdate = uiState.pendingUpdate,
                    onCheckUpdates = { viewModel.checkForUpdates() },
                    onDownloadAndInstall = { viewModel.downloadAndInstallUpdate() },
                    onInstall = { viewModel.installDownloadedUpdate() }
                )
            }

            // App version — ALWAYS visible
            item {
                AppVersionFooter()
            }

            item {
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

/**
 * User profile header with avatar and basic info.
 */
@Composable
private fun UserProfileHeader(profile: com.savia.domain.model.UserProfile) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Avatar
        Box(
            modifier = Modifier
                .size(64.dp)
                .background(
                    color = MaterialTheme.colorScheme.primary,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Default.Person,
                contentDescription = "Profile photo placeholder",
                modifier = Modifier.size(40.dp),
                tint = MaterialTheme.colorScheme.onPrimary
            )
        }

        // Name and email
        Text(
            text = profile.name,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = profile.email,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        // Role and organization
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = profile.role,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            Text(
                text = " • ",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = profile.organization,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Stats row showing sprints managed, PBIs completed, and hours logged.
 */
@Composable
private fun StatsRow(profile: com.savia.domain.model.UserProfile) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        StatColumn(
            label = stringResource(R.string.profile_sprints),
            value = (profile.stats?.sprintsManaged ?: 0).toString(),
            modifier = Modifier.weight(1f)
        )
        StatColumn(
            label = stringResource(R.string.profile_pbis),
            value = (profile.stats?.pbisCompleted ?: 0).toString(),
            modifier = Modifier.weight(1f)
        )
        StatColumn(
            label = stringResource(R.string.profile_hours),
            value = String.format("%.0f", profile.stats?.hoursLogged ?: 0f),
            modifier = Modifier.weight(1f)
        )
    }
}

/**
 * Single stat column.
 */
@Composable
private fun StatColumn(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Project card for project selection.
 */
@Composable
private fun ProjectCard(
    project: com.savia.domain.model.Project,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected)
                MaterialTheme.colorScheme.primaryContainer
            else
                MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = project.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = stringResource(R.string.profile_team, project.team),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                val currentSprint = project.currentSprint
                if (currentSprint != null) {
                    Text(
                        text = currentSprint,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
            val healthColor = when {
                project.health >= 75 -> MaterialTheme.colorScheme.primary
                project.health >= 50 -> MaterialTheme.colorScheme.outline
                else -> MaterialTheme.colorScheme.error
            }
            Box(
                modifier = Modifier
                    .size(16.dp)
                    .background(
                        color = healthColor,
                        shape = CircleShape
                    )
            )
        }
    }
}

/**
 * Update checker section with check, download, and install buttons.
 *
 * States:
 * 1. Initial: "Check for Updates" button
 * 2. Checking: spinner
 * 3. Update available: shows version info + "Download and Install" button
 * 4. Downloading: progress bar
 * 5. Downloaded: "Install" button
 */
@Composable
private fun UpdateChecker(
    isChecking: Boolean,
    isDownloading: Boolean,
    downloadProgress: Float,
    updateAvailable: Boolean,
    updateDownloaded: Boolean,
    pendingUpdate: com.savia.domain.model.AppUpdate?,
    onCheckUpdates: () -> Unit,
    onDownloadAndInstall: () -> Unit,
    onInstall: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
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
                verticalAlignment = Alignment.CenterVertically,
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
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    if (updateAvailable && pendingUpdate != null) {
                        Text(
                            text = "v${pendingUpdate.version} disponible (${pendingUpdate.size / 1024 / 1024} MB)",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
                if (isChecking) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                }
            }

            // Download progress bar
            if (isDownloading) {
                LinearProgressIndicator(
                    progress = { downloadProgress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp),
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant
                )
                Text(
                    text = "${(downloadProgress * 100).toInt()}%",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // Action buttons based on state
            if (!isChecking && !isDownloading) {
                when {
                    updateDownloaded -> {
                        Button(
                            onClick = onInstall,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.profile_download_update))
                        }
                        TextButton(
                            onClick = onCheckUpdates,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.profile_check_updates_btn))
                        }
                    }
                    updateAvailable -> {
                        Button(
                            onClick = onDownloadAndInstall,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.profile_download_update))
                        }
                        TextButton(
                            onClick = onCheckUpdates,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.profile_check_updates_btn))
                        }
                    }
                    else -> {
                        Button(
                            onClick = onCheckUpdates,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.profile_check_updates_btn))
                        }
                    }
                }
            }
        }
    }
}

/**
 * App version footer.
 */
@Composable
private fun AppVersionFooter() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                Icons.Default.Info,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "  Savia v${com.savia.mobile.BuildConfig.VERSION_NAME}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
