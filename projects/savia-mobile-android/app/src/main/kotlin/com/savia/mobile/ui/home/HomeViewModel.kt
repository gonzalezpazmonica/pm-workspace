package com.savia.mobile.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.BoardItem
import com.savia.domain.model.SprintSummary
import com.savia.domain.model.TimeEntry
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
 * @property selectedProject Current project name (null if not selected)
 * @property sprintName Name of the active sprint
 * @property sprintProgress Completion progress as decimal 0.0-1.0
 * @property completedStoryPoints Story points completed in sprint
 * @property totalStoryPoints Total story points planned
 * @property blockedItemsCount Number of blocked items
 * @property hoursToday Hours logged today
 * @property myTasks First 3 items from board assigned to current user
 * @property recentActivity Last 5 items from sprint activity
 * @property availableProjects List of available projects to select from
 * @property availableSprints List of available sprints to select from
 * @property isLoading Whether data is currently loading
 * @property error Error message to display in snackbar
 */
data class HomeUiState(
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
 * Responsibilities:
 * - Load selected project and sprint summary
 * - Load user's tasks for today
 * - Load time entries for today
 * - Load recent activity
 * - Handle refresh action for pull-to-refresh
 * - Display loading and error states
 *
 * Clean Architecture: ViewModel (UI layer) coordinates with ProjectRepository for data
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for Home screen.
     * Updated by all ViewModel methods as data loads.
     */
    private val _uiState = MutableStateFlow(HomeUiState())

    /**
     * Public observable state for HomeScreen to collect and recompose on changes.
     * Exposed as StateFlow for lifecycle-aware collection.
     */
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadDashboardData()
    }

    /**
     * Loads all dashboard data: projects, sprint summary, tasks, and activity.
     * Called on ViewModel initialization and during refresh.
     */
    private fun loadDashboardData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                // Load available projects
                val projects = projectRepository.getProjects()
                var selectedProject = projectRepository.getSelectedProject()

                // Auto-select project if none selected
                if (selectedProject == null) {
                    if (projects.isEmpty()) {
                        // No projects available - show error and return
                        _uiState.update {
                            it.copy(
                                isLoading = false,
                                availableProjects = projects,
                                error = "No projects available"
                            )
                        }
                        return@launch
                    }

                    // Try to find PM-Workspace project
                    selectedProject = projects.find { project ->
                        project.name.contains("PM-Workspace", ignoreCase = true) ||
                        project.id.contains("pm-workspace", ignoreCase = true)
                    }

                    // If PM-Workspace not found, use first project
                    if (selectedProject == null) {
                        selectedProject = projects.first()
                    }

                    // Set the chosen project as selected
                    projectRepository.setSelectedProject(selectedProject.id)
                }

                val sprintSummary = projectRepository.getSprintSummary(selectedProject.id)
                val board = projectRepository.getBoard(selectedProject.id)
                val timeEntries = projectRepository.getTimeEntries(getTodayDateString())

                // Extract available sprints from sprint summary
                val availableSprints = generateAvailableSprints(sprintSummary)

                // Extract user's tasks from Active column (first 3)
                val myTasks = board
                    .firstOrNull { it.name.contains("Active", ignoreCase = true) }
                    ?.items
                    ?.take(3)
                    ?: emptyList()

                // Extract recent activity (simplified to activity titles)
                val activity = board
                    .flatMap { it.items }
                    .take(5)
                    .map { it.title }

                val totalHours = timeEntries.sumOf { it.hours.toDouble() }.toFloat()

                _uiState.update {
                    it.copy(
                        selectedProject = selectedProject.name,
                        sprintName = sprintSummary?.name ?: "No Active Sprint",
                        sprintProgress = sprintSummary?.progress ?: 0f,
                        completedStoryPoints = sprintSummary?.completedPoints ?: 0,
                        totalStoryPoints = sprintSummary?.totalPoints ?: 0,
                        blockedItemsCount = sprintSummary?.blockedItems ?: 0,
                        hoursToday = totalHours,
                        myTasks = myTasks,
                        recentActivity = activity,
                        availableProjects = projects,
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
     * This will be replaced with a dedicated API call once available.
     *
     * @param sprintSummary Current sprint summary
     * @return List of available sprint names
     */
    private fun generateAvailableSprints(sprintSummary: SprintSummary?): List<String> {
        if (sprintSummary == null) {
            return emptyList()
        }

        val sprints = mutableListOf<String>()
        val currentName = sprintSummary.name

        // Extract sprint number from name (e.g., "Sprint 5" -> 5)
        val sprintNumberRegex = """Sprint\s+(\d+)""".toRegex()
        val matchResult = sprintNumberRegex.find(currentName)

        if (matchResult != null) {
            val currentNumber = matchResult.groupValues[1].toIntOrNull() ?: 0
            if (currentNumber > 1) {
                sprints.add("Sprint ${currentNumber - 1}")
            }
        }

        // Add current sprint
        sprints.add(currentName)

        // Add next sprint
        if (matchResult != null) {
            val currentNumber = matchResult.groupValues[1].toIntOrNull() ?: 0
            sprints.add("Sprint ${currentNumber + 1}")
        }

        return sprints
    }

    /**
     * Gets today's date in ISO 8601 format (YYYY-MM-DD).
     *
     * @return Today's date string
     */
    private fun getTodayDateString(): String {
        val calendar = java.util.Calendar.getInstance()
        val year = calendar.get(java.util.Calendar.YEAR)
        val month = String.format("%02d", calendar.get(java.util.Calendar.MONTH) + 1)
        val day = String.format("%02d", calendar.get(java.util.Calendar.DAY_OF_MONTH))
        return "$year-$month-$day"
    }
}
