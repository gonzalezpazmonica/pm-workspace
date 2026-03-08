package com.savia.domain.model

import kotlinx.serialization.Serializable

/**
 * Represents a conversation thread with Claude Code via the Savia Bridge server.
 *
 * A conversation is a container for related messages between the user and the AI assistant.
 * Each conversation maintains its own history and state, allowing users to keep multiple
 * independent chat sessions organized.
 *
 * ## Role in Clean Architecture
 * As a domain entity, [Conversation] defines the business rules for conversation management:
 * - Conversations are archived (soft deleted) rather than permanently removed
 * - Message ordering is preserved within a conversation
 * - Conversations track creation and update timestamps for sorting and filtering
 *
 * ## Usage
 * Create a new conversation when:
 * - User starts a new chat session
 * - User switches topics and wants to separate history
 * - Backend connection is re-established (may create a new conversation ID)
 *
 * Archive a conversation when:
 * - User explicitly dismisses or hides the conversation
 * - A conversation becomes stale (client-side decision)
 * - Cleanup is needed without permanent data loss
 *
 * @property id Unique identifier for this conversation (UUID)
 * @property title User-provided or auto-generated conversation name
 * @property messages Ordered list of [Message] objects (most recent last)
 * @property createdAt When the conversation was started (milliseconds since epoch)
 * @property updatedAt When the conversation was last modified
 * @property isArchived Whether this conversation is hidden from the main list
 */
@Serializable
data class Conversation(
    val id: String,
    val title: String,
    val messages: List<Message> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val isArchived: Boolean = false
) {
    /**
     * Returns the most recent message in this conversation.
     *
     * @return The last message, or null if the conversation is empty
     */
    val lastMessage: Message?
        get() = messages.lastOrNull()

    /**
     * Returns the total number of messages in this conversation.
     *
     * @return Message count
     */
    val messageCount: Int
        get() = messages.size

    /**
     * Returns a preview of the conversation's last message.
     *
     * Used for displaying a snippet in conversation list views.
     *
     * @return First 100 characters of the last message, or empty string if no messages
     */
    val preview: String
        get() = lastMessage?.content?.take(100) ?: ""
}
