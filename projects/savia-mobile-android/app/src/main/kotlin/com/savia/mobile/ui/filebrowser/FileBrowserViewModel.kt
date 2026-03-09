package com.savia.mobile.ui.filebrowser

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.data.api.FileContentResponse
import com.savia.data.api.FileEntry
import com.savia.data.api.SaviaBridgeService
import com.savia.domain.repository.SecurityRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for the file browser screen.
 *
 * Provides directory listing and file content reading via Bridge endpoints.
 * Supports breadcrumb navigation, back navigation, and file content viewing
 * for code and markdown files.
 */
@HiltViewModel
class FileBrowserViewModel @Inject constructor(
    private val bridgeService: SaviaBridgeService,
    private val securityRepository: SecurityRepository
) : ViewModel() {

    data class FileBrowserUiState(
        val currentPath: String = "",
        val entries: List<FileEntry> = emptyList(),
        val parentPath: String? = null,
        val isLoading: Boolean = false,
        val error: String? = null,
        val fileContent: FileContentResponse? = null,
        val isViewingFile: Boolean = false,
        val breadcrumbs: List<String> = listOf(""),
        val isConfigured: Boolean = false
    )

    private val _uiState = MutableStateFlow(FileBrowserUiState())
    val uiState: StateFlow<FileBrowserUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val bridgeUrl = securityRepository.getBridgeUrl()
            val token = securityRepository.getBridgeToken()
            _uiState.update { it.copy(isConfigured = bridgeUrl != null && token != null) }
            if (bridgeUrl != null && token != null) {
                loadDirectory("")
            }
        }
    }

    fun loadDirectory(path: String) {
        viewModelScope.launch(Dispatchers.IO) {
            _uiState.update { it.copy(isLoading = true, error = null, isViewingFile = false, fileContent = null) }
            val bridgeUrl = securityRepository.getBridgeUrl() ?: return@launch
            val token = securityRepository.getBridgeToken() ?: return@launch

            val response = bridgeService.listFiles(bridgeUrl, token, path)
            if (response != null) {
                val breadcrumbs = buildBreadcrumbs(response.path)
                _uiState.update {
                    it.copy(
                        currentPath = response.path,
                        entries = response.entries,
                        parentPath = response.parent,
                        isLoading = false,
                        breadcrumbs = breadcrumbs
                    )
                }
            } else {
                _uiState.update { it.copy(isLoading = false, error = "Failed to load directory") }
            }
        }
    }

    fun openFile(path: String) {
        viewModelScope.launch(Dispatchers.IO) {
            _uiState.update { it.copy(isLoading = true, error = null) }
            val bridgeUrl = securityRepository.getBridgeUrl() ?: return@launch
            val token = securityRepository.getBridgeToken() ?: return@launch

            val response = bridgeService.readFile(bridgeUrl, token, path)
            if (response != null) {
                _uiState.update {
                    it.copy(isLoading = false, isViewingFile = true, fileContent = response)
                }
            } else {
                _uiState.update { it.copy(isLoading = false, error = "Cannot read file") }
            }
        }
    }

    fun navigateBack(): Boolean {
        val state = _uiState.value
        if (state.isViewingFile) {
            _uiState.update { it.copy(isViewingFile = false, fileContent = null) }
            return true
        }
        if (state.parentPath != null) {
            loadDirectory(state.parentPath)
            return true
        }
        return false
    }

    fun onEntryClick(entry: FileEntry) {
        if (entry.type == "directory") {
            loadDirectory(entry.path)
        } else {
            openFile(entry.path)
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    private fun buildBreadcrumbs(path: String): List<String> {
        if (path.isEmpty()) return listOf("")
        val parts = path.split("/")
        val result = mutableListOf("")
        var accumulated = ""
        for (part in parts) {
            accumulated = if (accumulated.isEmpty()) part else "$accumulated/$part"
            result.add(accumulated)
        }
        return result
    }
}
