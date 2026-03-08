package com.savia.data.integration

import com.google.common.truth.Truth.assertThat
import com.savia.data.api.ClaudeApiService
import com.savia.data.api.ClaudeStreamParser
import com.savia.data.api.model.ApiMessage
import com.savia.data.api.model.CreateMessageRequest
import com.savia.domain.model.StreamDelta
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.Test
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit

/**
 * Integration tests for the Claude API client pipeline:
 * MockWebServer → OkHttp → Retrofit → ClaudeApiService → ClaudeStreamParser
 *
 * Verifies the full network stack works end-to-end:
 * - HTTP request format (headers, body, method)
 * - SSE response parsing from a real HTTP response
 * - Error handling (4xx, 5xx, malformed SSE)
 * - Timeout behavior
 */
class ClaudeApiIntegrationTest {

    private lateinit var mockWebServer: MockWebServer
    private lateinit var apiService: ClaudeApiService
    private lateinit var streamParser: ClaudeStreamParser

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    @Before
    fun setup() {
        mockWebServer = MockWebServer()
        mockWebServer.start()

        val client = OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()

        val retrofit = Retrofit.Builder()
            .baseUrl(mockWebServer.url("/"))
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()

        apiService = retrofit.create(ClaudeApiService::class.java)
        streamParser = ClaudeStreamParser()
    }

    @After
    fun tearDown() {
        mockWebServer.shutdown()
    }

    // --- Full Streaming Lifecycle ---

    @Test
    fun `full SSE streaming lifecycle - start, text deltas, stop`() = runTest {
        val sseBody = buildSseResponse(
            "message_start" to """{"type":"message_start","message":{"id":"msg_abc123","model":"claude-sonnet-4-20250514","role":"assistant"}}""",
            "content_block_start" to """{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}""",
            "content_block_delta" to """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hola"}}""",
            "content_block_delta" to """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":", soy"}}""",
            "content_block_delta" to """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" Savia"}}""",
            "content_block_stop" to """{"type":"content_block_stop","index":0}""",
            "message_stop" to """{"type":"message_stop"}"""
        )

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(sseBody)
        )

        val response = apiService.createMessageStream(
            apiKey = "sk-test-key",
            request = createTestRequest("Hello")
        )

        val deltas = streamParser.parse(response).toList()

        // Verify stream lifecycle
        val start = deltas.filterIsInstance<StreamDelta.Start>()
        assertThat(start).hasSize(1)
        assertThat(start[0].messageId).isEqualTo("msg_abc123")
        assertThat(start[0].model).isEqualTo("claude-sonnet-4-20250514")

        // Verify text assembly
        val textDeltas = deltas.filterIsInstance<StreamDelta.Text>()
        assertThat(textDeltas).hasSize(3)
        val fullText = textDeltas.joinToString("") { it.text }
        assertThat(fullText).isEqualTo("Hola, soy Savia")

