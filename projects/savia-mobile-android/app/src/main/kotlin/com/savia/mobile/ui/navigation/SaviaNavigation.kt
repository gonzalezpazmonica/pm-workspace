package com.savia.mobile.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.savia.mobile.ui.approvals.ApprovalsScreen
import com.savia.mobile.ui.capture.CaptureScreen
import com.savia.mobile.ui.chat.ChatScreen
import com.savia.mobile.ui.commands.CommandsScreen
import com.savia.mobile.ui.dashboard.DashboardScreen
import com.savia.mobile.ui.home.HomeScreen
import com.savia.mobile.ui.kanban.KanbanScreen
import com.savia.mobile.ui.profile.ProfileScreen
import com.savia.mobile.ui.settings.CompanyProfileScreen
import com.savia.mobile.ui.settings.GitConfigScreen
import com.savia.mobile.ui.settings.SettingsScreen
import com.savia.mobile.ui.settings.TeamManagementScreen
import com.savia.mobile.ui.timelog.TimeLogScreen

/**
 * Navigation destinations in the app using sealed class pattern.
 *
 * Each screen represents a tab in the bottom navigation bar.
 * Routes are used by NavHost for composable resolution.
 * Icons have selected/unselected variants for navigation bar state changes.
 *
 * @property route navigation path for NavHost
 * @property title display label
 * @property selectedIcon Material 3 icon when tab is active
 * @property unselectedIcon Material 3 icon when tab is inactive
 */
sealed class Screen(
    val route: String,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    /**
     * Home screen: dashboard with sprint progress, tasks, and activity.
     * Displays project overview, sprint metrics, and quick access to key functions.
     */
    data object Home : Screen(
        route = "home",
        title = "Home",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )

    /**
     * Chat screen: main messaging interface with Claude.
     * Shows conversation history, message input, and supports slash commands.
     * Handles both Bridge connection and direct API key authentication.
     */
    data object Chat : Screen(
        route = "chat",
        title = "Chat",
        selectedIcon = Icons.AutoMirrored.Filled.Chat,
        unselectedIcon = Icons.AutoMirrored.Outlined.Chat
    )

    /**
     * Commands screen: command palette for accessing PM-Workspace commands.
     * Organized by family, searchable, with quick access to frequently used commands.
     */
    data object Commands : Screen(
        route = "commands",
        title = "Commands",
        selectedIcon = Icons.Filled.Bolt,
        unselectedIcon = Icons.Outlined.Bolt
    )

    /**
     * Profile screen: user profile and project management.
     * Shows user info, active projects, and app settings/update management.
     */
    data object Profile : Screen(
        route = "profile",
        title = "Profile",
        selectedIcon = Icons.Filled.Person,
        unselectedIcon = Icons.Outlined.Person
    )

    /**
     * Kanban board screen: visualize work items across columns.
     * Filter and manage tasks in workflow pipeline.
     */
    data object Kanban : Screen(
        route = "kanban",
        title = "Board",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )

    /**
     * Time log screen: track hours spent on tasks.
     * Log time entries and view daily summary.
     */
    data object TimeLog : Screen(
        route = "timelog",
        title = "Time Log",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )

    /**
     * Capture screen: quick item creation.
     * Create new PBIs, bugs, or notes rapidly.
     */
    data object Capture : Screen(
        route = "capture",
        title = "Capture",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )

    /**
     * Approvals screen: review and approve pending requests.
     * Handle PRs, infrastructure changes, and deployments.
     */
    data object Approvals : Screen(
        route = "approvals",
        title = "Approvals",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )

    /**
     * Settings screen: configuration and status display.
     * Shows Bridge connection status, theme, language, and app info.
     * Allows disconnecting from Bridge and clearing configuration.
     */
    data object Settings : Screen(
        route = "settings",
        title = "Settings",
        selectedIcon = Icons.Filled.Settings,
        unselectedIcon = Icons.Outlined.Settings
    )

    /**
     * Git configuration screen: manage git name, email, PAT.
     */
    data object GitConfig : Screen(
        route = "gitconfig",
        title = "Git Config",
        selectedIcon = Icons.Filled.Settings,
        unselectedIcon = Icons.Outlined.Settings
    )

    /**
     * Team management screen: manage team members.
     */
    data object TeamManagement : Screen(
        route = "team",
        title = "Team",
        selectedIcon = Icons.Filled.Person,
        unselectedIcon = Icons.Outlined.Person
    )

    /**
     * Company profile screen: manage company data.
     */
    data object CompanyProfile : Screen(
        route = "company",
        title = "Company",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )

    /**
     * File browser screen: navigate PM-Workspace files.
     * View code (with line numbers) and markdown (rendered).
     * Accessible from Home screen via "Files" quick action.
     */
    data object Files : Screen(
        route = "files",
        title = "Files",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )

    /**
     * Sessions/Dashboard screen: lists all past conversations.
     * Users can select a conversation to resume it or delete it.
     * Empty state shown when no conversations exist.
     */
    data object Sessions : Screen(
        route = "sessions",
        title = "Sessions",
        selectedIcon = Icons.Filled.Forum,
        unselectedIcon = Icons.Outlined.Forum
    )
}

