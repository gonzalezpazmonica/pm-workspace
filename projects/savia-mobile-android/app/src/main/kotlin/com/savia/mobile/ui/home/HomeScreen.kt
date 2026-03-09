package com.savia.mobile.ui.home

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.savia.mobile.R
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.savia.mobile.ui.common.SaviaLogo
import com.savia.mobile.ui.common.VersionBadge

/**
 * Home/Dashboard screen for Savia Mobile v0.2.
 *
 * Displays:
 * - Greeting header with user/project/sprint info
 * - Sprint progress card with linear progress indicator
 * - Two metric cards: blocked items + hours today
 * - My Tasks compact list (first 3 items assigned to user)
 * - Activity feed (last 5 sprint items)
 * - FloatingActionButton for quick capture
 * - Pull-to-refresh support
 *
 * Clean Architecture Role: UI Layer (Presentation)
 * - HomeViewModel manages state and business logic
 * - HomeScreen renders UI based on state
 * - No business logic, pure UI rendering
 *
 * @param viewModel HomeViewModel providing dashboard state
 * @param onNavigateToSettings Callback to navigate to Settings screen
 * @param onNavigateToCapture Callback to navigate to Capture screen
 * @param onNavigateToBoard Callback to navigate to Kanban board
 * @param onNavigateToTimelog Callback to navigate to time log screen
 * @param onNavigateToApprovals Callback to navigate to approvals screen
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToSettings: () -> Unit = {},
    onNavigateToCapture: () -> Unit = {},
    onNavigateToBoard: () -> Unit = {},
    onNavigateToTimelog: () -> Unit = {},
    onNavigateToApprovals: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

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
                title = { Text(stringResource(R.string.home_title)) },
                actions = {
                    VersionBadge()
                    IconButton(
                        onClick = onNavigateToSettings
                    ) {
                        Icon(
                            Icons.Default.Settings,
                            contentDescription = stringResource(R.string.nav_settings),
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    IconButton(
                        onClick = { viewModel.refresh() }
                    ) {
                        Icon(
                            Icons.Default.Refresh,
                            contentDescription = stringResource(R.string.refresh),
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onNavigateToCapture,
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(
                    Icons.Default.Add,
                    contentDescription = stringResource(R.string.home_quick_capture),
                    tint = MaterialTheme.colorScheme.onPrimary
                )
            }
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        if (uiState.isLoading && uiState.selectedProject == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Greeting header
                item {
                    GreetingHeader(
                        projectName = uiState.selectedProject ?: stringResource(R.string.home_no_project),
                        sprintName = uiState.sprintName,
                        availableProjects = uiState.availableProjects,
                        availableSprints = uiState.availableSprints,
                        onProjectSelected = { viewModel.selectProject(it) },
                        onSprintSelected = { viewModel.selectSprint(it) }
                    )
                }

                // Sprint progress card
                item {
                    SprintProgressCard(
                        progress = uiState.sprintProgress,
                        completedPoints = uiState.completedStoryPoints,
                        totalPoints = uiState.totalStoryPoints
                    )
                }

                // Metrics row (blocked items + hours today)
                item {
                    MetricsRow(
                        blockedCount = uiState.blockedItemsCount,
                        hoursToday = uiState.hoursToday,
                        onHoursClick = onNavigateToTimelog
                    )
                }

                // My Tasks section
                if (uiState.myTasks.isNotEmpty()) {
                    item {
                        MyTasksSection(tasks = uiState.myTasks)
                    }
                }

                // Activity feed
                if (uiState.recentActivity.isNotEmpty()) {
                    item {
                        Text(
                            text = stringResource(R.string.home_recent_activity),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }
                    items(uiState.recentActivity) { activity ->
                        ActivityItem(title = activity)
                    }
                }

                // Quick action buttons
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        QuickActionButton(
                            label = stringResource(R.string.home_see_board),
                            onClick = onNavigateToBoard,
                            modifier = Modifier.weight(1f)
                        )
                        QuickActionButton(
                            label = stringResource(R.string.home_approvals),
                            onClick = onNavigateToApprovals,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(32.dp))
                }
            }
        }
    }
}

/**
 * Greeting header with user name, project dropdown selector, and sprint dropdown selector.
 *
 * Both selectors render as bordered cards (OutlinedCard style) with the selected value
 * and a dropdown arrow, making them clearly visible and tappable.
 */
