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
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
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
    val updateDownloadProgress: Float = 0f,
    val updateDownloaded: Boolean = false,
    val pendingUpdate: AppUpdate? = null
)

/**
 * One-shot events from ViewModel to UI (for intents that need Activity context).
 */
sealed class ProfileEvent {
    data class InstallApk(val apkPath: String) : ProfileEvent()
}

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

    private val _events = MutableSharedFlow<ProfileEvent>()
    val events: SharedFlow<ProfileEvent> = _events.asSharedFlow()

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
                withTimeout(20_000) {
                    // Load getUserProfile and getProjects in parallel
                    val profileDeferred = async(Dispatchers.IO) {
                        projectRepository.getUserProfile()
                    }
                    val projectsDeferred = async(Dispatchers.IO) {
                        projectRepository.getProjects()
                    }

                    // Wait for both to complete
                    val userProfile = profileDeferred.await()
                    val projects = projectsDeferred.await()

                    // Load selected project sequentially (depends on projects list)
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
            _uiState.update {
                it.copy(
                    updateCheckingUpdate = true,
                    updateAvailable = false,
                    updateDownloaded = false,
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
                        error = e.message ?: "Error checking for updates"
                    )
                }
            }
        }
    }

    /**
     * Downloads available app update APK from the Bridge and triggers install.
     */
    fun downloadAndInstallUpdate() {
        val update = _uiState.value.pendingUpdate ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(updateDownloading = true, updateDownloadProgress = 0f) }
            try {
                updateRepository.downloadUpdate(update).collect { progress ->
                    _uiState.update { it.copy(updateDownloadProgress = progress) }
                }
                // Download complete — get path and trigger install
                val apkPath = withContext(Dispatchers.IO) {
                    updateRepository.getDownloadedApkPath()
                }
                _uiState.update {
                    it.copy(
                        updateDownloading = false,
                        updateDownloaded = true,
                        updateDownloadProgress = 1f
                    )
                }
                if (apkPath != null) {
                    _events.emit(ProfileEvent.InstallApk(apkPath))
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
     * Triggers install of already-downloaded APK.
     */
    fun installDownloadedUpdate() {
        viewModelScope.launch {
            val apkPath = withContext(Dispatchers.IO) {
                updateRepository.getDownloadedApkPath()
            }
            if (apkPath != null) {
                _events.emit(ProfileEvent.InstallApk(apkPath))
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
