package com.savia.mobile.ui.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.savia.domain.model.Conversation
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.domain.model.StreamDelta
import com.savia.domain.repository.ChatRepository
import com.savia.domain.repository.SecurityRepository
import com.savia.domain.usecase.SendMessageUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * UI state for the Chat screen containing all observable data.
 *
 * @property messages complete list of messages in current conversation
 * @property streamingText partial text of assistant message currently being streamed
 * @property isStreaming whether a message stream is in progress
 * @property isConfigured whether Bridge or API key is configured
 * @property currentConversationId ID of the active conversation (null if none selected)
 * @property error error message to display in snackbar (null if no error)
 * @property conversations list of all past conversations for sidebar/sessions
 */
data class ChatUiState(
    val messages: List<Message> = emptyList(),
    val streamingText: String = "",
    val isStreaming: Boolean = false,
    val isConfigured: Boolean = false,
    val currentConversationId: String? = null,
    val error: String? = null,
    val conversations: List<Conversation> = emptyList()
)

/**
 * ViewModel for Chat screen managing message state and interactions.
 *
 * Responsibilities:
 * - Manage message list state (user and assistant messages)
 * - Handle message streaming from Claude API or Bridge
 * - Manage conversation lifecycle (create, load, delete)
 * - Handle configuration (Bridge setup or API key saving)
 * - Error handling and user feedback
 * - Session persistence (restore last conversation on app launch)
 *
 * Data flow:
 * ChatScreen → sendMessage() → SendMessageUseCase → ChatRepository → API/Bridge → StreamDelta flow
 * StreamDelta flow → _uiState updates → ChatScreen recomposes
 *
 * Clean Architecture: ViewModel (UI layer) coordinates domain use cases and repositories
 *
 * @author Savia Mobile Team
 */