@Composable
private fun GreetingHeader(
    projectName: String,
    sprintName: String,
    availableProjects: List<com.savia.domain.model.Project>,
    availableSprints: List<String>,
    onProjectSelected: (String) -> Unit,
    onSprintSelected: (String) -> Unit
) {
    var projectDropdownExpanded by remember { mutableStateOf(false) }
    var sprintDropdownExpanded by remember { mutableStateOf(false) }
    var projectSearchQuery by remember { mutableStateOf("") }
    var sprintSearchQuery by remember { mutableStateOf("") }

    val filteredProjects = remember(availableProjects, projectSearchQuery) {
        if (projectSearchQuery.isBlank()) availableProjects
        else availableProjects.filter {
            it.name.contains(projectSearchQuery, ignoreCase = true) ||
            it.id.contains(projectSearchQuery, ignoreCase = true)
        }
    }

    val filteredSprints = remember(availableSprints, sprintSearchQuery) {
        if (sprintSearchQuery.isBlank()) availableSprints
        else availableSprints.filter {
            it.contains(sprintSearchQuery, ignoreCase = true)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Greeting text
        Text(
            text = stringResource(R.string.home_welcome),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )

        // --- Project Selector (bordered card) ---
        Box(modifier = Modifier.fillMaxWidth()) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        projectSearchQuery = ""
                        projectDropdownExpanded = true
                    },
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface
                ),
                border = BorderStroke(
                    1.dp,
                    MaterialTheme.colorScheme.outline
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = stringResource(R.string.home_select_project),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = projectName,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Icon(
                        Icons.Default.ArrowDropDown,
                        contentDescription = stringResource(R.string.home_select_project),
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }

            DropdownMenu(
                expanded = projectDropdownExpanded,
                onDismissRequest = {
                    projectDropdownExpanded = false
                    projectSearchQuery = ""
                },
                modifier = Modifier
                    .fillMaxWidth(0.85f)
                    .heightIn(max = 300.dp)
            ) {
                OutlinedTextField(
                    value = projectSearchQuery,
                    onValueChange = { projectSearchQuery = it },
                    placeholder = { Text(stringResource(R.string.home_select_project)) },
                    leadingIcon = {
                        Icon(Icons.Default.Search, contentDescription = null,
                            modifier = Modifier.size(20.dp))
                    },
                    trailingIcon = {
                        if (projectSearchQuery.isNotEmpty()) {
                            IconButton(onClick = { projectSearchQuery = "" }) {
                                Icon(Icons.Default.Close, contentDescription = null,
                                    modifier = Modifier.size(20.dp))
                            }
                        }
                    },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    textStyle = MaterialTheme.typography.bodyMedium
                )

                filteredProjects.forEach { project ->
                    DropdownMenuItem(
                        text = {
                            Column {
                                Text(project.name, style = MaterialTheme.typography.bodyMedium)
                                Text(
                                    project.team,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        },
                        onClick = {
                            onProjectSelected(project.id)
                            projectDropdownExpanded = false
                            projectSearchQuery = ""
                        }
                    )
                }

                if (filteredProjects.isEmpty()) {
                    DropdownMenuItem(
                        text = {
                            Text(
                                stringResource(R.string.home_no_project),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        },
                        onClick = {},
                        enabled = false
                    )
                }
            }
        }

        // --- Sprint Selector (bordered card) ---
        Box(modifier = Modifier.fillMaxWidth()) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        sprintSearchQuery = ""
                        sprintDropdownExpanded = true
                    },
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface
                ),
                border = BorderStroke(
                    1.dp,
                    MaterialTheme.colorScheme.outlineVariant
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Sprint",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = sprintName,
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Icon(
                        Icons.Default.ArrowDropDown,
                        contentDescription = "Select sprint",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }

            DropdownMenu(
                expanded = sprintDropdownExpanded,
                onDismissRequest = {
                    sprintDropdownExpanded = false
                    sprintSearchQuery = ""
                },
                modifier = Modifier
                    .fillMaxWidth(0.85f)
                    .heightIn(max = 250.dp)
            ) {
                OutlinedTextField(
                    value = sprintSearchQuery,
                    onValueChange = { sprintSearchQuery = it },
                    placeholder = { Text("Search sprints") },
                    leadingIcon = {
                        Icon(Icons.Default.Search, contentDescription = null,
                            modifier = Modifier.size(20.dp))
                    },
                    trailingIcon = {
                        if (sprintSearchQuery.isNotEmpty()) {
                            IconButton(onClick = { sprintSearchQuery = "" }) {
                                Icon(Icons.Default.Close, contentDescription = null,
                                    modifier = Modifier.size(20.dp))
                            }
                        }
                    },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    textStyle = MaterialTheme.typography.bodyMedium
                )

                filteredSprints.forEach { sprint ->
                    DropdownMenuItem(
                        text = {
                            Text(sprint, style = MaterialTheme.typography.bodyMedium)
                        },
                        onClick = {
                            onSprintSelected(sprint)
                            sprintDropdownExpanded = false
                            sprintSearchQuery = ""
                        }
                    )
                }

                if (filteredSprints.isEmpty()) {
                    DropdownMenuItem(
                        text = {
                            Text(
                                "No sprints found",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        },
                        onClick = {},
                        enabled = false
                    )
                }
            }
        }
    }
}

/**
 * Sprint progress card showing linear progress and story point summary.
 */
@Composable
private fun SprintProgressCard(
    progress: Float,
    completedPoints: Int,
    totalPoints: Int
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
            Text(
                text = stringResource(R.string.home_sprint_progress),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp),
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant
            )
            Text(
                text = "$completedPoints / $totalPoints SP",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Metrics row displaying blocked items count and hours logged today.
 */
@Composable
private fun MetricsRow(
    blockedCount: Int,
    hoursToday: Float,
    onHoursClick: () -> Unit = {}
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        MetricCard(
            label = stringResource(R.string.home_blocked),
            value = blockedCount.toString(),
            icon = Icons.Default.Block,
            modifier = Modifier.weight(1f)
        )
        MetricCard(
            label = stringResource(R.string.home_hours_today),
            value = String.format("%.1f", hoursToday),
            icon = Icons.Default.CheckCircle,
            modifier = Modifier
                .weight(1f)
                .clickable(onClick = onHoursClick)
        )
    }
}

/**
 * Single metric card displaying count/value with icon and label.
 */
@Composable
private fun MetricCard(
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
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
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
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
 * My Tasks section showing first 3 items assigned to user.
 */
@Composable
private fun MyTasksSection(tasks: List<com.savia.domain.model.BoardItem>) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = stringResource(R.string.home_my_tasks),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        tasks.forEach { task ->
            TaskItem(title = task.title, storyPoints = task.storyPoints)
        }
    }
}

/**
 * Single task item in My Tasks list.
 */
@Composable
private fun TaskItem(
    title: String,
    storyPoints: Int?
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            if (storyPoints != null) {
                Box(
                    modifier = Modifier
                        .background(
                            color = MaterialTheme.colorScheme.primary,
                            shape = RoundedCornerShape(4.dp)
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "$storyPoints",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimary,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

/**
 * Activity feed item showing activity title.
 */
@Composable
private fun ActivityItem(title: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(50.dp)
                )
        )
        Text(
            text = title,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

/**
 * Quick action button for navigating to board/approvals.
 */
@Composable
private fun QuickActionButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
