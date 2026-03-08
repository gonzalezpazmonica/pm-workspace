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
     * Loads all dashboard data: project, sprint summary, tasks, and activity.
     * Called on ViewModel initialization and during refresh.
     */
    private fun loadDashboardData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val project = projectRepository.getSelectedProject()
                if (project == null) {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = "No project selected"
                        )
                    }
                    return@launch
                }

                val sprintSummary = projectRepository.getSprintSummary(project.id)
                val board = projectRepository.getBoard(project.id)
                val timeEntries = projectRepository.getTimeEntries(getTodayDateString())

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
                        selectedProject = project.name,
                        sprintName = sprintSummary?.name ?: "No Active Sprint",
                        sprintProgress = sprintSummary?.progress ?: 0f,
                        completedStoryPoints = sprintSummary?.completedPoints ?: 0,
                        totalStoryPoints = sprintSummary?.totalPoints ?: 0,
                        blockedItemsCount = sprintSummary?.blockedItems ?: 0,
                        hoursToday = totalHours,
                        myTasks = myTasks,
                        recentActivity = activity,
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
