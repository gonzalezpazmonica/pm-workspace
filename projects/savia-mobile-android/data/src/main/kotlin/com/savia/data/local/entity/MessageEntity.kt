package com.savia.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole

/**
 * Room entity representing a single message in a conversation.
 *
 * **Database Table:** `messages`
 *
 * **Columns:**
 * | Column | Type | Constraints | Purpose |
 * |--------|------|-------------|---------|
 * | id | TEXT | PRIMARY KEY | Unique message ID (UUID) |
 * | conversationId | TEXT | FK → conversations.id, CASCADE | Parent conversation (index for query perf) |
 * | role | TEXT | NOT NULL | "user" or "assistant" (enum stored as string) |
 * | content | TEXT | NOT NULL | Message text (can be large, no limit) |
 * | timestamp | INTEGER | NOT NULL | Unix ms (client-side or API server time) |
 * | tokenCount | INTEGER | NULL | Token count (optional, populated from API usage) |
 *
 * **Foreign Key Relationship:**
 * - Parent: ConversationEntity (conversations.id)
 * - Cascade Delete: Deleting conversation deletes all messages
 * - On Insert: Validates conversationId exists
 *
 * **Indexing:**
 * - conversationId: Index defined (efficient DAO.getMessages queries)
 * - id: Implicit (primary key)
 * - timestamp: No explicit index (Room may auto-index if frequently queried)
 *
 * **Domain Mapping:**
 * - Converts to/from domain [Message] model
 * - Enum conversion: role String ↔ MessageRole enum
 * - Unmarshalling: toDomain()
 * - Marshalling: fromDomain()
 *
 * **Timestamps:**
 * - Format: Unix milliseconds (System.currentTimeMillis() for local, API timestamp for remote)
 * - Used for ordering messages chronologically (oldest first in UI)
 *
 * **Token Count:**
 * - Nullable field (Int?)
 * - Set only for assistant messages (populated from API response)
 * - Used for tracking API usage costs
 * - Optional: Can be null if not provided by API
 *
 * **Roles:**
 * - "user": User message (sent to Claude)
 * - "assistant": Claude response (received from Claude)
 * - Stored as String (database-friendly), converted to enum in domain layer
 *
 * @property id Unique message identifier (UUID)
 * @property conversationId Reference to parent conversation (foreign key)
 * @property role Message role ("user" or "assistant")
 * @property content Message text (plain text, full message)
 * @property timestamp Creation/arrival time (Unix milliseconds)
 * @property tokenCount API token usage (optional, for billing/metrics)
 *
 * @see Message Domain model (presentation layer)
 * @see MessageRole Enum for role values
 * @see ConversationEntity Parent entity
 */
@Entity(
    tableName = "messages",
    foreignKeys = [
        ForeignKey(
            entity = ConversationEntity::class,
            parentColumns = ["id"],
            childColumns = ["conversationId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("conversationId")]
)
data class MessageEntity(
    @PrimaryKey val id: String,
    val conversationId: String,
    val role: String,
    val content: String,
    val timestamp: Long,
    val tokenCount: Int? = null
) {
    /**
     * Convert database entity to domain model.
     *
     * **Enum Conversion:**
     * - role String → MessageRole.valueOf(role)
     * - Safe: Only "user" and "assistant" values stored
     * - Throws IllegalArgumentException if invalid (data corruption)
     *
     * **Use Case:**
     * Called by repository after loading messages from DAO.
     *
     * @return [Message] domain model (for use layer)
     *
     * @throws IllegalArgumentException if role string is not "user" or "assistant"
     */
    fun toDomain(): Message =
        Message(
            id = id,
            conversationId = conversationId,
            role = MessageRole.valueOf(role),
            content = content,
            timestamp = timestamp,
            tokenCount = tokenCount
        )

    companion object {
        /**
         * Convert domain model to database entity.
         *
         * **Enum Conversion:**
         * - MessageRole enum → role.name (String)
         * - Always valid (enum source ensures correctness)
         *
         * **Use Case:**
         * Called before inserting message into database.
         *
         * @param message [Message] domain model
         *
         * @return [MessageEntity] database entity
         */
        fun fromDomain(message: Message): MessageEntity =
            MessageEntity(
                id = message.id,
                conversationId = message.conversationId,
                role = message.role.name,
                content = message.content,
                timestamp = message.timestamp,
                tokenCount = message.tokenCount
            )
    }
}
