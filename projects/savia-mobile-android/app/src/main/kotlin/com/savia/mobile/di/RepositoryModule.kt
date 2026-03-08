package com.savia.mobile.di

import com.savia.data.repository.ChatRepositoryImpl
import com.savia.data.repository.ProjectRepositoryImpl
import com.savia.data.repository.SecurityRepositoryImpl
import com.savia.data.repository.UpdateRepositoryImpl
import com.savia.domain.repository.ChatRepository
import com.savia.domain.repository.ProjectRepository
import com.savia.domain.repository.SecurityRepository
import com.savia.domain.repository.UpdateRepository
import com.savia.domain.usecase.GetConversationsUseCase
import com.savia.domain.usecase.SendMessageUseCase
import com.savia.mobile.update.UpdateManager
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Dependency injection module for repositories and use cases.
 *
 * Provides abstract bindings for domain repository interfaces to their implementation classes,
 * and factory methods for creating use cases. Repositories are singleton-scoped to ensure
 * consistent state across the application.
 *
 * @author Savia Mobile Team
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    /**
     * Binds ChatRepository interface to its implementation.
     *
     * ChatRepositoryImpl handles all chat-related data operations:
     * - creating and loading conversations
     * - retrieving messages
     * - sending messages via Claude API or Bridge
     * - managing conversation persistence in local database
     *
     * @param impl ChatRepositoryImpl instance to bind
     * @return ChatRepository interface
     */
    @Binds
    @Singleton
    abstract fun bindChatRepository(impl: ChatRepositoryImpl): ChatRepository

    /**
     * Binds SecurityRepository interface to its implementation.
     *
     * SecurityRepositoryImpl manages sensitive data:
     * - Bridge connection configuration (host, port, auth token)
     * - Claude API key
     * - Last viewed conversation ID for session restoration
     * - Encrypted storage via EncryptedSharedPreferences
     *
     * @param impl SecurityRepositoryImpl instance to bind
     * @return SecurityRepository interface
     */
    @Binds
    @Singleton
    abstract fun bindSecurityRepository(impl: SecurityRepositoryImpl): SecurityRepository

    /**
     * Binds UpdateRepository interface to its implementation.
     *
     * UpdateRepositoryImpl manages app updates:
     * - Checking for available updates from Bridge server
     * - Downloading APK files with progress tracking
     * - Managing cached APK storage in app cache directory
     *
     * @param impl UpdateRepositoryImpl instance to bind
     * @return UpdateRepository interface
     */
    @Binds
    @Singleton
    abstract fun bindUpdateRepository(impl: UpdateRepositoryImpl): UpdateRepository

    /**
     * Binds ProjectRepository interface to its implementation.
     *
     * ProjectRepositoryImpl manages workspace data:
     * - Project listing and selection
     * - Sprint summaries and board state
     * - Command execution via Bridge
     * - User profile and time tracking
     * - Backlog capture and approvals
     *
     * @param impl ProjectRepositoryImpl instance to bind
     * @return ProjectRepository interface
     */
    @Binds
    @Singleton
    abstract fun bindProjectRepository(impl: ProjectRepositoryImpl): ProjectRepository

    companion object {
        /**
         * Creates SendMessageUseCase for sending user messages and streaming Claude responses.
         *
         * Encapsulates the business logic of:
         * - validating message content
         * - determining whether to use Bridge or direct API
         * - streaming responses with progress updates
         * - persisting messages to database
         *
         * @param chatRepository repository for message persistence and API communication
         * @return SendMessageUseCase instance
         */
        @Provides
        fun provideSendMessageUseCase(chatRepository: ChatRepository): SendMessageUseCase =
            SendMessageUseCase(chatRepository)

        /**
         * Creates GetConversationsUseCase for retrieving the conversation list.
         *
         * Fetches all persisted conversations from the local database as a Flow
         * to enable reactive updates when new conversations are created.
         *
         * @param chatRepository repository for querying conversation data
         * @return GetConversationsUseCase instance
         */
        @Provides
        fun provideGetConversationsUseCase(chatRepository: ChatRepository): GetConversationsUseCase =
            GetConversationsUseCase(chatRepository)

    }
}
