package com.savia.data.integration

import com.google.common.truth.Truth.assertThat
import com.savia.data.api.model.ApiMessage
import com.savia.data.api.model.ContentBlock
import com.savia.data.api.model.CreateMessageRequest
import com.savia.data.api.model.CreateMessageResponse
import com.savia.data.api.model.Delta
import com.savia.data.api.model.StreamEvent
import com.savia.data.api.model.StreamMessage
import com.savia.data.api.model.Usage
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Before
import org.junit.Test

/**
 * Integration tests for API model serialization/deserialization.
 *
 * Verifies that our Kotlin models correctly match the Claude Messages API
 * JSON format in both directions. Critical for API compatibility.
 */
class ApiSerializationIntegrationTest {

    private lateinit var json: Json

    @Before
    fun setup() {
        json = Json {
            ignoreUnknownKeys = true
            isLenient = true
            encodeDefaults = true
        }
    }

    // --- Request Serialization ---

    @Test
    fun `CreateMessageRequest serializes to correct JSON format`() {
        val request = CreateMessageRequest(
            model = "claude-sonnet-4-20250514",
            maxTokens = 4096,
            messages = listOf(
                ApiMessage(role = "user", content = "Hello Savia")
            ),
            system = "You are a PM assistant.",
            stream = true
        )

        val jsonStr = json.encodeToString(request)

        assertThat(jsonStr).contains("\"model\":\"claude-sonnet-4-20250514\"")
        assertThat(jsonStr).contains("\"max_tokens\":4096")
        assertThat(jsonStr).contains("\"stream\":true")
        assertThat(jsonStr).contains("\"role\":\"user\"")
        assertThat(jsonStr).contains("\"content\":\"Hello Savia\"")
        assertThat(jsonStr).contains("\"system\":\"You are a PM assistant.\"")
    }

    @Test
    fun `CreateMessageRequest with null system serializes correctly`() {
        val request = CreateMessageRequest(
            messages = listOf(ApiMessage(role = "user", content = "Hi")),
            system = null
        )

        val jsonStr = json.encodeToString(request)
        assertThat(jsonStr).contains("\"system\":null")
    }

    @Test
    fun `CreateMessageRequest with multiple messages preserves order`() {
        val request = CreateMessageRequest(
            messages = listOf(
                ApiMessage(role = "user", content = "First"),
                ApiMessage(role = "assistant", content = "Second"),
                ApiMessage(role = "user", content = "Third")
            )
        )

        val jsonStr = json.encodeToString(request)

        // Verify messages appear in order
        val firstIdx = jsonStr.indexOf("First")
        val secondIdx = jsonStr.indexOf("Second")
        val thirdIdx = jsonStr.indexOf("Third")
        assertThat(firstIdx).isLessThan(secondIdx)
        assertThat(secondIdx).isLessThan(thirdIdx)
    }

    // --- Response Deserialization ---

    @Test
    fun `StreamEvent message_start deserializes correctly`() {
        val jsonStr = """
            {
                "type": "message_start",
                "message": {
                    "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
                    "model": "claude-sonnet-4-20250514",
                    "role": "assistant"
                }
            }
        """.trimIndent()

        val event = json.decodeFromString<StreamEvent>(jsonStr)

        assertThat(event.type).isEqualTo("message_start")
        assertThat(event.message).isNotNull()
        assertThat(event.message!!.id).isEqualTo("msg_01XFDUDYJgAACzvnptvVoYEL")
        assertThat(event.message!!.model).isEqualTo("claude-sonnet-4-20250514")
    }

    @Test
    fun `StreamEvent content_block_delta with text deserializes correctly`() {
        val jsonStr = """
            {
                "type": "content_block_delta",
                "index": 0,
                "delta": {
                    "type": "text_delta",
                    "text": "Hello, I'm Savia!"
                }
            }
        """.trimIndent()

        val event = json.decodeFromString<StreamEvent>(jsonStr)

        assertThat(event.type).isEqualTo("content_block_delta")
        assertThat(event.index).isEqualTo(0)
        assertThat(event.delta).isNotNull()
        assertThat(event.delta!!.type).isEqualTo("text_delta")
        assertThat(event.delta!!.text).isEqualTo("Hello, I'm Savia!")
    }

