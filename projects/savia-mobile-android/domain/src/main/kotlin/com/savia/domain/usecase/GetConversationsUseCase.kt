package com.savia.domain.usecase

import com.savia.domain.model.Conversation
import com.savia.domain.repository.ChatRepository
import kotlinx.coroutines.flow.Flow

/**
 * Use case for retrieving all conversations for the current user.
 *
 * This is a Clean Architecture use case that provides a thin abstraction over repository
 * access. It demonstrates the case where the use case mostly delegates to the repository
 * because there is minimal business logic needed (no orchestration, validation, or transformation).
 *
 * ## Reactive Streaming
 * Returns a Flow that emits an updated list whenever:
 * - New conversations are created
 * - A conversation's title or update timestamp changes
 * - Conversations are deleted/archived
 *
 * The Flow is cold and hot depending on the repository implementation. Typically,
 * the underlying Room query is cold (starts executing on each subscription), but
 * may be transformed to hot using [shareIn] in the data layer.
 *
 * ## Sort Order
 * The repository returns conversations in reverse chronological order (most recent first).
 * This is a business rule that should be consistent across all calls.
 *
 * ## UI Binding
 * The presenter/view model should collect from this Flow and update the UI whenever
 * new data arrives. In Jetpack Compose, use [androidx.compose.runtime.produceState] or
 * similar to bind the Flow to the UI state.
 */
class GetConversationsUseCase(
    private val chatRepository: ChatRepository
) {
    /**
     * Execute the use case to fetch all conversations.
     *
     * @return Flow of conversation lists (most recent first)
     */
    operator fun invoke(): Flow<List<Conversation>> =
        chatRepository.getConversations()
}
