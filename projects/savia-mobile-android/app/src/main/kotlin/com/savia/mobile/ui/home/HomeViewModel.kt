package com.savia.mobile.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.BoardItem
import com.savia.domain.model.SprintSummary
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Home screen displaying dashboard data.
 *
 * @property greeting Personalized greeting from Bridge (e.g., "Good morning, la usuaria")
 * @property selectedProject Current project name (null if not selected)
 * @property sprintName Name of the active sprint
 * @property sprintProgress Completion progress as decimal 0.0-1.0
 * @property completedStoryPoints Story points completed in sprint
 * @property totalStoryPoints Total story points planned
 * @property blockedItemsCount Number of blocked items
 * @property hoursToday Hours logged today
 * @property myTasks First tasks assigned to current user
 * @property recentActivity Last items from sprint activity
 * @property availableProjects List of available projects to select from
 * @property availableSprints List of available sprints to select from
 * @property isLoading Whether data is currently loading
 * @property error Error message to display in snackbar
 */
data class HomeUiState(
    val greeting: String = "",
    val selectedProject: String? = null,
    val sprintName: String = "Sprint",
    val sprintProgress: Float = 0f,
    val completedStoryPoints: Int = 0,
    val totalStoryPoints: Int = 0,
    val blockedItemsCount: Int = 0,
    val hoursToday: Float = 0f,
    val myTasks: List<BoardItem> = emptyList(),
    val recentActivity: List<String> = emptyList(),
    val availableProjects: List<com.savia.domain.model.Project> = emptyList(),
    val availableSprints: List<String> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

/**
 * ViewModel for Home screen managing dashboard state and data loading.
 *
 * Uses the Bridge GET /dashboard REST endpoint to fetch all Home data
 * in a single call. The Bridge reads project data directly from disk
 * (CLAUDE.md, mock JSON files), making this fast and reliable.
 *
 * Previous approach (DEPRECATED): sent slash commands via /chat endpoint
 * which depended on Claude CLI — fragile and slow.
 *
 * Clean Architecture: ViewModel (UI layer) coordinates with ProjectRepository for data.
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadDashboardData()
    }

    /**
     * Loads all dashboard data from Bridge GET /dashboard endpoint.
     *
     * Single REST call replaces the previous 4 separate chat commands
     * (getProjects, getSprintSummary, getBoard, getTimeEntries).
     */
    private fun loadDashboardData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val dashboard = projectRepository.getDashboard()

                if (dashboard == null) {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = "Could not connect to Bridge"
                        )
                    }
                    return@launch
                }

                // Respect local project selection; fall back to Bridge's default
                val localSelectedId = projectRepository.getSelectedProject()?.id
                val selectedId = localSelectedId ?: dashboard.selectedProjectId
                if (selectedId != null && localSelectedId == null) {
                    projectRepository.setSelectedProject(selectedId)
                }

                val selectedProject = dashboard.projects.find { it.id == selectedId }

                // Generate available sprints from sprint summary
                val availableSprints = generateAvailableSprints(dashboard.sprint)

                _uiState.update {
                    it.copy(
                        greeting = dashboard.greeting,
                        selectedProject = selectedProject?.name ?: selectedId,
                        sprintName = dashboard.sprint?.name ?: "No Active Sprint",
                        sprintProgress = dashboard.sprint?.progress ?: 0f,
                        completedStoryPoints = dashboard.sprint?.completedPoints ?: 0,
                        totalStoryPoints = dashboard.sprint?.totalPoints ?: 0,
                        blockedItemsCount = dashboard.blockedItems,
                        hoursToday = dashboard.hoursToday,
                        myTasks = dashboard.myTasks,
                        recentActivity = dashboard.recentActivity,
                        availableProjects = dashboard.projects,
                        availableSprints = availableSprints,
                        isLoading = false,
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Error loading dashboard"
                    )
                }
            }
        }
    }

    /**
     * Refreshes dashboard data.
     * Called by pull-to-refresh gesture on HomeScreen.
     */
    fun refresh() {
        loadDashboardData()
    }

    /**
     * Clears any error message from state after displaying it.
     * Called by HomeScreen after snackbar shows error.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    /**
     * Selects a project and reloads dashboard data.
     * Called when user selects a project from dropdown menu.
     */
    fun selectProject(projectId: String) {
        viewModelScope.launch {
            // Immediate UI feedback: show selected project name before reload
            val project = _uiState.value.availableProjects.find { it.id == projectId }
            _uiState.update { it.copy(selectedProject = project?.name ?: projectId) }
            projectRepository.setSelectedProject(projectId)
            loadDashboardData()
        }
    }

    /**
     * Selects a sprint and reloads dashboard data.
     * Called when user selects a sprint from dropdown menu.
     *
     * @param sprintName Name of the sprint to select
     */
    fun selectSprint(sprintName: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(sprintName = sprintName) }
            loadDashboardData()
        }
    }

    /**
     * Generates available sprints based on the current sprint summary.
     * Temporary approach: includes current sprint and adjacent sprints (prev/next).
     *
     * @param sprintSummary Current sprint summary
     * @return List of available sprint names
     */
    private fun generateAvailableSprints(sprintSummary: SprintSummary?): List<String> {
        if (sprintSummary == null) return emptyList()

        val sprints = mutableListOf<String>()
        val currentName = sprintSummary.name

        val sprintNumberRegex = """Sprint\s+(\d+)""".toRegex()
        val matchResult = sprintNumberRegex.find(currentName)

        if (matchResult != null) {
            val currentNumber = matchResult.groupValues[1].toIntOrNull() ?: 0
            if (currentNumber > 1) {
                sprints.add("Sprint ${currentNumber - 1}")
            }
        }

        sprints.add(currentName)

        if (matchResult != null) {
            val currentNumber = matchResult.groupValues[1].toIntOrNull() ?: 0
            sprints.add("Sprint ${currentNumber + 1}")
        }

        return sprints
    }
}
