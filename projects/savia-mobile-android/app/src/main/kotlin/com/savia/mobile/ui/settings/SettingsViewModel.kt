package com.savia.mobile.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.repository.ProjectRepository
import com.savia.domain.repository.SecurityRepository
import com.savia.mobile.ui.settings.AppLanguage
import com.savia.mobile.ui.settings.AppTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

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
    val appVersion: String = ""
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
    private val projectRepository: ProjectRepository
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
                    appVersion = "0.2.0"
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
}
