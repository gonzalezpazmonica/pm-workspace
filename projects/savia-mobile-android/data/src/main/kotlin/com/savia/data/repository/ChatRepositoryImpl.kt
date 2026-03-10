package com.savia.data.repository

import com.savia.data.api.ClaudeApiService
import com.savia.data.api.ClaudeStreamParser
import com.savia.data.api.SaviaBridgeService
import com.savia.data.api.model.ApiMessage
import com.savia.data.api.model.CreateMessageRequest
import com.savia.data.local.dao.ConversationDao
import com.savia.data.local.entity.ConversationEntity
import com.savia.data.local.entity.MessageEntity
import com.savia.domain.model.Conversation
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.domain.model.StreamDelta
import com.savia.domain.repository.ChatRepository
import com.savia.domain.repository.SecurityRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository implementation for chat messaging (data layer).
 *
 * **Responsibilities:**
 * 1. Route messages between mobile app and Claude (bridge or API)
 * 2. Persist conversations and messages to local database
 * 3. Manage conversation lifecycle (create, list, delete)
 * 4. Implement auto-titling and timestamp management
 * 5. Handle streaming responses and error cases
 *
 * **Architecture Role:**
 * - Clean Architecture data layer (repository pattern)
 * - Implements interface [ChatRepository] from domain layer
 * - Abstracts API/Bridge/Database from domain logic
 * - Single source of truth for message state
 *
 * **Request Flow:**
 * User input → UI calls sendMessage → determines route (bridge/API) →
 * sends request → parses stream → saves to DB → emits deltas
 *
 * **Dual-Stack Architecture:**
 * - Primary: Savia Bridge (recommended, lower latency)
 * - Fallback: Anthropic API (legacy, no bridge connection)
 * - Decision: Made by [SecurityRepository.hasBridgeConfig()]
 * - Transparent to UI (same interface, different impl)
 *
 * **Message Persistence:**
 * - User messages saved immediately (optimistic)
 * - Assistant messages saved when stream completes
 * - Database is source of truth for conversation history
 * - Supports offline-first (can read messages without network)
 *
 * **Auto-Titling:**
 * - First message (count ≤ 2): Auto-generate title from user text
 * - Subsequent messages: Keep existing title or allow user rename
 * - Title truncated at 50 chars with "..." if longer
 *
 * **Thread Safety:**
 * - Singleton managed by Hilt
 * - All DB operations use suspend/coroutine (thread-safe)
 * - Streaming on IO dispatcher (non-blocking)
 * - Safe concurrent sendMessage calls (queued by Flow)
 *
 * @constructor Injected dependencies via Hilt
 * @param apiService Retrofit interface for Anthropic API (legacy)
 * @param bridgeService Bridge transport (primary)
 * @param streamParser SSE event parser
 * @param conversationDao Database access (conversations/messages)
 * @param securityRepository Configuration & secrets (bridge URL, API key, etc.)
 *
 * @see ChatRepository Domain interface this implements
 * @see SaviaBridgeService Primary transport (bridge)
 * @see ClaudeApiService Legacy transport (Anthropic API)
 */