/** List of all screens displayed in bottom navigation bar */
val bottomNavScreens = listOf(
    Screen.Home,
    Screen.Chat,
    Screen.Commands,
    Screen.Profile
)

/**
 * Main navigation host for Savia Mobile app.
 *
 * Sets up:
 * - NavHost with bottom navigation bar (Chat, Sessions, Settings tabs)
 * - Composable routes for each screen
 * - Argument passing for conversation ID navigation
 * - Deep linking support for navigation from Sessions to Chat
 *
 * Start destination is Chat screen (messaging interface).
 * Tab state is preserved via saveState/restoreState flags.
 *
 * @param navController NavController for managing navigation state
 */
@Composable
fun SaviaNavHost(
    navController: NavHostController = rememberNavController()
) {
    Scaffold(
        bottomBar = { SaviaBottomBar(navController) }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            // Main tabs (bottom navigation)
            composable(Screen.Home.route) {
                HomeScreen(
                    onNavigateToSettings = { navController.navigate(Screen.Settings.route) },
                    onNavigateToCapture = { navController.navigate(Screen.Capture.route) },
                    onNavigateToBoard = { navController.navigate(Screen.Kanban.route) },
                    onNavigateToTimelog = { navController.navigate(Screen.TimeLog.route) },
                    onNavigateToApprovals = { navController.navigate(Screen.Approvals.route) },
                    onNavigateToFiles = { navController.navigate(Screen.Files.route) }
                )
            }

            composable(Screen.Chat.route) { ChatScreen() }

            composable(Screen.Commands.route) {
                CommandsScreen(
                    onNavigateToChat = { command ->
                        navController.navigate(Screen.Chat.route)
                    }
                )
            }

            composable(Screen.Profile.route) {
                ProfileScreen(
                    onNavigateToSettings = { navController.navigate(Screen.Settings.route) }
                )
            }

            // Secondary screens (navigated from main tabs)
            composable(Screen.Kanban.route) {
                KanbanScreen(
                    onCardClick = { cardId ->
                        // TODO: Expand card details in BottomSheet
                    }
                )
            }

            composable(Screen.TimeLog.route) {
                TimeLogScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }

            composable(Screen.Capture.route) {
                CaptureScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }

            composable(Screen.Approvals.route) {
                ApprovalsScreen()
            }

            composable(Screen.Settings.route) {
                SettingsScreen(
                    onNavigateToGitConfig = { navController.navigate(Screen.GitConfig.route) },
                    onNavigateToTeam = { navController.navigate(Screen.TeamManagement.route) },
                    onNavigateToCompany = { navController.navigate(Screen.CompanyProfile.route) },
                    onNavigateToProfile = {
                        navController.navigate(Screen.Profile.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                inclusive = false
                            }
                            launchSingleTop = true
                        }
                    }
                )
            }

            composable(Screen.GitConfig.route) {
                GitConfigScreen(onNavigateBack = { navController.popBackStack() })
            }

            composable(Screen.TeamManagement.route) {
                TeamManagementScreen(onNavigateBack = { navController.popBackStack() })
            }

            composable(Screen.CompanyProfile.route) {
                CompanyProfileScreen(onNavigateBack = { navController.popBackStack() })
            }

            composable(Screen.Files.route) {
                com.savia.mobile.ui.filebrowser.FileBrowserScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }

            // Legacy Sessions screen
            composable(Screen.Sessions.route) {
                DashboardScreen(
                    onConversationSelected = { conversationId ->
                        navController.navigate("chat?conversationId=$conversationId") {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = false
                            }
                            launchSingleTop = true
                        }
                    }
                )
            }

            composable(
                route = "chat?conversationId={conversationId}",
                arguments = listOf(
                    androidx.navigation.navArgument("conversationId") {
                        defaultValue = ""
                        nullable = true
                    }
                )
            ) { backStackEntry ->
                val conversationId = backStackEntry.arguments?.getString("conversationId")
                ChatScreen(conversationIdToLoad = conversationId?.takeIf { it.isNotBlank() })
            }
        }
    }
}

/**
 * Bottom navigation bar component showing Chat, Sessions, Settings tabs.
 *
 * Features:
 * - Reactive state: updates selected icon/label based on current route
 * - State preservation: saveState/restoreState keeps tab scroll position
 * - Single top: prevents duplicate instances of same screen in back stack
 * - Hierarchy matching: handles nested navigation graphs correctly
 *
 * @param navController for observing current destination and navigation
 */
@Composable
private fun SaviaBottomBar(navController: NavHostController) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    NavigationBar {
        bottomNavScreens.forEach { screen ->
            val selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true

            NavigationBarItem(
                icon = {
                    Icon(
                        imageVector = if (selected) screen.selectedIcon else screen.unselectedIcon,
                        contentDescription = screen.title
                    )
                },
                label = { Text(screen.title) },
                selected = selected,
                onClick = {
                    navController.navigate(screen.route) {
                        popUpTo(navController.graph.findStartDestination().id) {
                            inclusive = false
                        }
                        launchSingleTop = true
                    }
                }
            )
        }
    }
}
