package com.savia.mobile.integration

import android.content.Context
import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.savia.data.api.ClaudeApiService
import com.savia.data.api.ClaudeStreamParser
import com.savia.data.api.SaviaBridgeService
import com.savia.data.local.SaviaDatabase
import com.savia.data.local.dao.ConversationDao
import com.savia.data.repository.ChatRepositoryImpl
import com.savia.domain.model.MessageRole
import com.savia.domain.repository.SecurityRepository
import com.savia.domain.usecase.SendMessageUseCase
import com.savia.mobile.ui.chat.ChatViewModel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit

/**
 * Integration tests for ChatViewModel with real dependencies.
 *
 * Stack: ChatViewModel → SendMessageUseCase → ChatRepositoryImpl →
 *        MockWebServer (API) + In-Memory Room DB
 *
 * Verifies the full vertical slice from UI state to network+database:
 * - ViewModel state transitions during message sending
 * - Streaming text accumulation in UI state
 * - Messages persisted to database after stream completes
 * - Conversation lifecycle (create, load, delete)
 * - Error handling with API key validation
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], manifest = Config.NONE)
class ChatViewModelIntegrationTest {

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private val testDispatcher = UnconfinedTestDispatcher()
    private lateinit var mockWebServer: MockWebServer
    private lateinit var database: SaviaDatabase
    private lateinit var dao: ConversationDao
    private lateinit var viewModel: ChatViewModel
    private lateinit var fakeSecurityRepo: InMemorySecurityRepository

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)

        mockWebServer = MockWebServer()
        mockWebServer.start()

        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, SaviaDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        dao = database.conversationDao()

        fakeSecurityRepo = InMemorySecurityRepository("sk-test-key")

        val apiService = createApiService()
        val client = OkHttpClient.Builder().build()
        val bridgeService = SaviaBridgeService(client, json)
        val streamParser = ClaudeStreamParser()
        val chatRepository = ChatRepositoryImpl(apiService, bridgeService, streamParser, dao, fakeSecurityRepo)
        val sendMessageUseCase = SendMessageUseCase(chatRepository)

        viewModel = ChatViewModel(sendMessageUseCase, chatRepository, fakeSecurityRepo)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        database.close()
        mockWebServer.shutdown()
    }

    // --- Initial State ---

    @Test
    fun `initial state has API key and no messages`() = runTest {
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.isConfigured).isTrue()
        assertThat(state.messages).isEmpty()
        assertThat(state.isStreaming).isFalse()
        assertThat(state.streamingText).isEmpty()
        assertThat(state.error).isNull()
    }

    @Test
    fun `initial state without API key`() = runTest {
        // Rebuild with no API key
        fakeSecurityRepo = InMemorySecurityRepository(null)
        val apiService = createApiService()
        val client = OkHttpClient.Builder().build()
        val chatRepository = ChatRepositoryImpl(apiService, SaviaBridgeService(client, json), ClaudeStreamParser(), dao, fakeSecurityRepo)
        viewModel = ChatViewModel(SendMessageUseCase(chatRepository), chatRepository, fakeSecurityRepo)

        advanceUntilIdle()

        assertThat(viewModel.uiState.value.isConfigured).isFalse()
    }

    // --- Conversation Lifecycle ---

    @Test
    fun `startNewConversation creates conversation and resets state`() = runTest {
        advanceUntilIdle()

        viewModel.startNewConversation()
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.currentConversationId).isNotNull()
        assertThat(state.messages).isEmpty()
        assertThat(state.error).isNull()
    }

    @Test
    fun `sending message auto-creates conversation if none exists`() = runTest {
        advanceUntilIdle()
        enqueueStreamingResponse("Hello!")

        assertThat(viewModel.uiState.value.currentConversationId).isNull()

        viewModel.sendMessage("Hi")
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.currentConversationId).isNotNull()
    }

    @Test
    fun `deleteConversation clears current state`() = runTest {
        advanceUntilIdle()

        viewModel.startNewConversation()
        advanceUntilIdle()

        val conversationId = viewModel.uiState.value.currentConversationId!!

        viewModel.deleteConversation(conversationId)
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.currentConversationId).isNull()
        assertThat(viewModel.uiState.value.messages).isEmpty()
    }

    // --- Message Sending with Real API ---

    @Test
    fun `sendMessage adds user message to state immediately`() = runTest {
        advanceUntilIdle()
        viewModel.startNewConversation()
        advanceUntilIdle()

        enqueueStreamingResponse("Response from Savia")

        viewModel.sendMessage("Hello Savia!")
        awaitStreamingComplete()

        val state = viewModel.uiState.value
        val userMessages = state.messages.filter { it.role == MessageRole.USER }
        assertThat(userMessages).isNotEmpty()
        assertThat(userMessages[0].content).isEqualTo("Hello Savia!")
    }

    @Test
    fun `sendMessage accumulates streaming text then creates final message`() = runTest {
        advanceUntilIdle()
        viewModel.startNewConversation()
        advanceUntilIdle()

        enqueueStreamingResponse("Savia responding with care")

        viewModel.sendMessage("Tell me something")
        awaitStreamingComplete()

        val state = viewModel.uiState.value
        // After completion, streaming text should be cleared
        assertThat(state.isStreaming).isFalse()
        assertThat(state.streamingText).isEmpty()

        // Assistant message should be in the message list
        val assistantMessages = state.messages.filter { it.role == MessageRole.ASSISTANT }
        assertThat(assistantMessages).hasSize(1)
        assertThat(assistantMessages[0].content).isEqualTo("Savia responding with care")
    }

    @Test
    fun `multi-turn conversation preserves all messages in state`() = runTest {
        advanceUntilIdle()
        viewModel.startNewConversation()
        advanceUntilIdle()

        // Turn 1
        enqueueStreamingResponse("I'm Savia!")
        viewModel.sendMessage("Who are you?")
        awaitStreamingComplete()

        // Turn 2
        enqueueStreamingResponse("The sprint is going well.")
        viewModel.sendMessage("Sprint status?")
        awaitStreamingComplete()

        val state = viewModel.uiState.value
        assertThat(state.messages).hasSize(4) // 2 user + 2 assistant
        assertThat(state.messages[0].role).isEqualTo(MessageRole.USER)
        assertThat(state.messages[0].content).isEqualTo("Who are you?")
        assertThat(state.messages[1].role).isEqualTo(MessageRole.ASSISTANT)
        assertThat(state.messages[1].content).isEqualTo("I'm Savia!")
        assertThat(state.messages[2].role).isEqualTo(MessageRole.USER)
        assertThat(state.messages[2].content).isEqualTo("Sprint status?")
        assertThat(state.messages[3].role).isEqualTo(MessageRole.ASSISTANT)
        assertThat(state.messages[3].content).isEqualTo("The sprint is going well.")
    }

    // --- API Key Management ---

    @Test
    fun `saveApiKey updates isConfigured state`() = runTest {
        fakeSecurityRepo = InMemorySecurityRepository(null)
        val apiService = createApiService()
        val client = OkHttpClient.Builder().build()
        val chatRepository = ChatRepositoryImpl(apiService, SaviaBridgeService(client, json), ClaudeStreamParser(), dao, fakeSecurityRepo)
        viewModel = ChatViewModel(SendMessageUseCase(chatRepository), chatRepository, fakeSecurityRepo)

        advanceUntilIdle()
        assertThat(viewModel.uiState.value.isConfigured).isFalse()

        viewModel.saveApiKey("sk-ant-new-key")
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.isConfigured).isTrue()
    }

    // --- Error Handling ---

    @Test
    fun `sendMessage with API error sets error state`() = runTest {
        advanceUntilIdle()
        viewModel.startNewConversation()
        advanceUntilIdle()

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(500)
                .setBody("""{"type":"error","error":{"type":"api_error","message":"Internal error"}}""")
        )

        viewModel.sendMessage("This will fail")
        awaitStreamingComplete()

        val state = viewModel.uiState.value
        assertThat(state.isStreaming).isFalse()
        assertThat(state.error).isNotNull()
    }

    @Test
    fun `clearError resets error state`() = runTest {
        advanceUntilIdle()
        viewModel.startNewConversation()
        advanceUntilIdle()

        mockWebServer.enqueue(MockResponse().setResponseCode(500).setBody("{}"))
        viewModel.sendMessage("Fail")
        awaitStreamingComplete()

        assertThat(viewModel.uiState.value.error).isNotNull()

        viewModel.clearError()

        assertThat(viewModel.uiState.value.error).isNull()
    }

    @Test
    fun `blank message is ignored`() = runTest {
        advanceUntilIdle()

        val stateBefore = viewModel.uiState.value
        viewModel.sendMessage("   ")

        assertThat(viewModel.uiState.value).isEqualTo(stateBefore)
    }

    // --- Database Consistency ---

    @Test
    fun `messages sent through ViewModel are persisted in database`() = runTest {
        advanceUntilIdle()
        viewModel.startNewConversation()
        advanceUntilIdle()

        val conversationId = viewModel.uiState.value.currentConversationId!!
        enqueueStreamingResponse("Persisted response")

        viewModel.sendMessage("Persisted question")
        awaitStreamingComplete()

        // Verify directly in database
        val dbMessages = dao.getMessages(conversationId).first()
        val assistantDbMessages = dbMessages.filter { it.role == MessageRole.ASSISTANT.name }
        assertThat(assistantDbMessages).hasSize(1)
        assertThat(assistantDbMessages[0].content).isEqualTo("Persisted response")
    }

    // --- Helpers ---

    private fun createApiService(): ClaudeApiService {
        val client = OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()

        return Retrofit.Builder()
            .baseUrl(mockWebServer.url("/"))
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(ClaudeApiService::class.java)
    }

    private fun enqueueStreamingResponse(fullText: String) {
        val words = fullText.split(" ")
        val events = mutableListOf(
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_vm_test\",\"model\":\"claude-sonnet-4-20250514\",\"role\":\"assistant\"}}"
        )
        words.forEachIndexed { index, word ->
            val text = if (index < words.size - 1) "$word " else word
            events.add(
                "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"$text\"}}"
            )
        }
        events.add("event: message_stop\ndata: {\"type\":\"message_stop\"}")

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(events.joinToString("\n\n") + "\n\n")
        )
    }

    /**
     * Waits for the ViewModel to finish an async operation by polling state.
     * Uses Thread.sleep because OkHttp/MockWebServer streaming happens on real IO threads,
     * not on the test dispatcher.
     */
    private fun awaitStreamingComplete(timeoutMs: Long = 5000) {
        val start = System.currentTimeMillis()
        // Wait a bit for the operation to start
        Thread.sleep(200)
        // Then wait for streaming to finish
        while (viewModel.uiState.value.isStreaming) {
            if (System.currentTimeMillis() - start > timeoutMs) {
                throw AssertionError("Streaming did not complete within ${timeoutMs}ms")
            }
            Thread.sleep(50)
        }
        // Extra wait for state propagation after streaming completes
        Thread.sleep(200)
    }

    private class InMemorySecurityRepository(private var apiKey: String?) : SecurityRepository {
        override suspend fun saveApiKey(key: String) { apiKey = key }
        override suspend fun getApiKey(): String? = apiKey
        override suspend fun deleteApiKey() { apiKey = null }
        override suspend fun hasApiKey(): Boolean = apiKey != null
        override suspend fun saveLastConversationId(id: String) {}
        override suspend fun getLastConversationId(): String? = null
        override suspend fun clearLastConversationId() {}
        override suspend fun getDatabasePassphrase(): ByteArray = ByteArray(32)
        override suspend fun saveBridgeConfig(host: String, port: Int, token: String) {}
        override suspend fun getBridgeHost(): String? = null
        override suspend fun getBridgePort(): Int? = null
        override suspend fun getBridgeToken(): String? = null
        override suspend fun hasBridgeConfig(): Boolean = false
        override suspend fun deleteBridgeConfig() {}
    }
}
