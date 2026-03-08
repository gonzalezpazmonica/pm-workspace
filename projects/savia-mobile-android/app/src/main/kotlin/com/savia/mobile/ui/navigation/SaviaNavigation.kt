package com.savia.mobile.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.savia.mobile.R
import com.savia.mobile.ui.chat.ChatScreen
import com.savia.mobile.ui.dashboard.DashboardScreen
import com.savia.mobile.ui.settings.SettingsScreen

/**
 * Navigation destinations in the app using sealed class pattern.
 *
 * Each screen represents a tab in the bottom navigation bar.
 * Routes are used by NavHost for composable resolution.
 * Icons have selected/unselected variants for navigation bar state changes.
 *
 * @property route navigation path for NavHost
 * @property titleResId string resource ID for display label
 * @property selectedIcon Material 3 icon when tab is active
 * @property unselectedIcon Material 3 icon when tab is inactive
 */
sealed class Screen(
    val route: String,
    val titleResId: Int,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    /**
     * Chat screen: main messaging interface with Claude.
     * Shows conversation history, message input, and supports slash commands.
     * Handles both Bridge connection and direct API key authentication.
     */
    data object Chat : Screen(
        route = "chat",
        titleResId = R.string.nav_chat,
        selectedIcon = Icons.AutoMirrored.Filled.Chat,
        unselectedIcon = Icons.AutoMirrored.Outlined.Chat
    )

    /**
     * Sessions/Dashboard screen: lists all past conversations.
     * Users can select a conversation to resume it or delete it.
     * Empty state shown when no conversations exist.
     */
    data object Sessions : Screen(
        route = "sessions",
        titleResId = R.string.nav_sessions,
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
        titleResId = R.string.nav_settings,
        selectedIcon = Icons.Filled.Settings,
        unselectedIcon = Icons.Outlined.Settings
    )
}

/** List of all screens displayed in bottom navigation bar */
val bottomNavScreens = listOf(Screen.Chat, Screen.Sessions, Screen.Settings)

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
            startDestination = Screen.Chat.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Screen.Chat.route) { ChatScreen() }
            composable(Screen.Sessions.route) {
                DashboardScreen(
                    onConversationSelected = { conversationId ->
                        // Navigate to chat and pass the conversation ID
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
            composable(Screen.Settings.route) { SettingsScreen() }
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
                        contentDescription = stringResource(screen.titleResId)
                    )
                },
                label = { Text(stringResource(screen.titleResId)) },
                selected = selected,
                onClick = {
                    navController.navigate(screen.route) {
                        popUpTo(navController.graph.findStartDestination().id) {
                            saveState = true
                        }
                        launchSingleTop = true
                        restoreState = true
                    }
                }
            )
        }
    }
}
