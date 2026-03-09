package com.savia.mobile.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.repository.SecurityRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Locale
import javax.inject.Inject

data class AppStartupState(
    val isChecking: Boolean = true,
    val needsBridgeSetup: Boolean = false,
    val isReady: Boolean = false
)

@HiltViewModel
class AppStartupViewModel @Inject constructor(
    private val securityRepository: SecurityRepository
) : ViewModel() {

    private val _state = MutableStateFlow(AppStartupState())
    val state: StateFlow<AppStartupState> = _state.asStateFlow()

    init {
        checkStartupState()
    }

    private fun checkStartupState() {
        viewModelScope.launch {
            // Check if bridge config exists
            val hasBridgeConfig = securityRepository.hasBridgeConfig()

            // Detect and save language if not already set
            val currentLanguage = securityRepository.getLanguage()
            if (currentLanguage == null) {
                val detectedLanguage = detectLanguage()
                securityRepository.saveLanguage(detectedLanguage)
            }

            // Update state based on bridge config
            _state.value = if (hasBridgeConfig) {
                AppStartupState(
                    isChecking = false,
                    needsBridgeSetup = false,
                    isReady = true
                )
            } else {
                AppStartupState(
                    isChecking = false,
                    needsBridgeSetup = true,
                    isReady = false
                )
            }
        }
    }

    private fun detectLanguage(): String {
        val languageCode = Locale.getDefault().language
        return when (languageCode) {
            "es" -> "ES"
            else -> "EN"
        }
    }

    fun onBridgeSetupComplete() {
        _state.value = AppStartupState(
            isChecking = false,
            needsBridgeSetup = false,
            isReady = true
        )
    }

    fun skipSetup() {
        _state.value = AppStartupState(
            isChecking = false,
            needsBridgeSetup = false,
            isReady = true
        )
    }
}
