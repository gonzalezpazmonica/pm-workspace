package com.savia.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import com.savia.data.local.entity.ConversationEntity
import com.savia.data.local.entity.MessageEntity
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for conversations and messages.
 *
 * **Architecture:**
 * - Abstraction layer between repository and Room database
 * - All I/O operations are suspend functions (thread-safe on Dispatchers.Default)
 * - Query operations return Flow<T> for reactive updates
 * - Repository wraps Flow in domain models (Conversation, Message)
 *
 * **Reactive Pattern:**
 * - getAll() and getById() return Flow (listen to changes)
 * - getMessages() returns Flow (auto-refresh when messages added)
 * - Updates trigger Flow emissions (UI re-renders automatically)
 *
 * **Conflict Strategy:**
 * - onConflict = REPLACE (idempotent inserts, no duplicates)
 * - Safe for retry scenarios and out-of-order updates
 *
 * **Timestamps:**
 * - createdAt: Set only on insertion (never changes)
 * - updatedAt: Updated on any conversation modification (used for sorting)
 * - Message timestamps: Set by sender (client or API)
 *
 * **Archive Semantics:**
 * - isArchived=0: Active conversation (shown in list)
 * - isArchived=1: Archived conversation (hidden by default)
 * - Hard delete (deleteConversation) removes all data permanently
 * - Foreign key cascade: Deleting conversation deletes all messages
 *
 * @see ConversationEntity Schema for conversations table
 * @see MessageEntity Schema for messages table (includes FK to conversations)
 */
@Dao
interface ConversationDao {

    /**
     * Get all active (non-archived) conversations, newest first.
     *
     * **Query:**
     * ```sql
     * SELECT * FROM conversations WHERE isArchived = 0 ORDER BY updatedAt DESC
     * ```
     *
     * **Reactivity:**
     * Emits current state on subscription.
     * Re-emits whenever conversations are inserted/updated/deleted.
     *
     * **Performance:**
     * - Indexed on isArchived implicitly (Room creates indexes)
     * - OrderBy updatedAt is fast with index or small dataset
     * - Suitable for conversation list (usually <100 conversations)
     *
     * @return Flow<List<ConversationEntity>> Reactive list of active conversations
     *         Empty list if no conversations exist
     *         Completes when Flow is cancelled
     */
    @Query("SELECT * FROM conversations WHERE isArchived = 0 ORDER BY updatedAt DESC")
    fun getAll(): Flow<List<ConversationEntity>>

    /**
     * Get a single conversation by ID.
     *
     * **Query:**
     * ```sql
     * SELECT * FROM conversations WHERE id = :id
     * ```
     *
     * **Null Semantics:**
     * - Returns Flow<null> if conversation not found (not a Flow<null> error)
     * - Safe for reactive UI (no exception thrown)
     * - Repository handles null → show "not found" or empty state
     *
     * @param id Conversation ID (primary key)
     *
     * @return Flow<ConversationEntity?> Single conversation or null
     *         Emits when conversation is updated
     */
    @Query("SELECT * FROM conversations WHERE id = :id")
    fun getById(id: String): Flow<ConversationEntity?>

    /**
     * Get all messages in a conversation, oldest first.
     *
     * **Query:**
     * ```sql
     * SELECT * FROM messages WHERE conversationId = :conversationId ORDER BY timestamp ASC
     * ```
     *
     * **Ordering:**
     * - Ascending by timestamp (oldest message first)
     * - Matches chat UI display order (top: old, bottom: new)
     *
     * **Performance:**
     * - conversationId is indexed (DAO @Index annotation on MessageEntity)
     * - Efficient even with thousands of messages per conversation
     *
     * **Reactivity:**
     * Re-emits whenever messages are added/updated in conversation.
     *
     * @param conversationId Conversation ID (foreign key)
     *
     * @return Flow<List<MessageEntity>> All messages in conversation
     *         Empty list if no messages
     *         Emits when new messages added
     */
    @Query("SELECT * FROM messages WHERE conversationId = :conversationId ORDER BY timestamp ASC")
    fun getMessages(conversationId: String): Flow<List<MessageEntity>>

