package com.savia.mobile.ui.commands

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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.automirrored.filled.FormatListBulleted
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SyncAlt
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material.icons.filled.ViewColumn
import androidx.compose.material.icons.filled.Workspaces
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.savia.mobile.R

/**
 * Commands screen (Command Palette) for Savia Mobile v0.2.
 *
 * Displays:
 * - Search bar at top for filtering commands
 * - Horizontal tabs for command families (Sprint, Mi Trabajo, Backlog, etc.)
 * - Grid/list of command cards with icon, name, and description
 * - Favorites section (if stored in DataStore)
 * - Recent commands section
 * - Tap card to navigate to chat with pre-filled command
 *
 * Clean Architecture Role: UI Layer (Presentation)
 * - CommandsViewModel manages families and filtering logic
 * - CommandsScreen renders UI based on state
 * - No business logic, pure UI rendering
 *
 * @param viewModel CommandsViewModel providing command state
 * @param onNavigateToChat Callback to navigate to Chat with command pre-filled
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommandsScreen(
    viewModel: CommandsViewModel = hiltViewModel(),
    onNavigateToChat: (String) -> Unit = {}
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
                title = { Text("Commands") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Search bar
            SearchBar(
                query = uiState.searchQuery,
                onQueryChange = { viewModel.search(it) },
                modifier = Modifier.padding(16.dp)
            )

            if (uiState.isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else {
                // Tabs for families
                if (uiState.searchQuery.isEmpty()) {
                    ScrollableTabRow(
                        selectedTabIndex = uiState.families.indexOfFirst {
                            it.id == uiState.selectedFamilyId
                        }.takeIf { it >= 0 } ?: 0,
                        modifier = Modifier.fillMaxWidth(),
                        edgePadding = 16.dp,
                        containerColor = MaterialTheme.colorScheme.surface,
                        divider = {}
                    ) {
                        Tab(
                            selected = uiState.selectedFamilyId == null,
                            onClick = { viewModel.selectFamily(null) },
                            text = { Text("All", maxLines = 1, overflow = TextOverflow.Ellipsis) }
                        )
                        uiState.families.forEach { family ->
                            Tab(
                                selected = family.id == uiState.selectedFamilyId,
                                onClick = { viewModel.selectFamily(family.id) },
                                text = { Text(family.name, maxLines = 1, overflow = TextOverflow.Ellipsis) }
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }

                // Commands grid
                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    contentPadding = PaddingValues(vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(uiState.filteredCommands) { command ->
                        CommandCard(
                            command = command,
                            family = uiState.families.find { it.id == command.family },
                            onClick = { onNavigateToChat(command.name) },
                            onExecute = { viewModel.executeCommand(command.name) },
                            isExecuting = uiState.isExecuting
                        )
                    }

                    if (uiState.filteredCommands.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(32.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "No commands found",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Search bar for filtering commands.
 */
@Composable
private fun SearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        modifier = modifier.fillMaxWidth(),
        placeholder = { Text("Search commands") },
        leadingIcon = {
            Icon(
                Icons.Default.Search,
                contentDescription = "Search",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        },
        shape = RoundedCornerShape(24.dp),
        singleLine = true,
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions.Default
    )
}

/**
 * Command card for grid display with dynamic icon, name, and description.
 */
@Composable
private fun CommandCard(
    command: com.savia.domain.model.SlashCommand,
    family: com.savia.domain.model.CommandFamily?,
    onClick: () -> Unit,
    onExecute: () -> Unit,
    isExecuting: Boolean
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(140.dp)
            .clickable(enabled = !isExecuting, onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primary,
                        shape = RoundedCornerShape(8.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = getIconForFamily(family?.icon ?: ""),
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colorScheme.onPrimary
                )
            }

            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = command.name,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = command.description,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            if (isExecuting) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    color = MaterialTheme.colorScheme.primary,
                    strokeWidth = 2.dp
                )
            }
        }
    }
}

/**
 * Maps CommandFamily icon IDs to Material Design icons.
 */
private fun getIconForFamily(iconId: String): androidx.compose.ui.graphics.vector.ImageVector =
    when (iconId) {
        "ic_sprint" -> Icons.Default.DateRange
        "ic_board" -> Icons.Default.ViewColumn
        "ic_backlog" -> Icons.AutoMirrored.Filled.FormatListBulleted
        "ic_time" -> Icons.Default.AccessTime
        "ic_approval" -> Icons.Default.CheckCircle
        "ic_report" -> Icons.Default.Assessment
        "ic_workspace" -> Icons.Default.Workspaces
        "ic_commands" -> Icons.Default.Terminal
        "ic_integration" -> Icons.Default.SyncAlt
        "ic_analytics" -> Icons.Default.Insights
        else -> Icons.Default.Extension
    }
