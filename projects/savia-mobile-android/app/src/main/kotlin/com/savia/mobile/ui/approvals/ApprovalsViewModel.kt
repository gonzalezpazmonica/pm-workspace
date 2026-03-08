package com.savia.mobile.ui.approvals

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.ApprovalRequest
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Approvals screen.
 *
 * @property approvals List of pending approval requests
 * @property isLoading Whether approvals are loading
 * @property error Error message if any
 */
data class ApprovalsUiState(
    val approvals: List<ApprovalRequest> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

/**
 * ViewModel for Approvals screen managing approval requests.
 *
 * Responsibilities:
 * - Load pending approvals from ProjectRepository
 * - Handle approval/rejection actions
 * - Manage approval state
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class ApprovalsViewModel @Inject constructor(
    private val projectRepository: ProjectRepository
) : ViewModel() {

    /**
     * Mutable state backing the public uiState for Approvals screen.
     */
    private val _uiState = MutableStateFlow(ApprovalsUiState())

    /**
     * Public observable state for ApprovalsScreen to collect and recompose on changes.
     */
    val uiState: StateFlow<ApprovalsUiState> = _uiState.asStateFlow()

    init {
        loadApprovals()
    }

    /**
     * Loads pending approvals for the selected project.
     */
    private fun loadApprovals() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val projectId = projectRepository.getSelectedProject()?.id
                if (projectId == null) {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = "No project selected"
                        )
                    }
                    return@launch
                }

                val approvals = projectRepository.getApprovals(projectId)
                _uiState.update {
                    it.copy(
                        approvals = approvals,
                        isLoading = false,
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Error loading approvals"
                    )
                }
            }
        }
    }

    /**
     * Approves an approval request.
     * In a real implementation, would send approval action to Bridge.
     *
     * @param id Approval request ID to approve
     */
    fun approveRequest(id: String) {
        viewModelScope.launch {
            try {
                // TODO: Send approval action to Bridge
                _uiState.update {
                    it.copy(
                        approvals = it.approvals.filter { approval -> approval.id != id }
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(error = e.message ?: "Error approving request")
                }
            }
        }
    }

    /**
     * Rejects an approval request.
     * In a real implementation, would send rejection action to Bridge.
     *
     * @param id Approval request ID to reject
     */
    fun rejectRequest(id: String) {
        viewModelScope.launch {
            try {
                // TODO: Send rejection action to Bridge
                _uiState.update {
                    it.copy(
                        approvals = it.approvals.filter { approval -> approval.id != id }
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(error = e.message ?: "Error rejecting request")
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
}
