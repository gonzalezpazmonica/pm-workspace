package com.savia.mobile.ui.commands

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.CommandFamily
import com.savia.domain.model.SlashCommand
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Commands screen displaying command families and filtering.
 *
 * @property families All available command families
 * @property filteredCommands Filtered commands based on search/family selection
 * @property searchQuery Current search query text
 * @property selectedFamilyId Currently selected command family ID
 * @property isExecuting Whether a command is currently executing
 * @property isLoading Whether data is loading
 * @property error Error message if any
 */
data class CommandsUiState(
    val families: List<CommandFamily> = emptyList(),
    val filteredCommands: List<SlashCommand> = emptyList(),
    val searchQuery: String = "",
    val selectedFamilyId: String? = null,
    val isExecuting: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null
)

/**
 * ViewModel for Commands screen managing command families and execution.
 *
 * Responsibilities:
 * - Load command families from ProjectRepository
 * - Filter commands by search query and family selection
 * - Execute commands via ProjectRepository
 * - Manage command state and error handling
 *
 * Clean Architecture: ViewModel (UI layer) coordinates with ProjectRepository
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class CommandsViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for Commands screen.
     * Updated as commands load and user interacts.
     */
    private val _uiState = MutableStateFlow(CommandsUiState())

    /**
     * Public observable state for CommandsScreen to collect and recompose on changes.
     * Exposed as StateFlow for lifecycle-aware collection.
     */
    val uiState: StateFlow<CommandsUiState> = _uiState.asStateFlow()

    init {
        loadCommands()
    }

    /**
     * Loads command families from the repository.
     * Called on ViewModel initialization.
     */
    private fun loadCommands() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val families = projectRepository.getCommands()
                _uiState.update {
                    it.copy(
                        families = families,
                        isLoading = false,
                        error = null
                    )
                }
                // Load all commands for initial state
                updateFilteredCommands()
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Error loading commands"
                    )
                }
            }
        }
    }

    /**
     * Updates filtered commands based on current search query and selected family.
     * Filters across all families if search is active, otherwise shows selected family.
     */
    private fun updateFilteredCommands() {
        val currentState = _uiState.value
        val filtered = if (currentState.searchQuery.isNotEmpty()) {
            // Search across all families
            currentState.families
                .flatMap { it.commands }
                .filter {
                    it.name.contains(currentState.searchQuery, ignoreCase = true) ||
                    it.description.contains(currentState.searchQuery, ignoreCase = true)
                }
        } else if (currentState.selectedFamilyId != null) {
            // Show commands from selected family
            currentState.families
                .find { it.id == currentState.selectedFamilyId }
                ?.commands
                ?: emptyList()
        } else {
            // Show all commands
            currentState.families.flatMap { it.commands }
        }

        _uiState.update {
            it.copy(filteredCommands = filtered)
        }
    }

    /**
     * Updates the search query and filters commands accordingly.
     *
     * @param query New search query
     */
    fun search(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        updateFilteredCommands()
    }

    /**
     * Selects a command family to filter by.
     *
     * @param familyId ID of the family to select (null to deselect)
     */
    fun selectFamily(familyId: String?) {
        _uiState.update { it.copy(selectedFamilyId = familyId) }
        updateFilteredCommands()
    }

    /**
     * Executes a command via the Bridge.
     * Updates isExecuting state during execution.
     *
     * @param command The command name to execute
     */
    fun executeCommand(command: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isExecuting = true) }
            try {
                val projectId = projectRepository.getSelectedProject()?.id
                if (projectId == null) {
                    _uiState.update {
                        it.copy(
                            isExecuting = false,
                            error = "No project selected"
                        )
                    }
                    return@launch
                }

                projectRepository.executeCommand(command, projectId).collect { response ->
                    // Command is being executed, response is streaming in
                    // Screen will show loading state
                }

                _uiState.update {
                    it.copy(
                        isExecuting = false,
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isExecuting = false,
                        error = e.message ?: "Error executing command"
                    )
                }
            }
        }
    }

    /**
     * Clears any error message from state.
     * Called by CommandsScreen after showing error.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
