package com.savia.data

import com.google.common.truth.Truth.assertThat
import com.savia.data.api.ClaudeStreamParser
import com.savia.domain.model.StreamDelta
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Before
import org.junit.Test

class ClaudeStreamParserTest {

    private lateinit var parser: ClaudeStreamParser

    @Before
    fun setup() {
        parser = ClaudeStreamParser()
    }

    @Test
    fun `parse handles message_start event`() = runTest {
        val sse = """
            event: message_start
            data: {"type":"message_start","message":{"id":"msg_01","model":"claude-sonnet-4-20250514","role":"assistant"}}

            event: message_stop
            data: {"type":"message_stop"}

        """.trimIndent()

        val result = parser.parse(sse.toResponseBody()).toList()

        assertThat(result).hasSize(2) // Start + Done
        assertThat(result[0]).isInstanceOf(StreamDelta.Start::class.java)
        assertThat((result[0] as StreamDelta.Start).messageId).isEqualTo("msg_01")
    }

    @Test
    fun `parse extracts text deltas`() = runTest {
        val sse = """
            event: content_block_delta
            data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

            event: content_block_delta
            data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

            event: message_stop
            data: {"type":"message_stop"}

        """.trimIndent()

        val result = parser.parse(sse.toResponseBody()).toList()

        val textDeltas = result.filterIsInstance<StreamDelta.Text>()
        assertThat(textDeltas).hasSize(2)
        assertThat(textDeltas[0].text).isEqualTo("Hello")
        assertThat(textDeltas[1].text).isEqualTo(" world")
    }

    @Test
    fun `parse handles DONE marker`() = runTest {
        val sse = "data: [DONE]\n\n"

        val result = parser.parse(sse.toResponseBody()).toList()

        assertThat(result).hasSize(1)
        assertThat(result[0]).isEqualTo(StreamDelta.Done)
    }

    @Test
    fun `parse skips unknown event types gracefully`() = runTest {
        val sse = """
            event: ping
            data: {"type":"ping"}

            event: content_block_start
            data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

            event: message_stop
            data: {"type":"message_stop"}

        """.trimIndent()

        val result = parser.parse(sse.toResponseBody()).toList()

        // Only message_stop produces a delta (Done)
        assertThat(result.filterIsInstance<StreamDelta.Done>()).isNotEmpty()
    }

    @Test
    fun `parse handles empty response body`() = runTest {
        val result = parser.parse("".toResponseBody()).toList()

        // Should complete with Done without crashing
        assertThat(result).isNotEmpty()
        assertThat(result.last()).isEqualTo(StreamDelta.Done)
    }
}
