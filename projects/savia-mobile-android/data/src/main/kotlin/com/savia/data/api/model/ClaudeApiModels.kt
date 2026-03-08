/**
 * Data models for Claude API communication.
 *
 * **Architecture:**
 * - Request models: [CreateMessageRequest], [ApiMessage] (outgoing to API)
 * - Response models: [CreateMessageResponse], [StreamEvent] and nested types (incoming)
 * - Streaming models: Models in streaming SSE format (real-time chunks)
 *
 * **Serialization:**
 * All models use kotlinx.serialization with @Serializable.
 * Configuration: ignoreUnknownKeys=true, isLenient=true (backward compatible).
 *
 * **Versioning:**
 * API version 2023-06-01 (set in ClaudeApiService headers).
 */

package com.savia.data.api.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Request to create a message via Claude API.
 *
 * **Parameters:**
 * - model: Default "claude-sonnet-4-20250514" (configurable)
 * - maxTokens: Max output tokens (4096 default, adjust for memory/latency)
 * - messages: Message history (required, non-empty)
 * - system: Optional system prompt (context/persona)
 * - stream: Always true for streaming mode
 *
 * **Constraints:**
 * - messages.size >= 1 (at least one user message)
 * - maxTokens <= 200000 (API limit)
 * - model must be supported by API key tier
 *
 * @property model Claude model identifier
 * @property maxTokens Maximum tokens in response
 * @property messages Conversation history
 * @property system Optional system instructions
 * @property stream Enable Server-Sent Events streaming
 */
@Serializable
data class CreateMessageRequest(
    val model: String = "claude-sonnet-4-20250514",
    @SerialName("max_tokens") val maxTokens: Int = 4096,
    val messages: List<ApiMessage>,
    val system: String? = null,
    val stream: Boolean = true
)

/**
 * Single message in conversation history.
 *
 * **Roles:**
 * - "user": Human input (from user)
 * - "assistant": Claude response (from API)
 *
 * **Content:**
 * Typically plain text in messaging mode.
 * For vision/tools, content is wrapped in content blocks (not used in basic chat).
 *
 * @property role "user" or "assistant"
 * @property content Message text
 */
@Serializable
data class ApiMessage(
    val role: String,
    val content: String
)

// --- Streaming SSE response types ---

/**
 * Single SSE event from Claude API streaming response.
 *
 * **Event Types:**
 * - `message_start`: Stream start, includes message metadata
 * - `content_block_delta`: Text chunk (contains delta with text field)
 * - `message_stop`: Stream end
 * - `error`: Error event (contains error text)
 * - Others: ping, content_block_start, content_block_stop (ignored)
 *
 * **Fields by Event Type:**
 * - message_start: message (required), index (optional)
 * - content_block_delta: delta (required), index (optional)
 * - message_stop: (no additional fields)
 * - error: delta with text (optional)
 *
 * @property type Event type identifier (e.g., "message_start")
 * @property message Metadata for message_start events
 * @property index Block/event index (when relevant)
 * @property contentBlock Full content block (message_stop events)
 * @property delta Delta information (content_block_delta)
 */
@Serializable
data class StreamEvent(
    val type: String,
    val message: StreamMessage? = null,
    val index: Int? = null,
    @SerialName("content_block") val contentBlock: ContentBlock? = null,
    val delta: Delta? = null
)

/**
 * Message metadata in message_start event.
 *
 * @property id Unique message identifier (use in DB as messageId)
 * @property model Model used for this message
 * @property role Message role (usually "assistant" for responses)
 */
@Serializable
data class StreamMessage(
    val id: String,
    val model: String,
    val role: String? = null
)

/**
 * Content block in response (text, image, tool use, etc).
 *
 * **Type Field:**
 * - "text": Plain text response (most common)
 * - "image": Image content (not used in basic chat)
 * - "tool_use": Tool invocation (not used in basic chat)
 *
 * @property type Content block type ("text" for messages)
 * @property text Text content (if type="text")
 */
@Serializable
data class ContentBlock(
    val type: String,
    val text: String? = null
)

/**
 * Delta (incremental change) in streaming response.
 *
 * **Type Field:**
 * - "text_delta": Text chunk (contains text field)
 * - "input_json_delta": Partial JSON (tools)
 *
 * @property type Delta type ("text_delta" for text responses)
 * @property text Text chunk (for text_delta)
 * @property stopReason Completion reason ("end_turn", "max_tokens", etc)
 */
@Serializable
data class Delta(
    val type: String? = null,
    val text: String? = null,
    @SerialName("stop_reason") val stopReason: String? = null
)

// --- Non-streaming response (fallback) ---

/**
 * Complete message response (non-streaming fallback).
 *
 * Used only when streaming cannot be used. Provides complete message
 * with all content blocks and usage statistics.
 *
 * **Stop Reasons:**
 * - "end_turn": Natural completion
 * - "max_tokens": Output length limit reached
 * - "stop_sequence": Configured stop sequence reached
 *
 * @property id Message ID
 * @property model Model used
 * @property content List of content blocks (typically one text block)
 * @property stopReason Reason for completion
 * @property usage Token usage statistics
 */
@Serializable
data class CreateMessageResponse(
    val id: String,
    val model: String,
    val content: List<ContentBlock>,
    @SerialName("stop_reason") val stopReason: String? = null,
    val usage: Usage? = null
)

/**
 * Token usage statistics for a message.
 *
 * **Fields:**
 * - inputTokens: Tokens in the request (history + system prompt + user message)
 * - outputTokens: Tokens in the response (assistant message)
 *
 * **Billing:**
 * Different models charge different rates per token.
 * Use these to estimate API costs in settings.
 *
 * @property inputTokens Tokens consumed by request (prompt)
 * @property outputTokens Tokens consumed by response (completion)
 */
@Serializable
data class Usage(
    @SerialName("input_tokens") val inputTokens: Int,
    @SerialName("output_tokens") val outputTokens: Int
)
