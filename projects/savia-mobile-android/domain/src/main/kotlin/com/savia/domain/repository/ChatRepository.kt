package com.savia.domain.repository

import com.savia.domain.model.Conversation
import com.savia.domain.model.Message
import com.savia.domain.model.StreamDelta
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for chat operations.
 *
 * This is a Clean Architecture repository interface that abstracts all chat-related data access.
 * It separates the domain layer from implementation details such as networking (Bridge API),
 * local persistence (Room), or caching strategies.
 *
 * Implementations of this interface handle:
 * - Communication with the Savia Bridge server via OkHttp
 * - SSE streaming of responses
 * - Persisting messages and conversations to Room database
 * - Caching and synchronization
 *
 * The repository operates at the boundary between domain and data layers, translating
 * between high-level chat operations (send message, create conversation) and low-level
 * data access implementations.
 */
interface ChatRepository {
    /**
     * Send a user message to Claude and receive a streaming response.
     *
     * This operation:
     * 1. Sends the message content to the Savia Bridge server via the Bridge API
     * 2. Opens an SSE stream to receive the assistant's response
     * 3. Emits [StreamDelta] events as data arrives
     * 4. Persists the user message immediately (before streaming starts)
     * 5. Persists the assistant message incrementally as it arrives
     *
     * The returned Flow should emit events in order:
     * - [StreamDelta.Start]: Stream opened with message ID and model
     * - [StreamDelta.Text]: Zero or more chunks of response text
     * - [StreamDelta.Done] or [StreamDelta.Error]: Terminal event
     *
     * Cancelling the Flow will abort the stream and discard any unsaved response data.
     *
     * @param conversationId Target conversation for this message
     * @param content User message text
     * @param systemPrompt Optional system message to set tone/context (if supported by Bridge)
     * @return Flow of streaming events
     * @throws IOException if connection to Bridge fails
     * @throws IllegalArgumentException if conversationId is invalid
     */
    fun sendMessage(
        conversationId: String,
        content: String,
        systemPrompt: String? = null
    ): Flow<StreamDelta>

    /**
     * Retrieve all conversations for the current user.
     *
     * Returns conversations in reverse chronological order (most recent first).
     * Emits a new list each time the underlying data changes (e.g., new message arrives).
     *
     * @return Flow of conversation lists
     */
    fun getConversations(): Flow<List<Conversation>>

    /**
     * Retrieve a single conversation with all its messages.
     *
     * The returned conversation includes the full message history, ordered chronologically
     * (oldest first). Emits a new conversation each time messages are added.
     *
     * @param id Conversation ID to fetch
     * @return Flow that emits the conversation, or null if not found
     */
    fun getConversation(id: String): Flow<Conversation?>

    /**
     * Retrieve only the messages for a conversation.
     *
     * Useful when the UI just needs to update message list without touching conversation metadata.
     * Messages are ordered chronologically (oldest first).
     *
     * @param conversationId Target conversation ID
     * @return Flow of message lists
     */
    fun getMessages(conversationId: String): Flow<List<Message>>

    /**
     * Create a new conversation.
     *
     * The repository assigns a unique ID and sets timestamps. If title is empty,
     * the presentation layer should auto-generate a title from the first message.
     *
     * @param title Initial conversation name (optional)
     * @return The created conversation object (ready to use for sendMessage)
     * @throws IOException if unable to persist to database
     */
    suspend fun createConversation(title: String = ""): Conversation

    /**
     * Persist a message to local storage.
     *
     * Called by use cases to save both user and assistant messages. The repository
     * handles Room insert/update logic and may also sync to Bridge if needed.
     *
     * @param message Message to save
     * @throws IOException if database operation fails
     */
    suspend fun saveMessage(message: Message)

    /**
     * Delete a conversation and all its associated messages.
     *
     * This is a soft delete (marking as archived) unless explicitly overridden.
     * Hard deletion is reserved for administrative cleanup.
     *
     * @param id Conversation ID to delete
     * @throws IOException if database operation fails
     */
    suspend fun deleteConversation(id: String)

    /**
     * Update a conversation's title.
     *
     * Useful when auto-generating a title after the first message,
     * or allowing user to rename conversations.
     *
     * @param id Conversation ID to update
     * @param title New title
     * @throws IOException if database operation fails
     * @throws IllegalArgumentException if conversation doesn't exist
     */
    suspend fun updateConversationTitle(id: String, title: String)
}
