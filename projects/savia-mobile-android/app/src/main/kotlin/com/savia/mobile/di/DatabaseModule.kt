package com.savia.mobile.di

import android.content.Context
import androidx.room.Room
import com.savia.data.local.SaviaDatabase
import com.savia.data.local.dao.ConversationDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Dependency injection module for local database.
 *
 * Provides Room database instance and Data Access Objects (DAOs) for persisting:
 * - Conversations (metadata and message history)
 * - Messages (user and assistant messages with roles and timestamps)
 *
 * Database is stored locally on device using SQLite. Future versions will integrate
 * SQLCipher for encrypted storage once the SecurityRepository provides encryption keys.
 *
 * @author Savia Mobile Team
 */
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    /**
     * Creates and configures the Savia Room database.
     *
     * Configuration:
     * - Database name: "savia.db"
     * - Fallback destructive migration: newer app versions will clear old schema
     * - Future: SQLCipher integration for encrypted storage
     *
     * @param context Android application context for database file access
     * @return singleton SaviaDatabase instance
     */
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): SaviaDatabase =
        Room.databaseBuilder(
            context,
            SaviaDatabase::class.java,
            "savia.db"
        )
        // SQLCipher integration will be added when SecurityRepository provides passphrase
        // .openHelperFactory(SupportFactory(passphrase))
        .fallbackToDestructiveMigration()
        .build()

    /**
     * Provides ConversationDao for data access operations on conversations and messages.
     *
     * Supports:
     * - querying all conversations (ordered by timestamp)
     * - retrieving messages for a specific conversation
     * - inserting new conversations and messages
     * - deleting conversations and their associated messages
     *
     * @param db SaviaDatabase instance
     * @return ConversationDao for conversation data access
     */
    @Provides
    fun provideConversationDao(db: SaviaDatabase): ConversationDao =
        db.conversationDao()
}
