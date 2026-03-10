package com.savia.mobile.integration

import com.google.common.truth.Truth.assertThat
import com.savia.mobile.ui.navigation.Screen
import com.savia.mobile.ui.navigation.bottomNavScreens
import org.junit.Test

/**
 * Integration tests for Navigation configuration.
 *
 * Verifies:
 * - ADR-006: Single Activity + Navigation Compose routes match spec
 * - v0.2: Navigation Compose with 4 destinations (home, chat, commands, profile)
 * - Route uniqueness and correct tab configuration
 *
 * Note: Full Compose UI navigation tests require androidTest (Espresso/ComposeTestRule)
 * which needs a device. These tests verify the configuration contract.
 */
class NavigationIntegrationTest {

    @Test
    fun `bottomNavScreens contains exactly 5 screens with files tab`() {
        assertThat(bottomNavScreens).hasSize(5)
    }

    @Test
    fun `screens match expected routes - home, chat, files, commands, profile`() {
        val routes = bottomNavScreens.map { it.route }

        assertThat(routes).containsExactly("home", "chat", "files", "commands", "profile")
    }

    @Test
    fun `Home is the first screen - matches startDestination`() {
        assertThat(bottomNavScreens[0]).isEqualTo(Screen.Home)
        assertThat(Screen.Home.route).isEqualTo("home")
    }

    @Test
    fun `all routes are unique`() {
        val routes = bottomNavScreens.map { it.route }
        assertThat(routes).containsNoDuplicates()
    }

    @Test
    fun `all screens have distinct selected and unselected icons`() {
        bottomNavScreens.forEach { screen ->
            assertThat(screen.selectedIcon).isNotEqualTo(screen.unselectedIcon)
        }
    }

    @Test
    fun `screen routes match expected pattern - lowercase no spaces`() {
        bottomNavScreens.forEach { screen ->
            assertThat(screen.route).matches("[a-z]+")
        }
    }

    @Test
    fun `Sessions screen exists with correct route`() {
        assertThat(Screen.Sessions.route).isEqualTo("sessions")
    }

    @Test
    fun `Settings screen exists with correct route`() {
        assertThat(Screen.Settings.route).isEqualTo("settings")
    }

    @Test
    fun `secondary screens have valid routes`() {
        val secondaryRoutes = listOf(
            Screen.Kanban.route,
            Screen.TimeLog.route,
            Screen.Capture.route,
            Screen.Approvals.route
        )
        secondaryRoutes.forEach { route ->
            assertThat(route).matches("[a-z]+")
        }
    }

    @Test
    fun `management screens have valid routes`() {
        val managementRoutes = listOf(
            Screen.GitConfig.route,
            Screen.TeamManagement.route,
            Screen.CompanyProfile.route
        )
        managementRoutes.forEach { route ->
            assertThat(route).matches("[a-z]+")
        }
    }

    @Test
    fun `GitConfig screen exists with correct route`() {
        assertThat(Screen.GitConfig.route).isEqualTo("gitconfig")
    }

    @Test
    fun `TeamManagement screen exists with correct route`() {
        assertThat(Screen.TeamManagement.route).isEqualTo("team")
    }

    @Test
    fun `CompanyProfile screen exists with correct route`() {
        assertThat(Screen.CompanyProfile.route).isEqualTo("company")
    }
}
