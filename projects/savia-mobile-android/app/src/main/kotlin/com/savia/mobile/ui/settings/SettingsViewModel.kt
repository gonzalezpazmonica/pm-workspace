package com.savia.mobile.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.data.api.SaviaBridgeService
import com.savia.domain.repository.ProjectRepository
import com.savia.domain.repository.SecurityRepository
import com.savia.domain.repository.UpdateRepository
import com.savia.mobile.BuildConfig
import com.savia.mobile.ui.settings.AppLanguage
import com.savia.mobile.ui.settings.AppTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import javax.inject.Inject
import javax.inject.Named

/**
 * UI state for the Settings screen displaying Bridge connection status and user preferences.
 *
 * @property isBridgeConnected whether Bridge is currently configured
 * @property bridgeHost hostname or IP of the Bridge server
 * @property bridgePort port number of the Bridge server
 * @property userName user's name from profile
 * @property userEmail user's email from profile
 * @property currentTheme selected theme (System/Light/Dark)
 * @property currentLanguage selected language (System/ES/EN)
 * @property bridgeVersion version of Bridge service
 * @property appVersion version of the app
 */
data class SettingsUiState(
    val isBridgeConnected: Boolean = false,
    val bridgeHost: String = "",
    val bridgePort: Int = 0,
    val userName: String = "",
    val userEmail: String = "",
    val currentTheme: AppTheme = AppTheme.SYSTEM,
    val currentLanguage: AppLanguage = AppLanguage.SYSTEM,
    val bridgeVersion: String = "",
    val appVersion: String = "",
    val isConnecting: Boolean = false,
    val connectionError: String? = null,
    val updateCheckingUpdate: Boolean = false,
    val updateAvailable: Boolean = false,
    val updateDownloading: Boolean = false,
    val updateDownloadProgress: Float = 0f,
    val pendingUpdate: com.savia.domain.model.AppUpdate? = null
)

