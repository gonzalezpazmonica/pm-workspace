package com.savia.mobile.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.AppUpdate
import com.savia.domain.model.Project
import com.savia.domain.model.UserProfile
import com.savia.domain.repository.ProjectRepository
import com.savia.domain.repository.UpdateRepository
import com.savia.mobile.BuildConfig
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * UI state for the Profile screen displaying user and project information.
 */
data class ProfileUiState(
    val userProfile: UserProfile? = null,
    val projects: List<Project> = emptyList(),
    val selectedProjectId: String? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val updateCheckingUpdate: Boolean = false,
    val updateAvailable: Boolean = false,
    val updateDownloading: Boolean = false,
    val pendingUpdate: AppUpdate? = null
)

/**
 * ViewModel for Profile screen managing user profile, project selection, and updates.
 *
 * Clean Architecture: ViewModel (UI layer) coordinates with repositories.
 */
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val projectRepository: ProjectRepository,
    private val updateRepository: UpdateRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        loadProfileData()
    }

    /**
     * Loads user profile and list of projects.
     */
    fun loadProfileData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val userProfile = withContext(Dispatchers.IO) {
                    projectRepository.getUserProfile()
                }
                val projects = withContext(Dispatchers.IO) {
                    projectRepository.getProjects()
                }
                val selectedProject = withContext(Dispatchers.IO) {
                    projectRepository.getSelectedProject()
                }

                _uiState.update {
                    it.copy(
                        userProfile = userProfile,
                        projects = projects,
                        selectedProjectId = selectedProject?.id,
                        isLoading = false,
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Error loading profile"
                    )
                }
            }
        }
    }

    /**
     * Sets the active project for the user.
     */
    fun selectProject(projectId: String) {
        viewModelScope.launch {
            try {
                projectRepository.setSelectedProject(projectId)
                _uiState.update { it.copy(selectedProjectId = projectId) }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(error = e.message ?: "Error selecting project")
                }
            }
        }
    }

    /**
     * Checks for app updates via the Bridge /update/check endpoint.
     */
    fun checkForUpdates() {
        viewModelScope.launch {
            _uiState.update { it.copy(updateCheckingUpdate = true) }
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
                        error = e.message ?: "Error checking for updates"
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
            _uiState.update { it.copy(updateDownloading = true) }
            try {
                updateRepository.downloadUpdate(update).collect { /* progress */ }
                _uiState.update {
                    it.copy(updateDownloading = false)
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        updateDownloading = false,
                        error = e.message ?: "Error downloading update"
                    )
                }
            }
        }
    }

    /**
     * Clears any error message from state.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
