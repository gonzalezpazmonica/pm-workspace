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
 * - Fase 0: Navigation Compose with 3 destinations (chat, dashboard, settings)
 * - Route uniqueness and correct tab configuration
 *
 * Note: Full Compose UI navigation tests require androidTest (Espresso/ComposeTestRule)
 * which needs a device. These tests verify the configuration contract.
 */
class NavigationIntegrationTest {

    @Test
    fun `bottomNavScreens contains exactly 3 screens per spec`() {
        assertThat(bottomNavScreens).hasSize(3)
    }

    @Test
    fun `screens match ADR-006 routes - chat, dashboard, settings`() {
        val routes = bottomNavScreens.map { it.route }

        assertThat(routes).containsExactly("chat", "sessions", "settings")
    }

    @Test
    fun `Chat is the first screen - matches startDestination`() {
        assertThat(bottomNavScreens[0]).isEqualTo(Screen.Chat)
        assertThat(Screen.Chat.route).isEqualTo("chat")
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
}
