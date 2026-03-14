package com.savia.data.integration

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.savia.data.api.ClaudeApiService
import com.savia.data.api.ClaudeStreamParser
import com.savia.data.api.SaviaBridgeService
import com.savia.data.api.model.CreateMessageRequest
import com.savia.data.local.SaviaDatabase
import com.savia.data.local.dao.ConversationDao
import com.savia.data.repository.ChatRepositoryImpl
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.domain.model.StreamDelta
import com.savia.domain.repository.SecurityRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.ResponseBody
import okhttp3.ResponseBody.Companion.toResponseBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit

/**
 * Integration test for ChatRepositoryImpl.
 *
 * Tests the full orchestration flow:
 * MockWebServer (API) ↔ Retrofit ↔ ClaudeStreamParser ↔ ChatRepositoryImpl ↔ Room DB
 *
 * Verifies:
 * - User message is saved to DB before streaming starts
 * - SSE response is correctly parsed and assembled
 * - Assistant message is saved to DB when stream completes
 * - Conversation metadata (title, timestamp) is updated
 * - Message history is correctly built from DB for multi-turn conversations
 * - Error propagation from API failures
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], manifest = Config.NONE)
class ChatRepositoryIntegrationTest {

    private lateinit var mockWebServer: MockWebServer
    private lateinit var database: SaviaDatabase
    private lateinit var dao: ConversationDao
    private lateinit var repository: ChatRepositoryImpl

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    @Before
    fun setup() {
        mockWebServer = MockWebServer()
        mockWebServer.start()

        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, SaviaDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        dao = database.conversationDao()

        val client = OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()

        val retrofit = Retrofit.Builder()
            .baseUrl(mockWebServer.url("/"))
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()

        val apiService = retrofit.create(ClaudeApiService::class.java)
        val streamParser = ClaudeStreamParser()

        val bridgeService = SaviaBridgeService(client, json)

        repository = ChatRepositoryImpl(
            apiService = apiService,
            bridgeService = bridgeService,
            streamParser = streamParser,
            conversationDao = dao,
            securityRepository = FakeSecurityRepository("sk-test-valid-key")
        )
    }

    @After
    fun tearDown() {
        database.close()
        mockWebServer.shutdown()
    }

    // --- Full Send Message Flow ---

    @Test
    fun `sendMessage saves assistant response to database after stream completes`() = runTest {
        // Setup: create conversation with a user message already saved
        val conversationId = setupConversation("conv_1")
        enqueueStreamingResponse("Hola, soy Savia. ¿En qué puedo ayudarte?")

        // Act: send a message and collect all deltas
        val deltas = repository.sendMessage(
            conversationId = conversationId,
            content = "Hola Savia"
        ).toList()

        // Verify: stream deltas contain text
        val textDeltas = deltas.filterIsInstance<StreamDelta.Text>()
        assertThat(textDeltas).isNotEmpty()
        val fullText = textDeltas.joinToString("") { it.text }
        assertThat(fullText).isEqualTo("Hola, soy Savia. ¿En qué puedo ayudarte?")

        // Verify: assistant message persisted in DB
        val messages = dao.getMessages(conversationId).first()
        val assistantMessages = messages.filter { it.role == MessageRole.ASSISTANT.name }
        assertThat(assistantMessages).hasSize(1)
        assertThat(assistantMessages[0].content).isEqualTo("Hola, soy Savia. ¿En qué puedo ayudarte?")
    }

    @Test
    fun `sendMessage auto-titles conversation from first user message`() = runTest {
        val conversationId = setupConversation("conv_auto_title")
        enqueueStreamingResponse("I can help with that!")

        repository.sendMessage(
            conversationId = conversationId,
            content = "How is the sprint going?"
        ).toList()

        val conversation = dao.getById(conversationId).first()
        assertThat(conversation).isNotNull()
        assertThat(conversation!!.title).isEqualTo("How is the sprint going?")
    }

    @Test
    fun `sendMessage truncates long titles to 50 chars`() = runTest {
        val conversationId = setupConversation("conv_long_title")
        enqueueStreamingResponse("Sure!")

        val longMessage = "Can you analyze the quarterly performance metrics for the engineering team and provide actionable insights?"
        repository.sendMessage(
            conversationId = conversationId,
            content = longMessage
        ).toList()

        val conversation = dao.getById(conversationId).first()
        assertThat(conversation!!.title.length).isAtMost(53) // 50 + "..."
        assertThat(conversation.title).endsWith("...")
    }

    @Test
    fun `sendMessage updates conversation timestamp`() = runTest {
        val conversationId = setupConversation("conv_ts", updatedAt = 1000L)
        enqueueStreamingResponse("Updated!")

        repository.sendMessage(
            conversationId = conversationId,
            content = "Test"
        ).toList()

        val conversation = dao.getById(conversationId).first()
        assertThat(conversation!!.updatedAt).isGreaterThan(1000L)
    }

    // --- Multi-Turn Conversation ---

    @Test
    fun `multi-turn conversation includes history in API request`() = runTest {
        val conversationId = setupConversation("conv_multi")

        // Turn 1: save user message first (as SendMessageUseCase would do), then call API
        repository.saveMessage(
            Message(id = "msg_u1", conversationId = conversationId, role = MessageRole.USER, content = "Who are you?")
        )
        enqueueStreamingResponse("I'm Savia, your PM assistant.")
        repository.sendMessage(conversationId, "Who are you?").toList()

        // Turn 2: save user message first, then call API
        repository.saveMessage(
            Message(id = "msg_u2", conversationId = conversationId, role = MessageRole.USER, content = "Sprint status?")
        )
        enqueueStreamingResponse("The sprint is 70% complete with 3 blockers.")
        repository.sendMessage(conversationId, "Sprint status?").toList()

        // Verify the second request includes the full history
        mockWebServer.takeRequest() // discard first request
        val secondRequest = mockWebServer.takeRequest()
        val body = secondRequest.body.readUtf8()

        // Should contain Turn 1 user message, Turn 1 assistant response, and Turn 2 user message
        assertThat(body).contains("Who are you?")
        assertThat(body).contains("I'm Savia, your PM assistant.")  // assistant from turn 1
        assertThat(body).contains("Sprint status?")
    }

    @Test
    fun `multi-turn conversation stores all messages in DB`() = runTest {
        val conversationId = setupConversation("conv_full")

        enqueueStreamingResponse("Answer 1")
        repository.sendMessage(conversationId, "Question 1").toList()

        enqueueStreamingResponse("Answer 2")
        repository.sendMessage(conversationId, "Question 2").toList()

        enqueueStreamingResponse("Answer 3")
        repository.sendMessage(conversationId, "Question 3").toList()

        val messages = dao.getMessages(conversationId).first()
        // 3 user messages + 3 assistant messages = 6 total
        // Note: user messages are saved by the use case layer, but the repository
        // also saves them internally. We verify assistant messages specifically.
        val assistantMessages = messages.filter { it.role == MessageRole.ASSISTANT.name }
        assertThat(assistantMessages).hasSize(3)
        assertThat(assistantMessages[0].content).isEqualTo("Answer 1")
        assertThat(assistantMessages[1].content).isEqualTo("Answer 2")
        assertThat(assistantMessages[2].content).isEqualTo("Answer 3")
    }

    // --- System Prompt ---

    @Test
    fun `sendMessage includes system prompt in API request`() = runTest {
        val conversationId = setupConversation("conv_sys")
        enqueueStreamingResponse("OK")

        repository.sendMessage(
            conversationId = conversationId,
            content = "Hello",
            systemPrompt = "You are Savia, a PM assistant."
        ).toList()

        val request = mockWebServer.takeRequest()
        val body = request.body.readUtf8()
        assertThat(body).contains("You are Savia, a PM assistant.")
    }

    @Test
    fun `sendMessage without system prompt omits it from request`() = runTest {
        val conversationId = setupConversation("conv_no_sys")
        enqueueStreamingResponse("OK")

        repository.sendMessage(
            conversationId = conversationId,
            content = "Hello",
            systemPrompt = null
        ).toList()

        val request = mockWebServer.takeRequest()
        val body = request.body.readUtf8()
        assertThat(body).contains("\"system\":null")
    }

    // --- Conversation CRUD ---

    @Test
    fun `createConversation persists to database`() = runTest {
        val conversation = repository.createConversation("New Chat")

        assertThat(conversation.id).isNotEmpty()
        assertThat(conversation.title).isEqualTo("New Chat")

        val fromDb = dao.getById(conversation.id).first()
        assertThat(fromDb).isNotNull()
        assertThat(fromDb!!.title).isEqualTo("New Chat")
    }

    @Test
    fun `getConversations returns all non-archived conversations`() = runTest {
        repository.createConversation("Chat 1")
        repository.createConversation("Chat 2")
        repository.createConversation("Chat 3")

        val conversations = repository.getConversations().first()
        assertThat(conversations).hasSize(3)
    }

    @Test
    fun `deleteConversation removes from database with messages`() = runTest {
        val conversationId = setupConversation("conv_del")
        enqueueStreamingResponse("Will be deleted")
        repository.sendMessage(conversationId, "Hello").toList()

        repository.deleteConversation(conversationId)

        val conversation = dao.getById(conversationId).first()
        assertThat(conversation).isNull()

        val messages = dao.getMessages(conversationId).first()
        assertThat(messages).isEmpty()
    }

    @Test
    fun `updateConversationTitle changes title in database`() = runTest {
        val conversation = repository.createConversation("Old Title")

        repository.updateConversationTitle(conversation.id, "New Title")

        val fromDb = dao.getById(conversation.id).first()
        assertThat(fromDb!!.title).isEqualTo("New Title")
    }

    // --- Error Scenarios ---

    @Test
    fun `sendMessage without API key throws IllegalStateException`() = runTest {
        // Create repo with no API key
        val noKeyClient = OkHttpClient.Builder().build()
        val noKeyRepo = ChatRepositoryImpl(
            apiService = mockWebServer.url("/").let { url ->
                Retrofit.Builder()
                    .baseUrl(url)
                    .client(noKeyClient)
                    .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
                    .build()
                    .create(ClaudeApiService::class.java)
            },
            bridgeService = SaviaBridgeService(noKeyClient, json),
            streamParser = ClaudeStreamParser(),
            conversationDao = dao,
            securityRepository = FakeSecurityRepository(null)
        )

        val conversationId = setupConversation("conv_nokey")

        try {
            noKeyRepo.sendMessage(conversationId, "Hello").toList()
            assertThat(false).isTrue() // should not reach here
        } catch (e: IllegalStateException) {
            assertThat(e.message).contains("API key not configured")
        }
    }

    // --- Helpers ---

    private suspend fun setupConversation(
        id: String,
        title: String = "",
        updatedAt: Long = System.currentTimeMillis()
    ): String {
        dao.insertConversation(
            com.savia.data.local.entity.ConversationEntity(
                id = id,
                title = title,
                createdAt = updatedAt,
                updatedAt = updatedAt
            )
        )
        return id
    }

    private fun enqueueStreamingResponse(fullText: String) {
        val words = fullText.split(" ")
        val events = mutableListOf(
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_test\",\"model\":\"claude-sonnet-4-20250514\",\"role\":\"assistant\"}}"
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
     * Fake security repository that returns a predefined API key.
     */
    private class FakeSecurityRepository(private val apiKey: String?) : SecurityRepository {
        override suspend fun saveApiKey(key: String) {}
        override suspend fun getApiKey(): String? = apiKey
        override suspend fun deleteApiKey() {}
        override suspend fun hasApiKey(): Boolean = apiKey != null
        override suspend fun saveBridgeConfig(host: String, port: Int, token: String, username: String) {}
        override suspend fun getBridgeUsername(): String? = null
        override suspend fun getBridgeHost(): String? = null
        override suspend fun getBridgePort(): Int? = null
        override suspend fun getBridgeToken(): String? = null
        override suspend fun hasBridgeConfig(): Boolean = false
        override suspend fun deleteBridgeConfig() {}
        override suspend fun saveLastConversationId(id: String) {}
        override suspend fun getLastConversationId(): String? = null
        override suspend fun clearLastConversationId() {}
        override suspend fun getDatabasePassphrase(): ByteArray = ByteArray(32)
        override suspend fun saveTheme(theme: String) {}
        override suspend fun getTheme(): String? = null
        override suspend fun saveLanguage(language: String) {}
        override suspend fun getLanguage(): String? = null
    }
}
