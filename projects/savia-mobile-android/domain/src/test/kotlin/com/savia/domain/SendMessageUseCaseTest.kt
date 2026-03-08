package com.savia.domain

import com.google.common.truth.Truth.assertThat
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.domain.model.StreamDelta
import com.savia.domain.repository.ChatRepository
import com.savia.domain.usecase.SendMessageUseCase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test

class SendMessageUseCaseTest {

    private lateinit var useCase: SendMessageUseCase
    private lateinit var fakeRepository: FakeChatRepository

    @Before
    fun setup() {
        fakeRepository = FakeChatRepository()
        useCase = SendMessageUseCase(fakeRepository)
    }

    @Test
    fun `invoke emits stream deltas from repository`() = runTest {
        fakeRepository.streamResponse = flowOf(
            StreamDelta.Start("msg_123", "claude-sonnet-4-20250514"),
            StreamDelta.Text("Hello"),
            StreamDelta.Text(" world"),
            StreamDelta.Done
        )

        val result = useCase("conv_1", "Hi Savia").toList()

        assertThat(result).hasSize(4)
        assertThat(result[0]).isInstanceOf(StreamDelta.Start::class.java)
        assertThat((result[1] as StreamDelta.Text).text).isEqualTo("Hello")
        assertThat((result[2] as StreamDelta.Text).text).isEqualTo(" world")
        assertThat(result[3]).isEqualTo(StreamDelta.Done)
    }

    @Test
    fun `invoke saves user message before streaming`() = runTest {
        fakeRepository.streamResponse = flowOf(StreamDelta.Done)

        useCase("conv_1", "Test message").toList()

        assertThat(fakeRepository.savedMessages).hasSize(1)
        assertThat(fakeRepository.savedMessages[0].role).isEqualTo(MessageRole.USER)
        assertThat(fakeRepository.savedMessages[0].content).isEqualTo("Test message")
        assertThat(fakeRepository.savedMessages[0].conversationId).isEqualTo("conv_1")
    }

    @Test
    fun `invoke passes system prompt to repository`() = runTest {
        fakeRepository.streamResponse = flowOf(StreamDelta.Done)

        useCase("conv_1", "Hello", systemPrompt = "You are helpful").toList()

        assertThat(fakeRepository.lastSystemPrompt).isEqualTo("You are helpful")
    }
}

/**
 * Fake implementation for testing — avoids mocking framework dependency in domain module.
 */
private class FakeChatRepository : ChatRepository {
    var streamResponse: Flow<StreamDelta> = flowOf(StreamDelta.Done)
    var savedMessages = mutableListOf<Message>()
    var lastSystemPrompt: String? = null

    override fun sendMessage(
        conversationId: String,
        content: String,
        systemPrompt: String?
    ): Flow<StreamDelta> {
        lastSystemPrompt = systemPrompt
        return streamResponse
    }

    override fun getConversations() = flowOf(emptyList<com.savia.domain.model.Conversation>())
    override fun getConversation(id: String) = flowOf(null)
    override fun getMessages(conversationId: String) = flowOf(emptyList<Message>())
    override suspend fun createConversation(title: String) =
        com.savia.domain.model.Conversation(id = "test", title = title)
    override suspend fun saveMessage(message: Message) { savedMessages.add(message) }
    override suspend fun deleteConversation(id: String) {}
    override suspend fun updateConversationTitle(id: String, title: String) {}
}
