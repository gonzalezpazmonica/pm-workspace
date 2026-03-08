package com.savia.mobile.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.Conversation
import com.savia.domain.repository.ChatRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for Dashboard/Sessions screen managing conversation list state.
 *
 * Responsibilities:
 * - Provide reactive conversations list from repository
 * - Track selected conversation for navigation to Chat
 * - Handle conversation deletion requests
 *
 * Data flow:
 * ChatRepository.getConversations() Flow → StateFlow (stateIn) → DashboardScreen collection
 * On conversation selection: selectConversation(id) → DashboardScreen callback → ChatScreen.loadConversation
 * On delete: deleteConversation(id) → ChatRepository.delete → automatically removed from conversations Flow
 *
 * State management:
 * - conversations: LiveData from repository converted to StateFlow
 * - Uses WhileSubscribed(5000) sharing strategy (stops collecting after 5s of no subscribers)
 * - Initial value is empty list, populated when Flow emits
 *
 * Clean Architecture: ViewModel (UI layer) between repository and UI
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val chatRepository: ChatRepository
) : ViewModel() {

    /**
     * Observable list of all conversations from repository.
     * Automatically updates when conversations are created, deleted, or updated.
     * StateFlow enables reactive UI updates via collectAsStateWithLifecycle.
     * Sharing strategy: WhileSubscribed(5000) stops collection after 5s of no collectors.
     */
    val conversations: StateFlow<List<Conversation>> = chatRepository
        .getConversations()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /**
     * Internal tracking of selected conversation ID.
     * Used to coordinate navigation callback when user taps a conversation.
     */
    private var _selectedConversationId: String? = null

    /**
     * Marks a conversation as selected for loading in Chat screen.
     * Stores ID for potential future use (currently not actively used by DashboardScreen callback).
     *
     * @param id conversation ID that user selected
     */
    fun selectConversation(id: String) {
        _selectedConversationId = id
    }

    /**
     * Deletes a conversation and all its associated messages.
     * Called when user taps delete button on a conversation card.
     * Deletion is handled asynchronously; UI updates via conversations Flow automatically.
     *
     * @param id conversation ID to delete
     */
    fun deleteConversation(id: String) {
        viewModelScope.launch {
            chatRepository.deleteConversation(id)
        }
    }
}