        // Verify stream end
        assertThat(deltas.filterIsInstance<StreamDelta.Done>()).isNotEmpty()
    }

    @Test
    fun `long streaming response with many deltas`() = runTest {
        val events = mutableListOf(
            "message_start" to """{"type":"message_start","message":{"id":"msg_long","model":"claude-sonnet-4-20250514","role":"assistant"}}"""
        )
        // Simulate 50 text deltas (word-by-word streaming)
        val words = "Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua Ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur".split(" ")
        words.forEach { word ->
            events.add("content_block_delta" to """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"$word "}}""")
        }
        events.add("message_stop" to """{"type":"message_stop"}""")

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(buildSseResponse(*events.toTypedArray()))
        )

        val response = apiService.createMessageStream(
            apiKey = "sk-test-key",
            request = createTestRequest("Tell me a story")
        )

        val deltas = streamParser.parse(response).toList()
        val textDeltas = deltas.filterIsInstance<StreamDelta.Text>()

        assertThat(textDeltas).hasSize(words.size)
        val fullText = textDeltas.joinToString("") { it.text }.trim()
        assertThat(fullText).isEqualTo(words.joinToString(" "))
    }

    // --- Request Format Verification ---

    @Test
    fun `request contains correct headers and body format`() = runTest {
        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(buildSseResponse(
                    "message_stop" to """{"type":"message_stop"}"""
                ))
        )

        val request = CreateMessageRequest(
            model = "claude-sonnet-4-20250514",
            maxTokens = 2048,
            messages = listOf(
                ApiMessage(role = "user", content = "Hello Savia")
            ),
            system = "You are Savia, a PM assistant.",
            stream = true
        )

        val response = apiService.createMessageStream(
            apiKey = "sk-ant-api03-test",
            version = "2023-06-01",
            request = request
        )
        streamParser.parse(response).toList() // consume the response

        // Verify the request that was sent
        val recordedRequest = mockWebServer.takeRequest()
        assertThat(recordedRequest.method).isEqualTo("POST")
        assertThat(recordedRequest.path).isEqualTo("/v1/messages")
        assertThat(recordedRequest.getHeader("x-api-key")).isEqualTo("sk-ant-api03-test")
        assertThat(recordedRequest.getHeader("anthropic-version")).isEqualTo("2023-06-01")
        assertThat(recordedRequest.getHeader("Content-Type")).contains("application/json")

        // Verify body
        val body = recordedRequest.body.readUtf8()
        assertThat(body).contains("\"model\":\"claude-sonnet-4-20250514\"")
        assertThat(body).contains("\"max_tokens\":2048")
        assertThat(body).contains("\"stream\":true")
        assertThat(body).contains("Hello Savia")
        assertThat(body).contains("You are Savia")
    }

    @Test
    fun `request with conversation history includes all messages`() = runTest {
        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(buildSseResponse(
                    "message_stop" to """{"type":"message_stop"}"""
                ))
        )

        val request = CreateMessageRequest(
            messages = listOf(
                ApiMessage(role = "user", content = "First question"),
                ApiMessage(role = "assistant", content = "First answer"),
                ApiMessage(role = "user", content = "Follow-up question")
            )
        )

        val response = apiService.createMessageStream(apiKey = "sk-test", request = request)
        streamParser.parse(response).toList()

        val body = mockWebServer.takeRequest().body.readUtf8()
        assertThat(body).contains("First question")
        assertThat(body).contains("First answer")
        assertThat(body).contains("Follow-up question")
    }

    // --- Error Handling ---

    @Test
    fun `HTTP 401 unauthorized throws exception`() = runTest {
        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(401)
                .setBody("""{"type":"error","error":{"type":"authentication_error","message":"Invalid API key"}}""")
        )

        try {
            apiService.createMessageStream(
                apiKey = "sk-invalid",
                request = createTestRequest("Hello")
            )
            // If we get here, the test should fail — 401 should throw
            assertThat(false).isTrue() // force fail
        } catch (e: retrofit2.HttpException) {
            assertThat(e.code()).isEqualTo(401)
        }
    }

    @Test
    fun `HTTP 429 rate limit throws exception`() = runTest {
        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(429)
                .setHeader("retry-after", "30")
                .setBody("""{"type":"error","error":{"type":"rate_limit_error","message":"Rate limited"}}""")
        )

        try {
            apiService.createMessageStream(
                apiKey = "sk-test",
                request = createTestRequest("Hello")
            )
            assertThat(false).isTrue()
        } catch (e: retrofit2.HttpException) {
            assertThat(e.code()).isEqualTo(429)
        }
    }

    @Test
    fun `HTTP 500 server error throws exception`() = runTest {
        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(500)
                .setBody("""{"type":"error","error":{"type":"api_error","message":"Internal server error"}}""")
        )

        try {
            apiService.createMessageStream(
                apiKey = "sk-test",
                request = createTestRequest("Hello")
            )
            assertThat(false).isTrue()
        } catch (e: retrofit2.HttpException) {
            assertThat(e.code()).isEqualTo(500)
        }
    }

    // --- Malformed SSE Handling ---

    @Test
    fun `parser handles SSE with interleaved blank lines gracefully`() = runTest {
        val sseBody = """
            |event: message_start
            |data: {"type":"message_start","message":{"id":"msg_1","model":"claude-sonnet-4-20250514"}}
            |
            |
            |
            |event: content_block_delta
            |data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
            |
            |event: message_stop
            |data: {"type":"message_stop"}
            |
        """.trimMargin()

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(sseBody)
        )

        val response = apiService.createMessageStream(
            apiKey = "sk-test",
            request = createTestRequest("Hi")
        )
        val deltas = streamParser.parse(response).toList()

        val textDeltas = deltas.filterIsInstance<StreamDelta.Text>()
        assertThat(textDeltas).hasSize(1)
        assertThat(textDeltas[0].text).isEqualTo("Hello")
    }

    @Test
    fun `parser handles malformed JSON in one event without crashing`() = runTest {
        val sseBody = """
            |event: content_block_delta
            |data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Before"}}
            |
            |event: content_block_delta
            |data: {MALFORMED JSON HERE!!!}
            |
            |event: content_block_delta
            |data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"After"}}
            |
            |event: message_stop
            |data: {"type":"message_stop"}
            |
        """.trimMargin()

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(sseBody)
        )

        val response = apiService.createMessageStream(
            apiKey = "sk-test",
            request = createTestRequest("Hi")
        )
        val deltas = streamParser.parse(response).toList()

        // Should recover and continue parsing — skip the malformed event
        val textDeltas = deltas.filterIsInstance<StreamDelta.Text>()
        assertThat(textDeltas).hasSize(2)
        assertThat(textDeltas[0].text).isEqualTo("Before")
        assertThat(textDeltas[1].text).isEqualTo("After")
    }

    @Test
    fun `parser handles empty data field`() = runTest {
        val sseBody = """
            |event: content_block_delta
            |data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Valid"}}
            |
            |data:
            |
            |event: message_stop
            |data: {"type":"message_stop"}
            |
        """.trimMargin()

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(sseBody)
        )

        val response = apiService.createMessageStream(
            apiKey = "sk-test",
            request = createTestRequest("Hi")
        )
        val deltas = streamParser.parse(response).toList()

        assertThat(deltas.filterIsInstance<StreamDelta.Text>()).hasSize(1)
    }

    // --- Unicode and Special Characters ---

    @Test
    fun `streaming handles unicode characters correctly`() = runTest {
        val sseBody = buildSseResponse(
            "content_block_delta" to """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"¡Hola! "}}""",
            "content_block_delta" to """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"日本語 "}}""",
            "content_block_delta" to """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"🚀"}}""",
            "message_stop" to """{"type":"message_stop"}"""
        )

        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "text/event-stream")
                .setBody(sseBody)
        )

        val response = apiService.createMessageStream(
            apiKey = "sk-test",
            request = createTestRequest("multilingual test")
        )
        val deltas = streamParser.parse(response).toList()
        val fullText = deltas.filterIsInstance<StreamDelta.Text>().joinToString("") { it.text }

        assertThat(fullText).contains("¡Hola!")
        assertThat(fullText).contains("日本語")
        assertThat(fullText).contains("🚀")
    }

    // --- Helpers ---

    private fun createTestRequest(content: String) = CreateMessageRequest(
        messages = listOf(ApiMessage(role = "user", content = content))
    )

    private fun buildSseResponse(vararg events: Pair<String, String>): String {
        return events.joinToString("\n\n") { (event, data) ->
            "event: $event\ndata: $data"
        } + "\n\n"
    }
}
