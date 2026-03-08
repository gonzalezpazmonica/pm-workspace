package com.savia.data.api

import com.savia.data.api.model.CreateMessageRequest
import okhttp3.ResponseBody
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Streaming

/**
 * Retrofit HTTP interface for the Claude Messages API.
 *
 * Provides direct access to Anthropic's Claude API (fallback when bridge is unavailable).
 * Uses Retrofit for HTTP abstraction and `@Streaming` for incremental SSE delivery.
 *
 * **Architecture role:** API layer abstraction for Anthropic API communication.
 * Data layer delegates to [ClaudeStreamParser] for response deserialization.
 *
 * **API Contract:**
 * - Base URL: `https://api.anthropic.com` (configured in OkHttpClient setup)
 * - Authentication: API key via `x-api-key` header
 * - Protocol: HTTPS, Server-Sent Events (SSE)
 * - Version: Anthropic API v1 (2023-06-01)
 *
 * **Streaming:**
 * - `@Streaming` prevents Retrofit from buffering response body
 * - Enables incremental reading of SSE events as they arrive
 * - Compatible with [okio.BufferedSource] for line-by-line parsing
 *
 * **Security:**
 * - API key injected at runtime (never hardcoded)
 * - HTTPS only (no cleartext transmission)
 * - Implements Anthropic security best practices
 *
 * **Lifecycle:**
 * - Used only when bridge is unavailable
 * - Requires valid Anthropic API key in secure storage
 * - Fallback to this API triggers automatic token validation
 *
 * @see CreateMessageRequest Request body schema
 * @see com.savia.data.api.ClaudeStreamParser SSE response parsing
 */
interface ClaudeApiService {

    /**
     * Stream a message response from Claude API.
     *
     * Sends a message request to Anthropic's Claude API and receives a Server-Sent Events
     * stream of response chunks. The response body must be parsed by [ClaudeStreamParser]
     * to extract [StreamDelta] events.
     *
     * **HTTP Details:**
     * - Method: POST to `/v1/messages`
     * - Streaming: Enabled (ResponseBody returned incrementally)
     * - Expected response: text/event-stream with chunked encoding
     *
     * **Request Headers:**
     * - `x-api-key`: Authentication token (required)
     * - `anthropic-version`: API version specification (default: 2023-06-01)
     * - `content-type`: application/json (added by Retrofit)
     *
     * **Response Format (SSE):**
     * ```
     * event: message_start
     * data: {"type":"message_start","message":{...}}
     *
     * event: content_block_delta
     * data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}
     *
     * event: message_stop
     * data: {"type":"message_stop"}
     * ```
     *
     * **Error Handling:**
     * - 400 Bad Request: Invalid parameters in CreateMessageRequest
     * - 401 Unauthorized: Invalid or expired API key
     * - 429 Too Many Requests: Rate limit exceeded
     * - 500+ Server Error: Anthropic API service unavailable
     *
     * **Parsing:**
     * Call [ClaudeStreamParser.parse] to convert ResponseBody to Flow<StreamDelta>.
     *
     * @param apiKey Anthropic API key (x-api-key header)
     * @param version API version string (default: "2023-06-01")
     * @param request Message request with messages array and system prompt
     *
     * @return ResponseBody Unread stream of SSE events
     *         Pass to ClaudeStreamParser.parse() for event deserialization
     *
     * @throws IOException if network error occurs
     * @throws HttpException if HTTP status is 4xx or 5xx
     *
     * @see CreateMessageRequest for building request payloads
     * @see ClaudeStreamParser for parsing response stream
     */
    @POST("v1/messages")
    @Streaming
    suspend fun createMessageStream(
        @Header("x-api-key") apiKey: String,
        @Header("anthropic-version") version: String = "2023-06-01",
        @Body request: CreateMessageRequest
    ): ResponseBody
}
