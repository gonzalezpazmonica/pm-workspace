package com.savia.data.api

import com.savia.data.api.model.StreamEvent
import com.savia.domain.model.StreamDelta
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.serialization.json.Json
import okhttp3.ResponseBody
import javax.inject.Inject

/**
 * Parser for Anthropic Claude's Server-Sent Events (SSE) streaming responses.
 *
 * Converts raw SSE data streams into [StreamDelta] events that drive the UI.
 * Handles message start/stop, text chunks, errors, and connection boundaries.
 *
 * **Architecture role:** Unmarshalling layer for API response payloads.
 * Bridges between Retrofit's [ResponseBody] and domain [StreamDelta] model.
 *
 * **SSE Format Handled:**
 * ```
 * event: message_start
 * data: {"type":"message_start","message":{"id":"msg_...","model":"claude-..."}}
 *
 * event: content_block_delta
 * data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"response text"}}
 *
 * event: message_stop
 * data: {"type":"message_stop"}
 * ```
 *
 * **Event Types Recognized:**
 * - `message_start` → [StreamDelta.Start] (message ID, model)
 * - `content_block_delta` → [StreamDelta.Text] (text chunk)
 * - `message_stop` → [StreamDelta.Done] (completion)
 * - `[DONE]` → [StreamDelta.Done] (special marker)
 * - `error` → [StreamDelta.Error] (error event)
 * - Other events (e.g., ping, content_block_start) → ignored
 *
 * **Error Handling:**
 * - Malformed JSON in data field → skipped, parsing continues
 * - Missing/null fields → safe defaults or skipped
 * - Network errors → emitted as [StreamDelta.Error]
 * - Incomplete stream → auto-emit [StreamDelta.Done] at end
 *
 * **Thread Safety:**
 * - Safe to parse concurrent streams
 * - Runs on Dispatchers.IO (non-blocking)
 * - Flow can be collected from any coroutine context
 *
 * @constructor Single instance per app (singleton via Hilt)
 */
class ClaudeStreamParser @Inject constructor() {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    /**
     * Parse a streaming HTTP response body into a flow of [StreamDelta] events.
     *
     * **Parsing Algorithm:**
     * 1. Read response body line-by-line
     * 2. Identify `data:` lines and extract JSON payload
     * 3. Deserialize JSON to [StreamEvent]
     * 4. Map event type to appropriate [StreamDelta]
     * 5. Emit deltas to Flow subscribers
     * 6. Stop on [Done] event or stream exhaustion
     * 7. Auto-emit [Done] if stream ends naturally
     *
     * **Performance:**
     * - Streaming: No buffering of entire response
     * - Line-buffered: Minimal memory footprint
     * - Lazy: Processing starts only when subscribed
     *
     * **Backpressure:** Handles slow subscribers via callbackFlow.
     * Slow collection doesn't block network reads.
     *
     * @param body [ResponseBody] from Retrofit (unread, streaming)
     *
     * @return Flow<StreamDelta> Cold flow of events
     *         - Emits immediately on subscription
     *         - Completes after [Done] or stream end
     *         - Errors propagate to collector
     *         - Runs on Dispatchers.IO
     *
     * @throws IOException if response body can't be read
     * @throws SerializationException if JSON parsing fails (skipped, continues)
     */
    fun parse(body: ResponseBody): Flow<StreamDelta> = callbackFlow {
        var doneSent = false

        try {
            body.source().use { source ->
                val buffer = StringBuilder()

                while (!source.exhausted()) {
                    val line = source.readUtf8Line() ?: continue

                    when {
                        line.startsWith("data: ") -> {
                            val data = line.removePrefix("data: ").trim()
                            if (data == "[DONE]") {
                                trySend(StreamDelta.Done)
                                doneSent = true
                                close()
                                return@callbackFlow
                            }

                            try {
                                val event = json.decodeFromString<StreamEvent>(data)
                                processEvent(event)?.let { delta ->
                                    trySend(delta)
                                    if (delta is StreamDelta.Done) doneSent = true
                                }
                            } catch (e: Exception) {
                                // Skip malformed events, continue parsing
                            }
                        }
                        line.isBlank() -> {
                            // SSE event boundary — reset buffer
                            buffer.clear()
                        }
                    }
                }

                // Stream ended naturally — only emit Done if not already sent
                if (!doneSent) {
                    trySend(StreamDelta.Done)
                }
            }
        } catch (e: Exception) {
            trySend(StreamDelta.Error(e.message ?: "Unknown streaming error"))
        }

        close()
        awaitClose()
    }.flowOn(Dispatchers.IO)

    /**
     * Map a [StreamEvent] to the corresponding [StreamDelta] for the UI.
     *
     * Event-to-delta mapping:
     * - `message_start` → [StreamDelta.Start] with message ID and model
     * - `content_block_delta` → [StreamDelta.Text] with text chunk
     * - `message_stop` → [StreamDelta.Done] (end of stream)
     * - `error` → [StreamDelta.Error] with generic error message
     * - Other types (ping, content_block_start, etc.) → null (ignored)
     *
     * **Null Handling:**
     * Returns null (not skipped) if required fields are missing.
     * Null deltas are skipped; parsing continues.
     *
     * @param event [StreamEvent] decoded from SSE data line
     *
     * @return [StreamDelta] or null if event should be ignored
     *
     * @see StreamDelta domain model for all possible delta types
     */
    private fun processEvent(event: StreamEvent): StreamDelta? {
        return when (event.type) {
            "message_start" -> {
                val msg = event.message ?: return null
                StreamDelta.Start(messageId = msg.id, model = msg.model)
            }
            "content_block_delta" -> {
                val text = event.delta?.text ?: return null
                StreamDelta.Text(text)
            }
            "message_stop" -> StreamDelta.Done
            "error" -> StreamDelta.Error("API error in stream")
            else -> null // ping, content_block_start, content_block_stop, etc.
        }
    }
}