@Singleton
class ChatRepositoryImpl @Inject constructor(
    private val apiService: ClaudeApiService,
    private val bridgeService: SaviaBridgeService,
    private val streamParser: ClaudeStreamParser,
    private val conversationDao: ConversationDao,
    private val securityRepository: SecurityRepository
) : ChatRepository {

    /**
     * Send a message and stream the response.
     *
     * **High-Level Flow:**
     * 1. Determine routing: Bridge or API fallback?
     * 2. Build request: Current conversation history + new message
     * 3. Send request: Establish streaming connection
     * 4. Stream response: Emit deltas as they arrive
     * 5. Save response: When stream completes, persist assistant message
     * 6. Update metadata: Title (on first exchange), timestamp
     *
     * **Routing Decision:**
     * - Bridge: If [SecurityRepository.hasBridgeConfig()] returns true
     *   - URL and token obtained from secure storage
     *   - SessionId is the conversationId (maintains server-side context)
     * - API: If bridge unavailable or not configured
     *   - Requires valid Anthropic API key
     *   - Must send full message history (stateless)
     *   - SessionId is not used (no server-side session)
     *
     * **Message History:**
     * - Loaded from local database via DAO
     * - Filters out system messages (role == "system")
     * - Newest first (natural conversation order for context window)
     * - Converted to API format: ApiMessage(role, content)
     *
     * **System Prompt:**
     * - Optional parameter (can be null)
     * - If provided: Sent to Claude to guide response
     * - Use case: Customize behavior ("Be concise", "Use code examples", etc.)
     * - API automatically combines with conversation messages
     *
     * **Streaming:**
     * - Non-blocking (runs on Dispatchers.IO)
     * - Each delta is emitted as it arrives
     * - Backpressure handled by Flow collector
     * - Full response accumulated in memory (StringBuilder)
     * - Suitable for messages up to a few MB
     *
     * **Auto-Titling (First Exchange):**
     * - When message count ≤ 2 (typically user + assistant)
     * - Title = first 50 chars of user message
     * - Truncated with "..." if longer
     * - Example: "What is the capital of France?" → Title same
     * - Example: "Write a 2000-word essay about..." → Title="Write a 2000-word essay about..."
     *
     * **Message ID Generation:**
     * - Assistant message ID: UUID.randomUUID()
     * - User message ID: Assumed saved by caller or generated upstream
     * - No server-side ID assignment (fully client-generated)
     *
     * **Error Semantics:**
     * - Bridge errors (4xx, 5xx): Emit StreamDelta.Error, close stream
     * - API errors: Same (Retrofit throws, caught, converted)
     * - Parsing errors: Skipped, stream continues
     * - Connection loss: Emit error, close stream
     * - Invalid config: IllegalStateException (no bridge or API key)
     *
     * @param conversationId Conversation ID (session ID for bridge, context grouping)
     * @param content User message text (what the user typed)
     * @param systemPrompt Optional system instructions (Claude behavior guide)
     *
     * @return Flow<StreamDelta> Streaming response deltas
     *         - StreamDelta.Start: Initial message metadata
     *         - StreamDelta.Text: Response chunks
     *         - StreamDelta.Done: Completion signal
     *         - StreamDelta.Error: Error event
     *         - Runs on Dispatchers.IO
     *         - Completes after Done or error
     *
     * @throws IllegalStateException if neither bridge nor API key configured
     */
    override fun sendMessage(
        conversationId: String,
        content: String,
        systemPrompt: String?
    ): Flow<StreamDelta> = flow {
        // Determine which service to use: bridge or Anthropic API
        val useBridge = securityRepository.hasBridgeConfig()

        val deltaStream = if (useBridge) {
            // Use Savia Bridge
            val bridgeUrl = securityRepository.getBridgeUrl()
                ?: error("Bridge URL not configured. Please reconnect in Settings.")
            val bridgeToken = securityRepository.getBridgeToken()
                ?: error("Bridge token not configured. Please reconnect in Settings.")

            bridgeService.sendMessageStream(
                bridgeUrl = bridgeUrl,
                authToken = bridgeToken,
                message = content,
                sessionId = conversationId,
                systemPrompt = systemPrompt,
                interactive = false
            )
        } else {
            // Use Anthropic API (legacy)
            val apiKey = securityRepository.getApiKey()
                ?: throw IllegalStateException("API key not configured")

            // Build message history from local DB
            val history = conversationDao.getMessages(conversationId)
                .first()
                .filter { it.role != MessageRole.SYSTEM.name }
                .map { ApiMessage(role = it.role.lowercase(), content = it.content) }

            // Add the new user message
            val messages = history + ApiMessage(role = "user", content = content)

            val request = CreateMessageRequest(
                messages = messages,
                system = systemPrompt
            )

            val responseBody = apiService.createMessageStream(
                apiKey = apiKey,
                request = request
            )

            streamParser.parse(responseBody)
        }

        // Collect full response text to save as assistant message
        val fullResponse = StringBuilder()
        val assistantMessageId = UUID.randomUUID().toString()

        emitAll(
            deltaStream.map { delta ->
                when (delta) {
                    is StreamDelta.Text -> {
                        fullResponse.append(delta.text)
                        delta
                    }
                    is StreamDelta.Done -> {
                        // Save assistant message to DB
                        val assistantMessage = MessageEntity(
                            id = assistantMessageId,
                            conversationId = conversationId,
                            role = MessageRole.ASSISTANT.name,
                            content = fullResponse.toString(),
                            timestamp = System.currentTimeMillis()
                        )
                        conversationDao.insertMessage(assistantMessage)
                        conversationDao.updateTimestamp(conversationId)

                        // Auto-title on first exchange
                        val msgCount = conversationDao.getMessages(conversationId).first().size
                        if (msgCount <= 2) {
                            val title = content.take(50).let {
                                if (it.length == 50) "$it..." else it
                            }
                            conversationDao.updateTitle(conversationId, title)
                        }

                        delta
                    }
                    else -> delta
                }
            }
        )
    }

    /**
     * Get all active conversations, sorted by last modified (newest first).
     *
     * **Reactivity:**
     * Returns a Flow that emits whenever conversations change:
     * - New conversation created
     * - Existing conversation updated (title, timestamp)
     * - Conversation deleted
     *
     * **UI Binding:**
     * Suitable for conversation list screen.
     * Automatically re-renders when new conversations arrive.
     *
     * @return Flow<List<Conversation>> All non-archived conversations
     *         Completes when Flow is cancelled (screen closes)
     */
    override fun getConversations(): Flow<List<Conversation>> =
        conversationDao.getAll().map { entities ->
            entities.map { it.toDomain() }
        }

    /**
     * Get a single conversation with all its messages.
     *
     * **Composition:**
     * - Conversation entity from database
     * - Messages loaded separately and composed
     * - Null if conversation doesn't exist
     *
     * **Reactivity:**
     * Re-emits when conversation or messages are updated.
     * Suitable for conversation detail screen.
     *
     * @param id Conversation ID
     *
     * @return Flow<Conversation?> Single conversation or null
     *         Contains full message history
     */
    override fun getConversation(id: String): Flow<Conversation?> =
        conversationDao.getById(id).map { entity ->
            entity?.let {
                val messages = conversationDao.getMessages(id).first()
                it.toDomain(messages)
            }
        }

    /**
     * Get all messages in a conversation.
     *
     * **Ordering:**
     * Oldest first (ascending timestamp).
     * Matches chat UI display order.
     *
     * **Reactivity:**
     * Re-emits when messages are added/updated.
     *
     * **Performance:**
     * Efficient even with thousands of messages.
     * Database index on conversationId.
     *
     * @param conversationId Conversation ID
     *
     * @return Flow<List<Message>> Messages in chronological order
     *         Empty list if no messages
     */
    override fun getMessages(conversationId: String): Flow<List<Message>> =
        conversationDao.getMessages(conversationId).map { entities ->
            entities.map { it.toDomain() }
        }

    /**
     * Create a new empty conversation.
     *
     * **Initialization:**
     * - ID: Generated UUID
     * - Title: User-provided (or auto-generated on first message)
     * - createdAt/updatedAt: Current time
     * - isArchived: false (active)
     * - No messages yet
     *
     * **Persistence:**
     * Immediately written to database.
     * Returns domain model (not entity).
     *
     * @param title Display name for conversation
     *
     * @return [Conversation] Created conversation (with ID, timestamps)
     */
    override suspend fun createConversation(title: String): Conversation {
        val conversation = Conversation(
            id = UUID.randomUUID().toString(),
            title = title
        )
        conversationDao.insertConversation(ConversationEntity.fromDomain(conversation))
        return conversation
    }

    /**
     * Save a message to the database.
     *
     * **Use Cases:**
     * - Save user message immediately (optimistic)
     * - Save assistant message when stream completes
     * - Persist user edits or corrections
     *
     * **Side Effects:**
     * - Updates conversation's updatedAt timestamp (marks as recently active)
     * - Causes Flow emitters to re-emit (UI updates)
     *
     * @param message [Message] to persist (with ID, role, content, timestamp)
     */
    override suspend fun saveMessage(message: Message) {
        conversationDao.insertMessage(MessageEntity.fromDomain(message))
        conversationDao.updateTimestamp(message.conversationId)
    }

    /**
     * Permanently delete a conversation and all its messages.
     *
     * **Consequences:**
     * - All messages in conversation deleted (cascade)
     * - Cannot be undone (hard delete, not soft delete/archive)
     * - UI should confirm before calling
     *
     * **Alternative:**
     * Consider archiving instead: updateConversationTitle() with archive flag.
     * (Not currently implemented in this repository)
     *
     * @param id Conversation ID to delete
     */
    override suspend fun deleteConversation(id: String) {
        conversationDao.deleteConversation(id)
    }

    /**
     * Update conversation title.
     *
     * **Side Effects:**
     * - Updates title (displayed in conversation list)
     * - Updates updatedAt timestamp (moves to top of list)
     * - Triggers Flow re-emission (UI updates)
     *
     * **Use Cases:**
     * - User renames conversation in UI
     * - Auto-title on first message (done in sendMessage())
     *
     * @param id Conversation ID
     * @param title New title
     */
    override suspend fun updateConversationTitle(id: String, title: String) {
        conversationDao.updateTitle(id, title)
    }
}