@HiltViewModel
class ChatViewModel @Inject constructor(
    private val sendMessageUseCase: SendMessageUseCase,
    private val chatRepository: ChatRepository,
    private val securityRepository: SecurityRepository
) : ViewModel() {

    /**
     * Mutable state flow backing the public uiState StateFlow.
     * Updated by all ViewModel methods to reflect user actions and async results.
     */
    private val _uiState = MutableStateFlow(ChatUiState())

    /**
     * Public observable state for ChatScreen to collect and recompose on changes.
     * Exposed as StateFlow for lifecycle-aware collection.
     */
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    /**
     * Default system prompt used when communicating directly with Anthropic API.
     * Not sent when using Bridge (Bridge has its own enhanced system prompt with user context).
     */
    private val systemPrompt = """
        Eres Savia, una asistente de gestión de proyectos inteligente, empática y eficiente.
        Respondes en el idioma del usuario (español por defecto).
        Eres concisa pero cercana. Usas datos cuando los tienes disponibles.
        Tu objetivo es ayudar al usuario a gestionar sus proyectos de software de forma efectiva.
    """.trimIndent()

    init {
        checkConfig()
        loadConversations()
        restoreLastSession()
    }

    /**
     * Checks if Bridge or API key is configured and updates isConfigured state.
     * Preference: Bridge over direct API (hasBridgeConfig checked first).
     * Called on ViewModel initialization.
     */
    private fun checkConfig() {
        viewModelScope.launch {
            // Check bridge config first, fallback to API key
            val configured = securityRepository.hasBridgeConfig() || securityRepository.hasApiKey()
            _uiState.update { it.copy(isConfigured = configured) }
        }
    }

    /**
     * Restores the user's last active conversation on app launch.
     * Called during init to provide continuity across app sessions.
     * If no prior conversation exists, screen shows empty welcome message.
     */
    private fun restoreLastSession() {
        viewModelScope.launch {
            val lastId = securityRepository.getLastConversationId()
            if (lastId != null) {
                loadConversation(lastId)
            }
        }
    }

    /**
     * Saves the ID of the current active conversation for session restoration.
     * Called whenever user switches conversations or creates a new one.
     *
     * @param conversationId ID to persist as last active
     */
    private fun saveCurrentSession(conversationId: String) {
        viewModelScope.launch {
            securityRepository.saveLastConversationId(conversationId)
        }
    }

    /**
     * Loads all conversations from repository as a Flow.
     * Subscribed during init to keep conversations list up-to-date.
     * Enables real-time sync when conversations are created/deleted elsewhere.
     */
    private fun loadConversations() {
        viewModelScope.launch {
            chatRepository.getConversations().collect { conversations ->
                _uiState.update { it.copy(conversations = conversations) }
            }
        }
    }

    /**
     * Creates a new empty conversation and switches to it.
     * Clears message history and streaming text.
     * Called by "New conversation" button in Chat screen top bar.
     * Saves conversation ID for session restoration.
     */
    fun startNewConversation() {
        viewModelScope.launch {
            val conversation = chatRepository.createConversation()
            _uiState.update {
                it.copy(
                    currentConversationId = conversation.id,
                    messages = emptyList(),
                    streamingText = "",
                    error = null
                )
            }
            saveCurrentSession(conversation.id)
        }
    }

    /**
     * Loads a conversation by ID and subscribes to its message history.
     * Used when user selects a conversation from Sessions tab or navigates with ID.
     * Flow-based subscription keeps message list in sync with database.
     *
     * @param conversationId ID of conversation to load
     */
    fun loadConversation(conversationId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(currentConversationId = conversationId) }
            saveCurrentSession(conversationId)
            chatRepository.getMessages(conversationId).collect { messages ->
                _uiState.update { it.copy(messages = messages) }
            }
        }
    }

    /**
     * Sends a user message and streams Claude's response.
     *
     * Process:
     * 1. Create user message and add to state
     * 2. Set isStreaming=true and clear previous streaming text
     * 3. Call SendMessageUseCase with conversation context
     * 4. Collect StreamDelta events:
     *    - StreamDelta.Text: append to streamingText for real-time display
     *    - StreamDelta.Done: finalize message, set isStreaming=false
     *    - StreamDelta.Error: show error, set isStreaming=false
     * 5. Handle network/API errors via catch block
     *
     * Auto-creates a conversation if one is not active.
     * Prefers Bridge connection if configured; falls back to direct API.
     * Bridge includes user profile/context in its system prompt.
     *
     * @param content user message text
     */
    fun sendMessage(content: String) {
        if (content.isBlank()) return

        viewModelScope.launch {
            val conversationId = _uiState.value.currentConversationId
                ?: chatRepository.createConversation().also { conv ->
                    _uiState.update { it.copy(currentConversationId = conv.id) }
                    saveCurrentSession(conv.id)
                }.id

            val userMessage = Message(
                id = UUID.randomUUID().toString(),
                conversationId = conversationId,
                role = MessageRole.USER,
                content = content
            )
            _uiState.update {
                it.copy(
                    messages = it.messages + userMessage,
                    isStreaming = true,
                    streamingText = "",
                    error = null
                )
            }

            // Bridge has its own system prompt with user profile, don't override it.
            // Only send system prompt when using direct Anthropic API.
            val useBridge = securityRepository.hasBridgeConfig()
            sendMessageUseCase(
                conversationId = conversationId,
                userContent = content,
                systemPrompt = if (useBridge) null else systemPrompt
            ).catch { e ->
                _uiState.update {
                    it.copy(
                        isStreaming = false,
                        error = e.message ?: "Error desconocido"
                    )
                }
            }.collect { delta ->
                when (delta) {
                    is StreamDelta.Text -> {
                        _uiState.update {
                            it.copy(streamingText = it.streamingText + delta.text)
                        }
                    }
                    is StreamDelta.Done -> {
                        val assistantMessage = Message(
                            id = UUID.randomUUID().toString(),
                            conversationId = conversationId,
                            role = MessageRole.ASSISTANT,
                            content = _uiState.value.streamingText
                        )
                        _uiState.update {
                            it.copy(
                                messages = it.messages + assistantMessage,
                                streamingText = "",
                                isStreaming = false
                            )
                        }
                    }
                    is StreamDelta.Error -> {
                        _uiState.update {
                            it.copy(
                                isStreaming = false,
                                error = delta.message
                            )
                        }
                    }
                    is StreamDelta.Start -> { /* Stream started */ }
                }
            }
        }
    }

    /**
     * Saves Savia Bridge connection configuration for all future requests.
     * Host, port, and auth token are encrypted via SecurityRepository.
     *
     * @param host Bridge server hostname or IP address
     * @param port Bridge server port (default 8922)
     * @param token authentication token for Bridge API access
     */
    fun saveBridgeConfig(host: String, port: Int, token: String) {
        viewModelScope.launch {
            securityRepository.saveBridgeConfig(host, port, token)
            _uiState.update { it.copy(isConfigured = true) }
        }
    }

    /**
     * Saves Anthropic Claude API key for direct API calls.
     * Used when Bridge is not available or user prefers direct API.
     * API key is encrypted via SecurityRepository (EncryptedSharedPreferences).
     *
     * @param key Anthropic API key starting with "sk-ant-"
     */
    fun saveApiKey(key: String) {
        viewModelScope.launch {
            securityRepository.saveApiKey(key)
            _uiState.update { it.copy(isConfigured = true) }
        }
    }

    /**
     * Clears any error message from state after displaying it.
     * Called by ChatScreen after snackbar shows error.
     * Prevents error from being re-shown on subsequent recompositions.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    /**
     * Deletes a conversation and its associated messages from database.
     * If the deleted conversation is currently active, clears the active conversation state.
     * Called from Sessions tab delete button.
     *
     * @param id conversation ID to delete
     */
    fun deleteConversation(id: String) {
        viewModelScope.launch {
            chatRepository.deleteConversation(id)
            if (_uiState.value.currentConversationId == id) {
                securityRepository.clearLastConversationId()
                _uiState.update {
                    it.copy(
                        currentConversationId = null,
                        messages = emptyList()
                    )
                }
            }
        }
    }
}
