package com.savia.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.savia.data.local.dao.ConversationDao
import com.savia.data.local.dao.SavedOutputDao
import com.savia.data.local.entity.ConversationEntity
import com.savia.data.local.entity.MessageEntity
import com.savia.data.local.entity.SavedOutputEntity

/**
 * Room database for Savia mobile app.
 *
 * **Entities:**
 * - [ConversationEntity]: Conversations with metadata (title, timestamps, archive flag)
 * - [MessageEntity]: Messages with foreign key to conversations (cascading delete)
 * - [SavedOutputEntity]: Persisted Claude outputs (code, reports, snippets)
 *
 * **Encryption:**
 * SQLite database file is encrypted with AES-256 using SQLCipher.
 * Passphrase is derived from secure storage (managed by TinkKeyManager).
 *
 * **Versions:**
 * - v1: conversations + messages
 * - v2: added saved_outputs table for output persistence
 */
@Database(
    entities = [
        ConversationEntity::class,
        MessageEntity::class,
        SavedOutputEntity::class
    ],
    version = 2,
    exportSchema = true
)
abstract class SaviaDatabase : RoomDatabase() {
    /** Conversations and messages CRUD. */
    abstract fun conversationDao(): ConversationDao

    /** Saved outputs CRUD. */
    abstract fun savedOutputDao(): SavedOutputDao

    companion object {
        /** Migration from v1 to v2: add saved_outputs table. */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `saved_outputs` (
                        `id` TEXT NOT NULL PRIMARY KEY,
                        `conversationId` TEXT NOT NULL,
                        `messageId` TEXT NOT NULL,
                        `type` TEXT NOT NULL,
                        `title` TEXT NOT NULL,
                        `content` TEXT NOT NULL,
                        `language` TEXT,
                        `createdAt` INTEGER NOT NULL DEFAULT 0,
                        `isFavorite` INTEGER NOT NULL DEFAULT 0,
                        FOREIGN KEY(`conversationId`) REFERENCES `conversations`(`id`) ON DELETE CASCADE
                    )
                """.trimIndent())
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_saved_outputs_conversationId` ON `saved_outputs` (`conversationId`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_saved_outputs_type` ON `saved_outputs` (`type`)")
            }
        }
    }
}
