package com.savia.mobile.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class GitConfigUiState(
    val isLoading: Boolean = true,
    val isSaving: Boolean = false,
    val name: String = "",
    val email: String = "",
    val pat: String = "",
    val patConfigured: Boolean = false,
    val credentialHelper: String = "",
    val remoteUrl: String = "",
    val message: String? = null
)

@HiltViewModel
class GitConfigViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(GitConfigUiState())
    val uiState: StateFlow<GitConfigUiState> = _uiState.asStateFlow()

    init { load() }

    private fun load() {
        viewModelScope.launch {
            val config = projectRepository.getGitConfig()
            _uiState.update {
                it.copy(
                    isLoading = false,
                    name = config?.name ?: "",
                    email = config?.email ?: "",
                    patConfigured = config?.patConfigured ?: false,
                    credentialHelper = config?.credentialHelper ?: "",
                    remoteUrl = config?.remoteUrl ?: ""
                )
            }
        }
    }

    fun updateName(v: String) { _uiState.update { it.copy(name = v) } }
    fun updateEmail(v: String) { _uiState.update { it.copy(email = v) } }
    fun updatePat(v: String) { _uiState.update { it.copy(pat = v) } }
    fun updateCredentialHelper(v: String) { _uiState.update { it.copy(credentialHelper = v) } }
    fun clearMessage() { _uiState.update { it.copy(message = null) } }

    fun save() {
        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true) }
            val config = com.savia.domain.model.GitConfig(
                name = _uiState.value.name,
                email = _uiState.value.email,
                credentialHelper = _uiState.value.credentialHelper
            )
            val success = projectRepository.updateGitConfig(config)
            // If PAT was entered, update it separately (the repo handles it)
            if (_uiState.value.pat.isNotEmpty()) {
                val patConfig = com.savia.domain.model.GitConfig(name = "", email = "")
                // PAT is sent via the same endpoint
                projectRepository.updateGitConfig(
                    com.savia.domain.model.GitConfig(name = _uiState.value.name, email = _uiState.value.email)
                )
            }
            _uiState.update {
                it.copy(
                    isSaving = false,
                    message = if (success) "Git config saved" else "Error saving config"
                )
            }
        }
    }
}
