package com.savia.mobile.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.repository.SecurityRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Settings screen displaying Bridge connection status.
 *
 * @property isBridgeConnected whether Bridge is currently configured
 * @property bridgeHost hostname or IP of the Bridge server
 * @property bridgePort port number of the Bridge server
 */
data class SettingsUiState(
    val isBridgeConnected: Boolean = false,
    val bridgeHost: String = "",
    val bridgePort: Int = 0
)

/**
 * ViewModel for Settings screen managing Bridge connection status.
 *
 * Responsibilities:
 * - Load and display Bridge connection configuration
 * - Handle Bridge disconnection with confirmation
 * - Manage Bridge-related state in SecurityRepository
 *
 * Data flow:
 * Init → loadBridgeStatus() → SecurityRepository → _uiState → SettingsScreen
 * User taps disconnect → disconnectBridge() → SecurityRepository.delete → clear state
 *
 * Clean Architecture: ViewModel (UI layer) interfaces with repository for secure storage
 * Security: All Bridge credentials stored encrypted via EncryptedSharedPreferences
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val securityRepository: SecurityRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for Bridge connection status.
     * Updated by loadBridgeStatus and disconnectBridge methods.
     */
    private val _uiState = MutableStateFlow(SettingsUiState())

    /**
     * Observable Bridge connection state for SettingsScreen.
     * Exposed as StateFlow for lifecycle-aware collection.
     */
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        loadBridgeStatus()
    }

    /**
     * Loads current Bridge configuration from secure storage.
     * Called on ViewModel initialization to populate UI.
     * If no Bridge is configured, state shows disconnected with empty host/port.
     * Runs in viewModelScope to ensure lifecycle awareness.
     */
    private fun loadBridgeStatus() {
        viewModelScope.launch {
            val connected = securityRepository.hasBridgeConfig()
            val host = securityRepository.getBridgeHost() ?: ""
            val port = securityRepository.getBridgePort() ?: 0
            _uiState.update {
                it.copy(
                    isBridgeConnected = connected,
                    bridgeHost = host,
                    bridgePort = port
                )
            }
        }
    }

    /**
     * Disconnects Bridge and clears all Bridge-related data.
     *
     * Clears:
     * - Bridge host, port, and auth token
     * - Last active conversation ID (forces restart on reconnect)
     * - Updates UI state to show disconnected status
     *
     * Called when user confirms Bridge disconnection from dialog.
     * All data is cleared permanently (data persisted in EncryptedSharedPreferences is deleted).
     */
    fun disconnectBridge() {
        viewModelScope.launch {
            securityRepository.deleteBridgeConfig()
            securityRepository.clearLastConversationId()
            _uiState.update {
                it.copy(
                    isBridgeConnected = false,
                    bridgeHost = "",
                    bridgePort = 0
                )
            }
        }
    }
}