    /**
     * Insert or replace a conversation.
     *
     * **Conflict Strategy:** REPLACE
     * - If conversation with same ID exists: update all fields
     * - No exception thrown
     * - Safe for retry scenarios
     *
     * **Idempotency:**
     * Calling twice with same data is safe (second call is no-op).
     *
     * **Suspend Context:**
     * Call within a coroutine. Blocks on database I/O.
     *
     * @param conversation Conversation to insert/update
     *                      ID must be non-null and unique
     *
     * @throws SQLiteConstraintException if ID is null (Room validates)
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertConversation(conversation: ConversationEntity)

    /**
     * Insert or replace a message.
     *
     * **Conflict Strategy:** REPLACE (same semantics as insertConversation)
     *
     * **Foreign Key Check:**
     * The conversationId must reference an existing conversation.
     * If conversation not found: SQLiteConstraintException is thrown.
     *
     * @param message Message to insert
     *                ID and conversationId must be non-null
     *
     * @throws SQLiteConstraintException if conversationId doesn't exist
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMessage(message: MessageEntity)

    /**
     * Update conversation title and timestamp.
     *
     * **Query:**
     * ```sql
     * UPDATE conversations SET title = :title, updatedAt = :updatedAt WHERE id = :id
     * ```
     *
     * **Default Behavior:**
     * - updatedAt defaults to System.currentTimeMillis() if not provided
     * - Automatically reflects "last modified" time in UI sorting
     *
     * **Use Case:**
     * Called after first message (to set auto-generated title) or user rename.
     *
     * @param id Conversation ID (WHERE clause)
     * @param title New conversation title (user-facing)
     * @param updatedAt Timestamp of update (defaults to now)
     */
    @Query("UPDATE conversations SET title = :title, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateTitle(id: String, title: String, updatedAt: Long = System.currentTimeMillis())

    /**
     * Update conversation's last-modified timestamp.
     *
     * **Query:**
     * ```sql
     * UPDATE conversations SET updatedAt = :updatedAt WHERE id = :id
     * ```
     *
     * **Purpose:**
     * Marks conversation as recently active (moves to top of list).
     * Called when new message is added.
     *
     * **Default Behavior:**
     * updatedAt defaults to System.currentTimeMillis() if not provided.
     *
     * @param id Conversation ID
     * @param updatedAt Timestamp (defaults to now)
     */
    @Query("UPDATE conversations SET updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateTimestamp(id: String, updatedAt: Long = System.currentTimeMillis())

    /**
     * Permanently delete a conversation and all its messages.
     *
     * **Query:**
     * ```sql
     * DELETE FROM conversations WHERE id = :id
     * ```
     *
     * **Cascade Behavior:**
     * Deleting conversation triggers ON DELETE CASCADE for all messages.
     * All messages in the conversation are also deleted.
     *
     * **Irreversible:**
     * This is a hard delete (not archiving). Data is permanently lost.
     * Consider suggesting "Archive" UI instead of "Delete".
     *
     * @param id Conversation ID to delete
     */
    @Query("DELETE FROM conversations WHERE id = :id")
    suspend fun deleteConversation(id: String)

    /**
     * Get count of active (non-archived) conversations.
     *
     * **Query:**
     * ```sql
     * SELECT COUNT(*) FROM conversations WHERE isArchived = 0
     * ```
     *
     * **Use Case:**
     * Show "You have N conversations" in empty state.
     * Fast count query (SQLite optimizes COUNT).
     *
     * @return Number of non-archived conversations (0 if none)
     */
    @Query("SELECT COUNT(*) FROM conversations WHERE isArchived = 0")
    suspend fun getConversationCount(): Int
}
