package com.savia.domain.usecase

import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.domain.model.StreamDelta
import com.savia.domain.repository.ChatRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.onStart
import java.util.UUID

/**
 * Use case for sending a message to Claude and receiving a streaming response.
 *
 * This is a Clean Architecture use case that orchestrates the business logic flow:
 * 1. Create a domain model for the user's message
 * 2. Save the user message to local storage immediately
 * 3. Send the message to Claude via the Bridge and stream the response
 * 4. Return streaming events to the presenter/view model
 *
 * ## Separation of Concerns
 * - The use case does NOT handle UI state or error display (that's the presenter's job)
 * - The use case does NOT directly access the network (that's the repository's job)
 * - The use case defines the business rule: always persist the user's message before the response
 *
 * ## Streaming Architecture
 * This use case returns a Flow of [StreamDelta] events that the UI observes:
 * - [StreamDelta.Start]: Stream begins, message ID available
 * - [StreamDelta.Text]: Chunks of response text arrive
 * - [StreamDelta.Done] or [StreamDelta.Error]: Stream ends
 *
 * The Flow is "hot" because it starts executing as soon as it's created,
 * but the repository's sendMessage should not emit until someone subscribes.
 *
 * ## Message Persistence
 * The user message is persisted synchronously before the response stream begins.
 * This ensures the user's message is never lost, even if the network request fails.
 * The assistant's message is persisted incrementally as [StreamDelta.Text] events arrive.
 */
class SendMessageUseCase(
    private val chatRepository: ChatRepository
) {
    /**
     * Execute the use case to send a message and stream the response.
     *
     * @param conversationId Target conversation for the message
     * @param userContent The user's message text
     * @param systemPrompt Optional system message to set context/tone (passed to Bridge)
     * @return Flow of streaming events from Claude
     *
     * @throws IllegalArgumentException if conversationId or userContent is invalid
     * @throws IOException if network or persistence fails (emitted on the Flow)
     */
    operator fun invoke(
        conversationId: String,
        userContent: String,
        systemPrompt: String? = null
    ): Flow<StreamDelta> {
        val userMessage = Message(
            id = UUID.randomUUID().toString(),
            conversationId = conversationId,
            role = MessageRole.USER,
            content = userContent
        )

        return chatRepository.sendMessage(
            conversationId = conversationId,
            content = userContent,
            systemPrompt = systemPrompt
        ).onStart {
            chatRepository.saveMessage(userMessage)
        }
    }
}
