package com.savia.domain.model

import kotlinx.serialization.Serializable

/**
 * Represents a message exchanged with Claude Code or the Savia Bridge server.
 *
 * This domain model is part of the Clean Architecture domain layer and serves as the
 * core data structure for chat functionality. It encapsulates a single message in a conversation,
 * whether sent by the user or received from the AI assistant.
 *
 * ## Role in Clean Architecture
 * As a domain entity, [Message] is independent of any specific framework or persistence layer.
 * It contains only business logic and validation rules related to messages. Data access and
 * serialization details are handled by the data layer repositories.
 *
 * ## Usage
 * Create a new message when:
 * - User submits text to send to Claude
 * - Streaming response arrives from Bridge server
 * - System message needs to be persisted (e.g., conversation history)
 *
 * @property id Unique identifier for this message (UUID)
 * @property conversationId Reference to the parent conversation
 * @property role The sender role (user, assistant, or system)
 * @property content The message text
 * @property timestamp When the message was created (milliseconds since epoch)
 * @property isStreaming Whether this message is still receiving streaming data
 * @property tokenCount Optional Claude API token count (for cost tracking and context management)
 */
@Serializable
data class Message(
    val id: String,
    val conversationId: String,
    val role: MessageRole,
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isStreaming: Boolean = false,
    val tokenCount: Int? = null
)

/**
 * Enumeration of valid message sender roles in a conversation.
 *
 * Used to distinguish the source of each message for proper UI rendering and
 * conversation management.
 *
 * @property USER Human user sending a message
 * @property ASSISTANT Claude AI providing a response
 * @property SYSTEM Internal system messages (e.g., connection status, errors)
 */
@Serializable
enum class MessageRole {
    USER,
    ASSISTANT,
    SYSTEM
}
