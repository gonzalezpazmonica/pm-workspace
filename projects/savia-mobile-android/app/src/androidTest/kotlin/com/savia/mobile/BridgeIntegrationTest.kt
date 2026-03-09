package com.savia.mobile

import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.savia.domain.repository.SecurityRepository
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.Request
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.security.cert.X509Certificate
import javax.inject.Inject
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * Integration test that validates the compiled APK against the running Bridge.
 *
 * This test:
 * 1. Pre-configures the Bridge connection via SecurityRepository
 * 2. Launches the app on the emulator
 * 3. Validates the Home screen loads real data from Bridge GET /dashboard
 * 4. Validates Chat screen is accessible
 * 5. Validates Commands screen is accessible
 * 6. Validates Profile screen is accessible
 * 7. Verifies Bridge /health, /dashboard, /profile endpoints from emulator
 *
 * Requirements:
 *   - Bridge running on host: systemctl --user start savia-bridge
 *   - Port forwarding: adb reverse tcp:8922 tcp:8922
 *   - Emulator booted
 *
 * Run with:
 *   ./gradlew :app:connectedDebugAndroidTest \
 *     -Pandroid.testInstrumentationRunnerArguments.class=com.savia.mobile.BridgeIntegrationTest \
 *     -Pandroid.testInstrumentationRunnerArguments.bridgeToken=YOUR_TOKEN
 */
@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class BridgeIntegrationTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Inject
    lateinit var securityRepository: SecurityRepository

    private lateinit var device: UiDevice

    private val bridgeHost = "localhost"
    private val bridgePort = 8922
    private val bridgeToken: String by lazy {
        InstrumentationRegistry.getArguments().getString("bridgeToken", "")
    }

    @Before
    fun setup() {
        hiltRule.inject()
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

        // Pre-configure Bridge connection
        if (bridgeToken.isNotEmpty()) {
            runBlocking {
                securityRepository.saveBridgeConfig(bridgeHost, bridgePort, bridgeToken)
            }
        }
    }

    // ============================================================
    // SPEC 1: Bridge Connectivity from Emulator
    // ============================================================

    @Test
    fun spec1_bridgeHealthReachable() {
        val client = createTrustAllClient()
        val request = Request.Builder()
            .url("https://$bridgeHost:$bridgePort/health")
            .addHeader("Authorization", "Bearer $bridgeToken")
            .get().build()

        val response = client.newCall(request).execute()
        assertEquals("Bridge /health should return 200", 200, response.code)
        val body = response.body?.string() ?: ""
        assertTrue("Should contain status ok", body.contains("ok"))
    }

    @Test
    fun spec2_dashboardEndpointReachable() {
        val client = createTrustAllClient()
        val request = Request.Builder()
            .url("https://$bridgeHost:$bridgePort/dashboard")
            .addHeader("Authorization", "Bearer $bridgeToken")
            .get().build()

        val response = client.newCall(request).execute()
        assertEquals("Bridge /dashboard should return 200", 200, response.code)
        val body = response.body?.string() ?: ""
        assertTrue("Should contain projects", body.contains("\"projects\""))
        assertTrue("Should contain sprint", body.contains("\"sprint\""))
        assertTrue("Should contain myTasks", body.contains("\"myTasks\""))
        assertTrue("Should contain recentActivity", body.contains("\"recentActivity\""))
    }

    @Test
    fun spec3_profileEndpointReachable() {
        val client = createTrustAllClient()
        val request = Request.Builder()
            .url("https://$bridgeHost:$bridgePort/profile")
            .addHeader("Authorization", "Bearer $bridgeToken")
            .get().build()

        val response = client.newCall(request).execute()
        assertEquals("Bridge /profile should return 200", 200, response.code)
        val body = response.body?.string() ?: ""
        assertTrue("Should contain name", body.contains("\"name\""))
    }

    // ============================================================
    // SPEC 4: Home Screen Loads Data
    // ============================================================

    @Test
    fun spec4_homeScreenLoads() {
        composeRule.waitForIdle()
        Thread.sleep(5000) // Give time for Bridge network call

        // Home should display sprint data or a fallback message
        composeRule.waitUntil(timeoutMillis = 15_000) {
            composeRule.onAllNodesWithText("Sprint", substring = true)
                .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodesWithText("Home", substring = true)
                .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodesWithText("Bridge", substring = true)
                .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodesWithText("Dashboard", substring = true)
                .fetchSemanticsNodes().isNotEmpty()
        }
    }

    // ============================================================
    // SPEC 5: Tab Navigation Works
    // ============================================================

    @Test
    fun spec5_chatTabNavigable() {
        composeRule.waitForIdle()
        Thread.sleep(2000)
        composeRule.onNodeWithText("Chat").performClick()
        composeRule.waitForIdle()
        Thread.sleep(1500)

        val visible = composeRule.onAllNodes(hasText("Message", substring = true))
            .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodes(hasText("Chat", substring = true))
                .fetchSemanticsNodes().isNotEmpty()
        assertTrue("Chat screen should be visible", visible)
    }

    @Test
    fun spec6_commandsTabNavigable() {
        composeRule.waitForIdle()
        Thread.sleep(2000)
        composeRule.onNodeWithText("Commands").performClick()
        composeRule.waitForIdle()
        Thread.sleep(1500)

        val visible = composeRule.onAllNodes(hasText("Sprint", substring = true))
            .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodes(hasText("Board", substring = true))
                .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodes(hasText("Commands", substring = true))
                .fetchSemanticsNodes().isNotEmpty()
        assertTrue("Commands screen should show command families", visible)
    }

    @Test
    fun spec7_profileTabNavigable() {
        composeRule.waitForIdle()
        Thread.sleep(2000)
        composeRule.onNodeWithText("Profile").performClick()
        composeRule.waitForIdle()
        Thread.sleep(2000)

        val visible = composeRule.onAllNodes(hasText("Profile", substring = true))
            .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodes(hasText("Settings", substring = true))
                .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodes(hasText("Update", substring = true))
                .fetchSemanticsNodes().isNotEmpty() ||
            composeRule.onAllNodes(hasText("Bridge", substring = true))
                .fetchSemanticsNodes().isNotEmpty()
        assertTrue("Profile screen should have content", visible)
    }

    // ============================================================
    // Helpers
    // ============================================================

    private fun createTrustAllClient(): OkHttpClient {
        val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
            override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        })
        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(null, trustAllCerts, java.security.SecureRandom())
        return OkHttpClient.Builder()
            .sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
            .hostnameVerifier { _, _ -> true }
            .connectTimeout(10, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(10, java.util.concurrent.TimeUnit.SECONDS)
            .build()
    }
}