    @Test
    fun `StreamEvent message_stop deserializes correctly`() {
        val jsonStr = """{"type":"message_stop"}"""

        val event = json.decodeFromString<StreamEvent>(jsonStr)

        assertThat(event.type).isEqualTo("message_stop")
        assertThat(event.message).isNull()
        assertThat(event.delta).isNull()
    }

    @Test
    fun `StreamEvent with unknown fields is deserialized without error`() {
        val jsonStr = """
            {
                "type": "content_block_delta",
                "index": 0,
                "unknown_field": "should be ignored",
                "delta": {
                    "type": "text_delta",
                    "text": "works"
                }
            }
        """.trimIndent()

        val event = json.decodeFromString<StreamEvent>(jsonStr)
        assertThat(event.delta!!.text).isEqualTo("works")
    }

    @Test
    fun `CreateMessageResponse non-streaming format deserializes correctly`() {
        val jsonStr = """
            {
                "id": "msg_01ABC",
                "model": "claude-sonnet-4-20250514",
                "content": [
                    {"type": "text", "text": "Hello! I'm Savia."}
                ],
                "stop_reason": "end_turn",
                "usage": {
                    "input_tokens": 25,
                    "output_tokens": 150
                }
            }
        """.trimIndent()

        val response = json.decodeFromString<CreateMessageResponse>(jsonStr)

        assertThat(response.id).isEqualTo("msg_01ABC")
        assertThat(response.model).isEqualTo("claude-sonnet-4-20250514")
        assertThat(response.content).hasSize(1)
        assertThat(response.content[0].text).isEqualTo("Hello! I'm Savia.")
        assertThat(response.stopReason).isEqualTo("end_turn")
        assertThat(response.usage!!.inputTokens).isEqualTo(25)
        assertThat(response.usage!!.outputTokens).isEqualTo(150)
    }

    // --- Edge Cases ---

    @Test
    fun `delta with special characters deserializes correctly`() {
        val jsonStr = """
            {
                "type": "content_block_delta",
                "index": 0,
                "delta": {
                    "type": "text_delta",
                    "text": "¡Hola! 日本語 \"quoted\" \n newline"
                }
            }
        """.trimIndent()

        val event = json.decodeFromString<StreamEvent>(jsonStr)

        assertThat(event.delta!!.text).contains("¡Hola!")
        assertThat(event.delta!!.text).contains("日本語")
        assertThat(event.delta!!.text).contains("\"quoted\"")
    }

    @Test
    fun `delta with stop_reason field deserializes correctly`() {
        val jsonStr = """
            {
                "type": "message_delta",
                "delta": {
                    "stop_reason": "end_turn"
                }
            }
        """.trimIndent()

        val event = json.decodeFromString<StreamEvent>(jsonStr)

        assertThat(event.delta!!.stopReason).isEqualTo("end_turn")
    }

    // --- Round-Trip Serialization ---

    @Test
    fun `ApiMessage round-trip serialization preserves data`() {
        val original = ApiMessage(role = "user", content = "Test message with unicode: ñ á é")

        val serialized = json.encodeToString(original)
        val deserialized = json.decodeFromString<ApiMessage>(serialized)

        assertThat(deserialized.role).isEqualTo(original.role)
        assertThat(deserialized.content).isEqualTo(original.content)
    }

    @Test
    fun `CreateMessageRequest round-trip preserves all fields`() {
        val original = CreateMessageRequest(
            model = "claude-sonnet-4-20250514",
            maxTokens = 1024,
            messages = listOf(
                ApiMessage("user", "Q1"),
                ApiMessage("assistant", "A1"),
                ApiMessage("user", "Q2")
            ),
            system = "You are helpful.",
            stream = true
        )

        val serialized = json.encodeToString(original)
        val deserialized = json.decodeFromString<CreateMessageRequest>(serialized)

        assertThat(deserialized.model).isEqualTo(original.model)
        assertThat(deserialized.maxTokens).isEqualTo(original.maxTokens)
        assertThat(deserialized.messages).hasSize(3)
        assertThat(deserialized.system).isEqualTo(original.system)
        assertThat(deserialized.stream).isEqualTo(original.stream)
    }
}
