package com.savia.mobile.ui.timelog

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.TimeEntry
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

/**
 * UI state for the TimeLog screen.
 *
 * @property entries Time entries for today
 * @property totalHours Sum of hours logged today
 * @property isAdding Whether a time entry is being added
 * @property isLoading Whether data is loading
 * @property error Error message if any
 */
data class TimeLogUiState(
    val entries: List<TimeEntry> = emptyList(),
    val totalHours: Float = 0f,
    val isAdding: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null
)

/**
 * ViewModel for TimeLog screen managing time entries.
 *
 * Responsibilities:
 * - Load time entries for today
 * - Add new time entry
 * - Calculate total hours
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class TimeLogViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for TimeLog screen.
     */
    private val _uiState = MutableStateFlow(TimeLogUiState())

    /**
     * Public observable state for TimeLogScreen to collect and recompose on changes.
     */
    val uiState: StateFlow<TimeLogUiState> = _uiState.asStateFlow()

    init {
        loadTimeEntries()
    }

    /**
     * Loads time entries for today.
     */
    private fun loadTimeEntries() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val todayString = getTodayDateString()
                val entries = projectRepository.getTimeEntries(todayString)
                val total = entries.sumOf { it.hours.toDouble() }.toFloat()

                _uiState.update {
                    it.copy(
                        entries = entries,
                        totalHours = total,
                        isLoading = false,
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Error loading time entries"
                    )
                }
            }
        }
    }

    /**
     * Adds a new time entry.
     *
     * @param taskId ID of task to log time for
     * @param hours Hours to log
     * @param note Optional note
     */
    fun addTimeEntry(taskId: String, hours: Float, note: String?) {
        viewModelScope.launch {
            _uiState.update { it.copy(isAdding = true) }
            try {
                val todayString = getTodayDateString()
                projectRepository.logTime(taskId, hours, todayString, note)
                loadTimeEntries()
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isAdding = false,
                        error = e.message ?: "Error adding time entry"
                    )
                }
            }
        }
    }

    /**
     * Clears any error message.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    /**
     * Gets today's date in ISO 8601 format.
     */
    private fun getTodayDateString(): String {
        val today = LocalDate.now()
        return today.toString()
    }
}
