package com.savia.mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.savia.mobile.notification.SaviaNotificationManager
import com.savia.mobile.ui.AppStartupViewModel
import com.savia.mobile.ui.navigation.SaviaNavHost
import com.savia.mobile.ui.settings.BridgeSetupDialog
import com.savia.mobile.ui.theme.SaviaTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * Main activity for Savia Mobile application.
 *
 * Serves as the single Activity container for the entire Jetpack Compose UI.
 * Handles:
 * - Splash screen initialization and animation
 * - Edge-to-edge display (no status bar/navigation bar insets)
 * - Theme application (violet/mauve Material 3 color scheme)
 * - Navigation setup via SaviaNavHost (bottom navigation with Chat, Sessions, Settings tabs)
 * - Startup validation: checks bridge configuration and guides setup if needed
 *
 * All ViewModels and repositories are injected via Hilt @AndroidEntryPoint.
 * The UI is fully built with Jetpack Compose and rendered into the Compose surface.
 *
 * @author Savia Mobile Team
 */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val appStartupViewModel: AppStartupViewModel by viewModels()

    @Inject
    lateinit var notificationManager: SaviaNotificationManager

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { /* granted or denied — no action needed, just registers the response */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        requestNotificationPermissionIfNeeded()
        setContent {
            SaviaTheme {
                val startupState by appStartupViewModel.state.collectAsState()

                when {
                    startupState.isChecking -> {
                        // Keep splash screen visible while checking
                    }
                    startupState.needsBridgeSetup -> {
                        BridgeSetupDialog(
                            onDismiss = { appStartupViewModel.skipSetup() },
                            onConnected = { appStartupViewModel.onBridgeSetupComplete() }
                        )
                    }
                    startupState.isReady -> {
                        SaviaNavHost()
                    }
                }
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}
