package com.savia.mobile.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.CompanySection
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CompanyProfileUiState(
    val isLoading: Boolean = true,
    val status: String = "not_configured",
    val sections: Map<String, CompanySection> = emptyMap(),
    val message: String? = null
)

@HiltViewModel
class CompanyProfileViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CompanyProfileUiState())
    val uiState: StateFlow<CompanyProfileUiState> = _uiState.asStateFlow()

    init { load() }

    private fun load() {
        viewModelScope.launch {
            val profile = projectRepository.getCompanyProfile()
            if (profile != null) {
                val sections = mutableMapOf<String, CompanySection>()
                profile.identity?.let { sections["identity"] = it }
                profile.structure?.let { sections["structure"] = it }
                profile.strategy?.let { sections["strategy"] = it }
                profile.policies?.let { sections["policies"] = it }
                profile.technology?.let { sections["technology"] = it }
                profile.vertical?.let { sections["vertical"] = it }
                _uiState.update {
                    it.copy(isLoading = false, status = profile.status, sections = sections)
                }
            } else {
                _uiState.update { it.copy(isLoading = false) }
            }
        }
    }

    fun clearMessage() { _uiState.update { it.copy(message = null) } }

    fun updateSection(sectionKey: String, fields: Map<String, String>, content: String) {
        viewModelScope.launch {
            val success = projectRepository.updateCompanySection(sectionKey, fields, content)
            _uiState.update {
                it.copy(message = if (success) "Section updated" else "Error updating section")
            }
            if (success) load()
        }
    }
}
