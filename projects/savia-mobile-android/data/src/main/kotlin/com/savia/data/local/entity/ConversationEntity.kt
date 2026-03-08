package com.savia.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.savia.domain.model.Conversation

/**
 * Room entity representing a conversation with Claude.
 *
 * **Database Table:** `conversations`
 *
 * **Columns:**
 * | Column | Type | Constraints | Purpose |
 * |--------|------|-------------|---------|
 * | id | TEXT | PRIMARY KEY | Unique conversation ID (UUID) |
 * | title | TEXT | NOT NULL | Display name in conversation list |
 * | createdAt | INTEGER | NOT NULL | Unix timestamp of creation (immutable) |
 * | updatedAt | INTEGER | NOT NULL | Last modification time (sorted by this) |
 * | isArchived | INTEGER (bool) | NOT NULL, DEFAULT 0 | Flag for soft-delete (0=active, 1=archived) |
 *
 * **Relationships:**
 * One-to-Many with [MessageEntity] via conversationId foreign key.
 * Cascade delete: Deleting conversation deletes all messages.
 *
 * **Domain Mapping:**
 * - Converts to/from domain [Conversation] model
 * - Unmarshalling: toDomain() (with messages loaded separately)
 * - Marshalling: fromDomain() (for insertion)
 * - Messages linked via repository composition (not embedded)
 *
 * **Timestamps:**
 * - createdAt: Set at conversation creation (never updated)
 * - updatedAt: Updated when conversation modified (title change, new message)
 * - Format: Unix milliseconds (System.currentTimeMillis())
 *
 * **Archive Flag:**
 * - false/0: Conversation is active (visible in list)
 * - true/1: Conversation is archived (hidden by default)
 * - Soft delete (data remains, can be unarchived)
 *
 * @property id Unique identifier (typically UUID)
 * @property title User-facing conversation name (auto-generated from first message or user-set)
 * @property createdAt Creation timestamp (immutable after insert)
 * @property updatedAt Last modified timestamp (updated on any conversation change)
 * @property isArchived Whether conversation is archived (default: false)
 *
 * @see Conversation Domain model (presentation layer)
 * @see MessageEntity Child entity (messages in conversation)
 */
@Entity(tableName = "conversations")
data class ConversationEntity(
    @PrimaryKey val id: String,
    val title: String,
    val createdAt: Long,
    val updatedAt: Long,
    val isArchived: Boolean = false
) {
    /**
     * Convert database entity to domain model.
     *
     * **Mapping:**
     * - Entity fields → Domain fields (1:1)
     * - Messages are provided separately (loaded by DAO.getMessages)
     * - Empty messages list if not loaded
     *
     * **Use Case:**
     * Called by repository after loading entity from database.
     * Messages are loaded separately and composed here.
     *
     * @param messages Messages in this conversation (default empty)
     *                  Must be loaded via DAO.getMessages(id)
     *
     * @return [Conversation] domain model (for use layer)
     */
    fun toDomain(messages: List<MessageEntity> = emptyList()): Conversation =
        Conversation(
            id = id,
            title = title,
            messages = messages.map { it.toDomain() },
            createdAt = createdAt,
            updatedAt = updatedAt,
            isArchived = isArchived
        )

    companion object {
        /**
         * Convert domain model to database entity.
         *
         * **Mapping:**
         * - Domain fields → Entity fields (1:1)
         * - Messages are NOT included (stored separately)
         *
         * **Use Case:**
         * Called before inserting conversation into database.
         * Messages must be inserted separately via DAO.insertMessage().
         *
         * @param conversation [Conversation] domain model
         *
         * @return [ConversationEntity] database entity
         */
        fun fromDomain(conversation: Conversation): ConversationEntity =
            ConversationEntity(
                id = conversation.id,
                title = conversation.title,
                createdAt = conversation.createdAt,
                updatedAt = conversation.updatedAt,
                isArchived = conversation.isArchived
            )
    }
}
