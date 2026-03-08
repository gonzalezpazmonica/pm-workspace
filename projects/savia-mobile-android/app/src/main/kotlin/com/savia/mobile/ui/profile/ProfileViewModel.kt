package com.savia.mobile.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.Project
import com.savia.domain.model.UserProfile
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Profile screen displaying user and project information.
 *
 * @property userProfile Current user's profile with name, email, role, stats
 * @property projects List of all active projects user is involved in
 * @property selectedProjectId Currently selected project ID
 * @property isLoading Whether data is currently loading
 * @property error Error message to display
 * @property updateCheckingUpdate Whether app is checking for updates
 * @property updateAvailable Whether new app version is available
 * @property updateDownloading Whether update is being downloaded
 */
data class ProfileUiState(
    val userProfile: UserProfile? = null,
    val projects: List<Project> = emptyList(),
    val selectedProjectId: String? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val updateCheckingUpdate: Boolean = false,
    val updateAvailable: Boolean = false,
    val updateDownloading: Boolean = false
)

/**
 * ViewModel for Profile screen managing user profile and project selection.
 *
 * Responsibilities:
 * - Load user profile from ProjectRepository
 * - Load list of active projects
 * - Handle project selection
 * - Manage update checking (integrates with UpdateManager)
 * - Display user statistics
 *
 * Clean Architecture: ViewModel (UI layer) coordinates with ProjectRepository
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for Profile screen.
     * Updated as profile data loads and user interacts.
     */
    private val _uiState = MutableStateFlow(ProfileUiState())

    /**
     * Public observable state for ProfileScreen to collect and recompose on changes.
     * Exposed as StateFlow for lifecycle-aware collection.
     */
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        loadProfileData()
    }

    /**
     * Loads user profile and list of projects.
     * Called on ViewModel initialization.
     */
    private fun loadProfileData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val userProfile = projectRepository.getUserProfile()
                val projects = projectRepository.getProjects()
                val selectedProject = projectRepository.getSelectedProject()

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
     *
     * @param projectId ID of project to select
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
     * Triggers a check for app updates.
     * In a real implementation, would call UpdateManager.checkForUpdates().
     */
    fun checkForUpdates() {
        viewModelScope.launch {
            _uiState.update { it.copy(updateCheckingUpdate = true) }
            try {
                // TODO: Call UpdateManager.checkForUpdates()
                // For now, simulate checking
                kotlinx.coroutines.delay(500)
                _uiState.update {
                    it.copy(
                        updateCheckingUpdate = false,
                        updateAvailable = false  // Example: no update available
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
     * Downloads available app update.
     * In a real implementation, would call UpdateManager.downloadUpdate().
     */
    fun downloadUpdate() {
        viewModelScope.launch {
            _uiState.update { it.copy(updateDownloading = true) }
            try {
                // TODO: Call UpdateManager.downloadUpdate()
                // For now, simulate downloading
                kotlinx.coroutines.delay(2000)
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
     * Called by ProfileScreen after showing error.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
