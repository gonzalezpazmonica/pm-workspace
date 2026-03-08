package com.savia.mobile.ui.capture

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Capture screen.
 *
 * @property content Current input text
 * @property itemType Selected work item type (PBI, Bug, Note)
 * @property isCapturing Whether an item is being captured
 * @property captureResult ID of newly created work item
 * @property error Error message if any
 */
data class CaptureUiState(
    val content: String = "",
    val itemType: String = "PBI",
    val isCapturing: Boolean = false,
    val captureResult: String? = null,
    val error: String? = null
)

/**
 * ViewModel for Capture screen managing backlog item creation.
 *
 * Responsibilities:
 * - Capture user input as new backlog item
 * - Call ProjectRepository.captureBacklogItem()
 * - Manage capture state and results
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class CaptureViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for Capture screen.
     */
    private val _uiState = MutableStateFlow(CaptureUiState())

    /**
     * Public observable state for CaptureScreen to collect and recompose on changes.
     */
    val uiState: StateFlow<CaptureUiState> = _uiState.asStateFlow()

    /**
     * Updates the content text.
     *
     * @param text New content text
     */
    fun updateContent(text: String) {
        _uiState.update { it.copy(content = text) }
    }

    /**
     * Updates the selected item type.
     *
     * @param type Work item type: "PBI", "Bug", or "Note"
     */
    fun selectItemType(type: String) {
        _uiState.update { it.copy(itemType = type) }
    }

    /**
     * Captures the current content as a new backlog item.
     */
    fun captureItem() {
        if (_uiState.value.content.isBlank()) {
            _uiState.update { it.copy(error = "Please enter content") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isCapturing = true) }
            try {
                val projectId = projectRepository.getSelectedProject()?.id
                if (projectId == null) {
                    _uiState.update {
                        it.copy(
                            isCapturing = false,
                            error = "No project selected"
                        )
                    }
                    return@launch
                }

                val result = projectRepository.captureBacklogItem(
                    _uiState.value.content,
                    _uiState.value.itemType,
                    projectId
                )

                _uiState.update {
                    it.copy(
                        isCapturing = false,
                        captureResult = result,
                        content = "",
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isCapturing = false,
                        error = e.message ?: "Error capturing item"
                    )
                }
            }
        }
    }

    /**
     * Clears the capture result and prepares for new capture.
     */
    fun clearResult() {
        _uiState.update { it.copy(captureResult = null) }
    }

    /**
     * Clears any error message.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