/**
 * ViewModel for Settings screen managing Bridge connection status and user preferences.
 *
 * Responsibilities:
 * - Load and display Bridge connection configuration
 * - Load user profile from Bridge
 * - Handle Bridge disconnection with confirmation
 * - Manage theme and language preferences
 * - Display app version information
 *
 * Clean Architecture: ViewModel (UI layer) coordinates with repositories
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val securityRepository: SecurityRepository,
    private val projectRepository: ProjectRepository,
    private val updateRepository: UpdateRepository,
    private val bridgeService: SaviaBridgeService,
    @Named("bridge") private val bridgeClient: OkHttpClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        loadSettings()
    }

    /**
     * Loads all settings: Bridge status, user profile, and preferences.
     */
    private fun loadSettings() {
        viewModelScope.launch {
            val connected = securityRepository.hasBridgeConfig()
            val host = securityRepository.getBridgeHost() ?: ""
            val port = securityRepository.getBridgePort() ?: 0

            val profile = projectRepository.getUserProfile()

            _uiState.update {
                it.copy(
                    isBridgeConnected = connected,
                    bridgeHost = host,
                    bridgePort = port,
                    userName = profile?.name ?: "",
                    userEmail = profile?.email ?: "",
                    appVersion = BuildConfig.VERSION_NAME
                )
            }
        }
    }

    /**
     * Changes the app theme and persists to secure storage.
     */
    fun changeTheme(theme: AppTheme) {
        viewModelScope.launch {
            securityRepository.saveTheme(theme.toString())
            _uiState.update { it.copy(currentTheme = theme) }
        }
    }

    /**
     * Changes the app language and persists to secure storage.
     */
    fun changeLanguage(language: AppLanguage) {
        viewModelScope.launch {
            securityRepository.saveLanguage(language.toString())
            _uiState.update { it.copy(currentLanguage = language) }
        }
    }

    /**
     * Disconnects Bridge and clears all Bridge-related data.
     */
    fun disconnectBridge() {
        viewModelScope.launch {
            securityRepository.deleteBridgeConfig()
            securityRepository.clearLastConversationId()
            _uiState.update {
                it.copy(
                    isBridgeConnected = false,
                    bridgeHost = "",
                    bridgePort = 0,
                    userName = "",
                    userEmail = ""
                )
            }
        }
    }

    /**
     * Saves Bridge configuration, performs health check, and registers the user.
     *
     * Flow:
     * 1. Save host/port/token (master token) to secure storage
     * 2. Health check — verify bridge is reachable
     * 3. Register user via POST /auth/register with master token + username
     * 4. On success, replace stored token with the per-user token
     *
     * @param host Bridge server hostname or IP address
     * @param port Bridge server port (1-65535)
     * @param token Master authentication token for the Bridge
     * @param username Username slug for multi-user session registration
     */
    fun saveBridgeConfig(host: String, port: Int, token: String, username: String = "") {
        viewModelScope.launch {
            _uiState.update { it.copy(isConnecting = true, connectionError = null) }

            try {
                val bridgeUrl = "https://$host:$port"

                // Save initial config with master token
                securityRepository.saveBridgeConfig(host, port, token, username)

                // Perform health check on IO dispatcher
                val healthError = withContext(Dispatchers.IO) {
                    val request = okhttp3.Request.Builder()
                        .url("$bridgeUrl/health")
                        .addHeader("Authorization", "Bearer $token")
                        .get()
                        .build()
                    bridgeClient.newCall(request).execute().use { resp ->
                        if (resp.isSuccessful) null else "Bridge returned status ${resp.code}"
                    }
                }

                if (healthError != null) {
                    _uiState.update { it.copy(isConnecting = false, connectionError = healthError) }
                    return@launch
                }

                // Register user and obtain per-user token
                if (username.isNotEmpty()) {
                    val userToken = withContext(Dispatchers.IO) {
                        bridgeService.registerUser(bridgeUrl, token, username)
                    }
                    if (userToken != null) {
                        // Replace master token with per-user token
                        securityRepository.saveBridgeConfig(host, port, userToken, username)
                    }
                }

                _uiState.update {
                    it.copy(
                        isBridgeConnected = true,
                        bridgeHost = host,
                        bridgePort = port,
                        isConnecting = false,
                        connectionError = null
                    )
                }
            } catch (e: Exception) {
                val errorMsg = when {
                    e is android.os.NetworkOnMainThreadException -> "Network threading error"
                    e.message.isNullOrBlank() -> "Connection failed: ${e.javaClass.simpleName}"
                    else -> e.message!!
                }
                _uiState.update { it.copy(isConnecting = false, connectionError = errorMsg) }
            }
        }
    }

    /**
     * Refreshes the user profile from the Bridge.
     *
     * Fetches the latest user profile information from the ProjectRepository
     * and updates the userName and userEmail in the UI state.
     */
    fun refreshProfile() {
        viewModelScope.launch {
            val profile = projectRepository.getUserProfile()
            _uiState.update {
                it.copy(
                    userName = profile?.name ?: "",
                    userEmail = profile?.email ?: ""
                )
            }
        }
    }

    /**
     * Checks for app updates via the Bridge /update/check endpoint.
     */
    fun checkForUpdates() {
        viewModelScope.launch {
            _uiState.update {
                it.copy(
                    updateCheckingUpdate = true,
                    updateAvailable = false,
                    updateDownloading = false,
                    updateDownloadProgress = 0f,
                    pendingUpdate = null
                )
            }
            try {
                val currentVersionCode = BuildConfig.VERSION_CODE
                val update = withContext(Dispatchers.IO) {
                    updateRepository.checkForUpdate(currentVersionCode)
                }
                _uiState.update {
                    it.copy(
                        updateCheckingUpdate = false,
                        updateAvailable = update != null,
                        pendingUpdate = update
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        updateCheckingUpdate = false,
                        connectionError = e.message ?: "Error checking for updates"
                    )
                }
            }
        }
    }

    /**
     * Downloads available app update APK from the Bridge.
     */
    fun downloadUpdate() {
        val update = _uiState.value.pendingUpdate ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(updateDownloading = true, updateDownloadProgress = 0f) }
            try {
                updateRepository.downloadUpdate(update).collect { progress ->
                    _uiState.update { it.copy(updateDownloadProgress = progress) }
                }
                _uiState.update {
                    it.copy(updateDownloading = false, updateDownloadProgress = 1f)
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        updateDownloading = false,
                        updateDownloadProgress = 0f,
                        connectionError = e.message ?: "Error downloading update"
                    )
                }
            }
        }
    }

    /**
     * Clears any connection error message from the UI state.
     *
     * Called when the user dismisses the error or attempts to connect again.
     */
    fun clearConnectionError() {
        _uiState.update { it.copy(connectionError = null) }
    }
}
