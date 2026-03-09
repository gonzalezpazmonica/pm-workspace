package com.savia.mobile.ui.screenshot

import androidx.activity.ComponentActivity
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import com.github.takahirom.roborazzi.captureRoboImage
import com.savia.mobile.ui.theme.SaviaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Roborazzi screenshot tests for Savia Mobile UI components.
 *
 * These tests run on JVM (no device needed) and generate PNG screenshots
 * in app/build/outputs/roborazzi/ for visual regression testing.
 *
 * Commands:
 *   Record baselines:   ./gradlew recordRoborazziDebug
 *   Verify no changes:  ./gradlew verifyRoborazziDebug
 *   Compare diffs:      ./gradlew compareRoborazziDebug
 *
 * Note: Full screens with hiltViewModel() cannot be tested directly here.
 * Instead we recreate composable structures with hardcoded state (no DI).
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [33], qualifiers = "w400dp-h800dp-xxhdpi")
class ScreenshotTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    // ------------------------------------------------------------------
    // Settings Screen — Bridge Connected
    // ------------------------------------------------------------------
    @OptIn(ExperimentalMaterial3Api::class)
    @Test
    fun settingsScreen_bridgeConnected() {
        composeTestRule.setContent {
            SaviaTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        TopAppBar(
                            title = { Text("Settings") },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = MaterialTheme.colorScheme.surface
                            )
                        )
                        Column(modifier = Modifier.padding(top = 8.dp)) {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 4.dp),
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer
                                )
                            ) {
                                ListItem(
                                    headlineContent = {
                                        Text("Bridge", style = MaterialTheme.typography.titleMedium)
                                    },
                                    supportingContent = {
                                        Text("Connected to 192.168.1.100:8922",
                                            style = MaterialTheme.typography.bodyMedium)
                                    },
                                    leadingContent = {
                                        Icon(Icons.Default.Cloud, contentDescription = null,
                                            tint = MaterialTheme.colorScheme.primary)
                                    }
                                )
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            SettingsItem(Icons.Default.Person, "Monica Gonzalez", "monica@savia.dev")
                            SettingsItem(Icons.Default.Code, "Git Configuration", "Name, email, PAT")
                            SettingsItem(Icons.Default.Group, "Team", "Manage team members")
                            SettingsItem(Icons.Default.Business, "Company", "Company profile")
                            SettingsItem(Icons.Default.DarkMode, "Theme", "SYSTEM")
                            SettingsItem(Icons.Default.Language, "Language", "SYSTEM")
                            SettingsItem(Icons.Default.Info, "About", "v0.2.14-debug")
                        }
                    }
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage()
    }

    // ------------------------------------------------------------------
    // Settings Screen — Bridge Disconnected
    // ------------------------------------------------------------------
    @OptIn(ExperimentalMaterial3Api::class)
    @Test
    fun settingsScreen_bridgeDisconnected() {
        composeTestRule.setContent {
            SaviaTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        TopAppBar(
                            title = { Text("Settings") },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = MaterialTheme.colorScheme.surface
                            )
                        )
                        Column(modifier = Modifier.padding(top = 8.dp)) {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 4.dp),
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.errorContainer
                                )
                            ) {
                                ListItem(
                                    headlineContent = {
                                        Text("Bridge", style = MaterialTheme.typography.titleMedium)
                                    },
                                    supportingContent = {
                                        Text("Not connected — tap to configure",
                                            style = MaterialTheme.typography.bodyMedium)
                                    },
                                    leadingContent = {
                                        Icon(Icons.Default.Cloud, contentDescription = null,
                                            tint = MaterialTheme.colorScheme.error)
                                    }
                                )
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            SettingsItem(Icons.Default.Person, "Profile", "Tap to load profile")
                            SettingsItem(Icons.Default.Code, "Git Configuration", "Name, email, PAT")
                            SettingsItem(Icons.Default.Group, "Team", "Manage team members")
                            SettingsItem(Icons.Default.Business, "Company", "Company profile")
                            SettingsItem(Icons.Default.DarkMode, "Theme", "SYSTEM")
                            SettingsItem(Icons.Default.Language, "Language", "SYSTEM")
                            SettingsItem(Icons.Default.Info, "About", "v0.2.14-debug")
                        }
                    }
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage()
    }

    // ------------------------------------------------------------------
    // Bridge Setup Form — as Surface (AlertDialog causes idle issues)
    // ------------------------------------------------------------------
    @Test
    fun bridgeSetupForm_empty() {
        composeTestRule.setContent {
            SaviaTheme {
                Surface(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text("Configure Bridge connection",
                            style = MaterialTheme.typography.titleLarge)
                        OutlinedTextField(
                            value = "",
                            onValueChange = {},
                            label = { Text("Host (IP address)") },
                            placeholder = { Text("192.168.x.x") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = "8922",
                            onValueChange = {},
                            label = { Text("Port") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = "",
                            onValueChange = {},
                            label = { Text("Token") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth()) {
                            Text("Connect")
                        }
                    }
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage()
    }

    // ------------------------------------------------------------------
    // Bridge Setup Form — With Error
    // ------------------------------------------------------------------
    @Test
    fun bridgeSetupForm_withError() {
        composeTestRule.setContent {
            SaviaTheme {
                Surface(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text("Configure Bridge connection",
                            style = MaterialTheme.typography.titleLarge)
                        OutlinedTextField(
                            value = "192.168.1.100",
                            onValueChange = {},
                            label = { Text("Host (IP address)") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = "8922",
                            onValueChange = {},
                            label = { Text("Port") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = "my-secret-token",
                            onValueChange = {},
                            label = { Text("Token") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Text(
                            text = "Error: Connection timed out",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error
                        )
                        Button(onClick = {}, modifier = Modifier.fillMaxWidth()) {
                            Text("Connect")
                        }
                    }
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage()
    }

    // ------------------------------------------------------------------
    // Profile Screen — Not Configured (no Bridge)
    // ------------------------------------------------------------------
    @OptIn(ExperimentalMaterial3Api::class)
    @Test
    fun profileScreen_notConfigured() {
        composeTestRule.setContent {
            SaviaTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        TopAppBar(
                            title = { Text("Profile") },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = MaterialTheme.colorScheme.surface
                            )
                        )
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(32.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                Icons.Default.Person,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "Configure Bridge to see your profile",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(onClick = {}, modifier = Modifier.fillMaxWidth()) {
                                Text("Go to Settings")
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Button(onClick = {}, modifier = Modifier.fillMaxWidth()) {
                                Text("Retry")
                            }
                        }
                    }
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage()
    }

    // ------------------------------------------------------------------
    // Helper: reusable settings item (mirrors ClickableSettingsItem)
    // ------------------------------------------------------------------
    @Composable
    private fun SettingsItem(
        icon: ImageVector,
        title: String,
        subtitle: String
    ) {
        ListItem(
            modifier = Modifier.clickable {},
            headlineContent = { Text(title, style = MaterialTheme.typography.titleMedium) },
            supportingContent = {
                Text(subtitle, style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            },
            leadingContent = { Icon(icon, contentDescription = null) }
        )
    }
}
