package com.savia.mobile

import com.google.common.truth.Truth.assertThat
import com.savia.domain.model.Conversation
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.domain.model.StreamDelta
import com.savia.domain.repository.ChatRepository
import com.savia.domain.repository.SecurityRepository
import com.savia.domain.usecase.SendMessageUseCase
import com.savia.mobile.notification.SaviaNotificationManager
import com.savia.mobile.ui.chat.ChatViewModel
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var viewModel: ChatViewModel
    private lateinit var fakeChatRepo: FakeChatRepo
    private lateinit var fakeSecurityRepo: FakeSecurityRepo

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        fakeChatRepo = FakeChatRepo()
        fakeSecurityRepo = FakeSecurityRepo(hasKey = true)
        viewModel = ChatViewModel(
            sendMessageUseCase = SendMessageUseCase(fakeChatRepo),
            chatRepository = fakeChatRepo,
            securityRepository = fakeSecurityRepo,
            notificationManager = mockk(relaxed = true),
            bridgeService = mockk(relaxed = true)
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial state has no messages`() = runTest {
        advanceUntilIdle()
        assertThat(viewModel.uiState.value.messages).isEmpty()
        assertThat(viewModel.uiState.value.isStreaming).isFalse()
    }

    @Test
    fun `isConfigured reflects security repository`() = runTest {
        advanceUntilIdle()
        assertThat(viewModel.uiState.value.isConfigured).isTrue()
    }

    @Test
    fun `startNewConversation creates conversation and resets messages`() = runTest {
        viewModel.startNewConversation()
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.currentConversationId).isNotNull()
        assertThat(viewModel.uiState.value.messages).isEmpty()
    }

    @Test
    fun `saveApiKey updates state`() = runTest {
        fakeSecurityRepo = FakeSecurityRepo(hasKey = false)
        viewModel = ChatViewModel(
            sendMessageUseCase = SendMessageUseCase(fakeChatRepo),
            chatRepository = fakeChatRepo,
            securityRepository = fakeSecurityRepo,
            notificationManager = mockk(relaxed = true),
            bridgeService = mockk(relaxed = true)
        )
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.isConfigured).isFalse()

        viewModel.saveApiKey("sk-test-key")
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.isConfigured).isTrue()
    }

    @Test
    fun `clearError resets error state`() = runTest {
        advanceUntilIdle()
        viewModel.clearError()

        assertThat(viewModel.uiState.value.error).isNull()
    }
}

// --- Fakes ---

private class FakeChatRepo : ChatRepository {
    var streamResponse: Flow<StreamDelta> = flowOf(StreamDelta.Done)
    private var conversationCounter = 0

    override fun sendMessage(conversationId: String, content: String, systemPrompt: String?) = streamResponse
    override fun getConversations() = flowOf(emptyList<Conversation>())
    override fun getConversation(id: String) = flowOf<Conversation?>(null)
    override fun getMessages(conversationId: String) = flowOf(emptyList<Message>())
    override suspend fun createConversation(title: String) =
        Conversation(id = "conv_${++conversationCounter}", title = title)
    override suspend fun saveMessage(message: Message) {}
    override suspend fun deleteConversation(id: String) {}
    override suspend fun updateConversationTitle(id: String, title: String) {}
}

private class FakeSecurityRepo(private var hasKey: Boolean) : SecurityRepository {
    private var savedKey: String? = if (hasKey) "test-key" else null

    override suspend fun saveApiKey(key: String) { savedKey = key }
    override suspend fun getApiKey() = savedKey
    override suspend fun deleteApiKey() { savedKey = null }
    override suspend fun hasApiKey() = savedKey != null
    override suspend fun saveLastConversationId(id: String) {}
    override suspend fun getLastConversationId(): String? = null
    override suspend fun clearLastConversationId() {}
    override suspend fun getDatabasePassphrase() = ByteArray(32)
    override suspend fun saveBridgeConfig(host: String, port: Int, token: String, username: String) {}
    override suspend fun getBridgeUsername(): String? = null
    override suspend fun getBridgeHost(): String? = null
    override suspend fun getBridgePort(): Int? = null
    override suspend fun getBridgeToken(): String? = null
    override suspend fun hasBridgeConfig(): Boolean = false
    override suspend fun deleteBridgeConfig() {}
    override suspend fun saveTheme(theme: String) {}
    override suspend fun getTheme(): String? = null
    override suspend fun saveLanguage(language: String) {}
    override suspend fun getLanguage(): String? = null
}
