package com.savia.mobile.ui.kanban

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.BoardColumn
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Kanban screen displaying board columns and items.
 *
 * @property columns List of board columns with their items
 * @property selectedFilter Current filter applied (All, Mine, Blocked)
 * @property isLoading Whether data is loading
 * @property error Error message if any
 */
data class KanbanUiState(
    val columns: List<BoardColumn> = emptyList(),
    val selectedFilter: String = "All",
    val isLoading: Boolean = false,
    val error: String? = null
)

/**
 * ViewModel for Kanban screen managing board state and filtering.
 *
 * Responsibilities:
 * - Load board columns from ProjectRepository
 * - Apply filters (All, Mine, Blocked)
 * - Manage board state
 *
 * Clean Architecture: ViewModel (UI layer) coordinates with ProjectRepository
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class KanbanViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for Kanban screen.
     */
    private val _uiState = MutableStateFlow(KanbanUiState())

    /**
     * Public observable state for KanbanScreen to collect and recompose on changes.
     */
    val uiState: StateFlow<KanbanUiState> = _uiState.asStateFlow()

    init {
        loadBoard()
    }

    /**
     * Loads the board for the selected project.
     */
    private fun loadBoard() {
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

                val columns = projectRepository.getBoard(project.id)
                _uiState.update {
                    it.copy(
                        columns = columns,
                        isLoading = false,
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Error loading board"
                    )
                }
            }
        }
    }

    /**
     * Applies a filter to the board.
     *
     * @param filter Filter name: "All", "Mine", or "Blocked"
     */
    fun applyFilter(filter: String) {
        _uiState.update { it.copy(selectedFilter = filter) }
    }

    /**
     * Clears any error message from state.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
