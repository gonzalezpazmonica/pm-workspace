package com.savia.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.savia.data.local.dao.ConversationDao
import com.savia.data.local.entity.ConversationEntity
import com.savia.data.local.entity.MessageEntity

/**
 * Room database for Savia mobile app.
 *
 * **Architecture:**
 * - Provides local persistence for conversations and messages
 * - Singleton instance created via Hilt dependency injection
 * - Encrypted database (password from [SecurityRepositoryImpl.getDatabasePassphrase])
 * - No automatic migrations (version 1, schema exported)
 *
 * **Entities:**
 * - [ConversationEntity]: Conversations with metadata (title, timestamps, archive flag)
 * - [MessageEntity]: Messages with foreign key to conversations (cascading delete)
 *
 * **Indexing:**
 * - Conversations: Primary key (id) indexed by default
 * - Messages: Indexed on conversationId (Query in DAO uses this for efficient lookups)
 *
 * **Encryption:**
 * SQLite database file is encrypted with AES-256 using SQLCipher.
 * Passphrase is derived from secure storage (managed by TinkKeyManager).
 *
 * **Room Version:**
 * - Current: 1 (no migrations needed yet)
 * - Schema exported to git (track changes over time)
 * - Future versions: Create new migration classes (Migration_1_2.kt, etc.)
 *
 * **Lifecycle:**
 * - Created once per app process (singleton)
 * - Accessed only through ConversationDao
 * - Closed automatically when app terminates
 *
 * @see ConversationEntity Database schema for conversations table
 * @see MessageEntity Database schema for messages table
 * @see ConversationDao Data access operations
 */
@Database(
    entities = [
        ConversationEntity::class,
        MessageEntity::class
    ],
    version = 1,
    exportSchema = true
)
abstract class SaviaDatabase : RoomDatabase() {
    /**
     * Provides access to conversation and message operations.
     *
     * **Usage:**
     * Database instance is typically accessed via [SecurityRepositoryImpl]
     * and [ChatRepositoryImpl], not directly by UI code.
     *
     * @return [ConversationDao] for CRUD operations on conversations and messages
     */
    abstract fun conversationDao(): ConversationDao
}
