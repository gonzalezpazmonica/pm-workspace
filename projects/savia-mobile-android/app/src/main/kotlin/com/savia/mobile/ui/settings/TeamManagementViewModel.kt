package com.savia.mobile.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.TeamMember
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TeamManagementUiState(
    val isLoading: Boolean = true,
    val members: List<TeamMember> = emptyList(),
    val message: String? = null
)

@HiltViewModel
class TeamManagementViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TeamManagementUiState())
    val uiState: StateFlow<TeamManagementUiState> = _uiState.asStateFlow()

    init { load() }

    private fun load() {
        viewModelScope.launch {
            val members = projectRepository.getTeamMembers()
            _uiState.update { it.copy(isLoading = false, members = members) }
        }
    }

    fun clearMessage() { _uiState.update { it.copy(message = null) } }

    fun addMember(name: String, role: String, email: String) {
        viewModelScope.launch {
            val slug = name.lowercase().replace(" ", "-").replace(Regex("[^a-z0-9-]"), "")
            val identity = mapOf("name" to name, "role" to role, "email" to email)
                .filterValues { it.isNotBlank() }
            val success = projectRepository.addTeamMember(slug, identity)
            _uiState.update {
                it.copy(message = if (success) "Member added" else "Error adding member")
            }
            if (success) load()
        }
    }

    fun updateMember(slug: String, name: String, role: String, email: String) {
        viewModelScope.launch {
            val identity = mapOf("name" to name, "role" to role, "email" to email)
                .filterValues { it.isNotBlank() }
            val success = projectRepository.updateTeamMember(slug, identity)
            _uiState.update {
                it.copy(message = if (success) "Member updated" else "Error updating member")
            }
            if (success) load()
        }
    }

    fun removeMember(slug: String) {
        viewModelScope.launch {
            val success = projectRepository.removeTeamMember(slug)
            _uiState.update {
                it.copy(message = if (success) "Member removed" else "Error removing member")
            }
            if (success) load()
        }
    }
}
