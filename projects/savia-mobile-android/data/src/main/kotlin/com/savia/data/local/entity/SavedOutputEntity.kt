package com.savia.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Room entity for Claude-generated outputs that users want to keep.
 *
 * Persists structured outputs (code snippets, reports, action items, etc.)
 * extracted from assistant messages so they can be browsed, searched,
 * and exported independently of the chat conversation.
 *
 * @property id Unique output ID (UUID)
 * @property conversationId Parent conversation reference
 * @property messageId Source assistant message that produced this output
 * @property type Output type: "code", "markdown", "action_items", "report", "snippet"
 * @property title User-visible title (auto-generated or user-provided)
 * @property content The saved content (full text)
 * @property language Programming language if type="code" (e.g., "kotlin", "python")
 * @property createdAt Timestamp when output was saved
 * @property isFavorite Whether user marked as favorite for quick access
 */
@Entity(
    tableName = "saved_outputs",
    foreignKeys = [
        ForeignKey(
            entity = ConversationEntity::class,
            parentColumns = ["id"],
            childColumns = ["conversationId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("conversationId"), Index("type")]
)
data class SavedOutputEntity(
    @PrimaryKey val id: String,
    val conversationId: String,
    val messageId: String,
    val type: String,
    val title: String,
    val content: String,
    val language: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val isFavorite: Boolean = false
)
