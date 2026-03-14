package com.savia.data.api

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import kotlinx.serialization.json.Json
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import com.savia.domain.model.StreamDelta
import javax.inject.Inject

/**
 * HTTP client for the Savia Bridge server (port 8922).
 *
 * Savia Bridge is an HTTPS/SSE wrapper around Claude Code CLI that enables the mobile app
 * to communicate with Claude using Server-Sent Events for streaming responses. This service
 * handles all bridge communication when the bridge is configured as the primary backend.
 *
 * **Architecture role:** Data layer integration point for the bridge transport layer.
 * Replaces direct Anthropic API calls when bridge connectivity is available.
 *
 * **HTTP Contract:**
 * - Base URL: configurable (typically `https://localhost:8922`)
 * - Authentication: Bearer token (obtained during bridge connection)
 * - Protocol: HTTPS/TLS, SSE for streaming
 *
 * **Endpoints:**
 * - POST `/chat` - Send a message and receive streamed response
 * - GET `/health` - Check bridge server availability
 *
 * **Request/Response Flow:**
 * - Client sends: JSON message with user text, session ID, optional system prompt
 * - Server responds: Server-Sent Events with text chunks and completion marker
 * - No polling: Uses persistent HTTP connection for real-time streaming
 *
 * @constructor Creates a bridge service with OkHttpClient and Kotlinx Serialization
 * @param httpClient OkHttpClient for HTTP operations (injected via Hilt)
 * @param json Kotlinx Serialization Json instance for request/response parsing
 */
class SaviaBridgeService @Inject constructor(
    private val httpClient: OkHttpClient,
    private val json: Json
) {

    /**
     * Get the Bridge server base URL.
     *
     * Convenience method for retrieving the complete Bridge URL.
     * Returns null if Bridge is not configured in SecurityRepository.
     *
     * **Note:** In actual implementation, this would need access to SecurityRepository
     * or the Bridge URL would be passed explicitly to the calling methods.
     *
     * @return Complete Bridge URL (e.g., "https://localhost:8922"), or null if not configured
     */
    fun getBridgeUrl(): String? {
        // In production, this would fetch from SecurityRepository or be set during initialization
        // For now, callers will pass the URL explicitly to methods like sendMessageStream
        return null
    }

    /**
     * Send a message to the bridge server and stream the response via SSE.
     *
     * Establishes an HTTP POST connection to the bridge server's `/chat` endpoint,
     * sends the message in bridge format, and emits [StreamDelta] events as SSE
     * data arrives. Automatically handles SSE event parsing, error events, and
     * connection termination.
     *
     * **Request format:**
     * ```json
     * {
     *   "message": "user text",
     *   "session_id": "conversation-id",
     *   "system_prompt": "optional system instructions"
     * }
     * ```
     *
     * **Response (SSE events):**
     * - `data: {"type":"text","text":"chunk"}` - Text delta
     * - `data: {"type":"error","text":"error message"}` - Stream error
     * - `data: {"type":"done"}` - Stream completion
     *
     * **Error handling:**
     * - HTTP errors (4xx, 5xx) → emit [StreamDelta.Error] and close
     * - Malformed SSE events → skip event, continue parsing
     * - Connection loss → emit error on exception
     *
     * **Thread safety:** Safe to call concurrently; runs on IO dispatcher.
     *
     * @param bridgeUrl Base URL of bridge server (e.g., "https://localhost:8922")
     * @param authToken Bearer token for authentication (obtained during bridge setup)
     * @param message User message text to send
     * @param sessionId Conversation/session ID for maintaining context on server
     * @param systemPrompt Optional system instructions to guide response
     *
     * @return Flow<StreamDelta> Cold flow emitting deltas as they arrive
     *         - Subscriptions run on Dispatchers.IO
     *         - Flow completes after Done event or error
     *         - Handles backpressure via callbackFlow
     *
     * @throws IllegalStateException if HTTP response is not successful
     */
    fun sendMessageStream(
        bridgeUrl: String,
        authToken: String,
        message: String,
        sessionId: String,
        systemPrompt: String? = null,
        interactive: Boolean = false
    ): Flow<StreamDelta> = callbackFlow {
        val requestBody = json.encodeToString(
            BridgeRequest.serializer(),
            BridgeRequest(
                message = message,
                session_id = sessionId,
                system_prompt = systemPrompt,
                interactive = interactive
            )
        ).toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("$bridgeUrl/chat")
            .post(requestBody)
            .header("Authorization", "Bearer $authToken")
            .header("Accept", "text/event-stream")
            .build()

        var doneSent = false

        try {
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    trySend(StreamDelta.Error("Bridge server error: ${response.code}"))
                    close()
                    return@callbackFlow
                }

                response.body?.source()?.use { source ->
                    while (!source.exhausted()) {
                        val line = source.readUtf8Line() ?: continue

                        if (line.startsWith("data: ")) {
                            val data = line.removePrefix("data: ").trim()
                            if (data.isEmpty()) continue

                            try {
                                val event = json.decodeFromString(
                                    BridgeStreamEvent.serializer(),
                                    data
                                )
                                when (event.type) {
                                    "text" -> {
                                        event.text?.let { text ->
                                            trySend(StreamDelta.Text(text))
                                        }
                                    }
                                    "tool_use" -> {
                                        val toolName = event.tool ?: "unknown"
                                        trySend(StreamDelta.ToolUse(toolName))
                                    }
                                    "permission_request" -> {
                                        trySend(
                                            StreamDelta.PermissionRequest(
                                                requestId = event.request_id ?: "",
                                                toolName = event.tool_name ?: "unknown",
                                                toolInput = event.tool_input ?: emptyMap(),
                                                description = event.description ?: ""
                                            )
                                        )
                                    }
                                    "done" -> {
                                        trySend(StreamDelta.Done)
                                        doneSent = true
                                        close()
                                        return@callbackFlow
                                    }
                                    "error" -> {
                                        trySend(
                                            StreamDelta.Error(
                                                event.text ?: "Unknown error from bridge"
                                            )
                                        )
                                    }
                                }
                            } catch (e: Exception) {
                                // Skip malformed events, continue parsing
                            }
                        }
                    }

                    if (!doneSent) {
                        trySend(StreamDelta.Done)
                    }
                }
            }
        } catch (e: Exception) {
            trySend(StreamDelta.Error(e.message ?: "Unknown streaming error"))
        }

        close()
        awaitClose()
    }.flowOn(Dispatchers.IO)

    /**
     * Verify bridge server availability and health.
     *
     * Performs a synchronous GET request to the bridge's `/health` endpoint to test:
     * - Network connectivity to bridge server
     * - Bridge server is running and responsive
     * - Authentication token is still valid
     *
     * **Use cases:**
     * - Connection testing after initial bridge configuration
     * - Periodic health checks (recommendations: every 60 seconds or on resume)
     * - Determining fallback to Anthropic API
     *
     * @param bridgeUrl Base URL of bridge server
     * @param authToken Bearer token for authentication
     *
     * @return true if HTTP response is 2xx; false if unreachable, 4xx, or any exception
     *         Never throws; always returns Boolean for safe fallback logic
     */
    /**
     * Send a permission response back to the Bridge for a pending tool approval request.
     *
     * Called when the user taps Allow or Deny on the permission dialog.
     * The Bridge will forward this decision to the Claude CLI process.
     *
     * @param bridgeUrl Base URL of bridge server
     * @param authToken Bearer token for authentication
     * @param sessionId Session ID of the active conversation
     * @param requestId The request_id from the PermissionRequest event
     * @param allow true to allow the tool, false to deny
     * @return true if the response was accepted, false on error
     */
    suspend fun sendPermissionResponse(
        bridgeUrl: String,
        authToken: String,
        sessionId: String,
        requestId: String,
        allow: Boolean
    ): Boolean {
        return try {
            val body = json.encodeToString(
                PermissionResponseRequest.serializer(),
                PermissionResponseRequest(
                    session_id = sessionId,
                    request_id = requestId,
                    behavior = if (allow) "allow" else "deny"
                )
            ).toRequestBody("application/json".toMediaType())

            val request = Request.Builder()
                .url("$bridgeUrl/chat/permission")
                .post(body)
                .header("Authorization", "Bearer $authToken")
                .build()

            httpClient.newCall(request).execute().use { response ->
                response.isSuccessful
            }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Register a user with the Bridge to obtain a per-user token.
     *
     * POSTs to `$bridgeUrl/auth/register` with the master token and username.
     * On success the Bridge returns a per-user token that must replace the master
     * token for all subsequent requests.
     *
     * @param bridgeUrl Base URL of bridge server (e.g., "https://192.168.1.100:8922")
     * @param masterToken Master authentication token configured in the Bridge
     * @param username Username slug (^[a-zA-Z0-9_-]{1,64}$)
     * @return Per-user token string, or null if registration failed
     */
    suspend fun registerUser(bridgeUrl: String, masterToken: String, username: String): String? {
        return try {
            val body = json.encodeToString(
                RegisterRequest.serializer(),
                RegisterRequest(username = username)
            ).toRequestBody("application/json".toMediaType())

            val request = Request.Builder()
                .url("$bridgeUrl/auth/register")
                .post(body)
                .header("Authorization", "Bearer $masterToken")
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use null
                response.body?.string()?.let { bodyStr ->
                    json.decodeFromString(RegisterResponse.serializer(), bodyStr).user_token
                }
            }
        } catch (e: Exception) {
            null
        }
    }

    suspend fun healthCheck(bridgeUrl: String, authToken: String): Boolean {
        return try {
            val request = Request.Builder()
                .url("$bridgeUrl/health")
                .header("Authorization", "Bearer $authToken")
                .build()

            httpClient.newCall(request).execute().use { response ->
                response.isSuccessful
            }
        } catch (e: Exception) {
            false
        }
    }
    /**
     * List files and directories at the given workspace path.
     *
     * @param bridgeUrl Base URL of bridge server
     * @param authToken Bearer token for authentication
     * @param path Relative path within workspace (empty string for root)
     * @return FileListResponse with directory entries, or null on error
     */
    suspend fun listFiles(bridgeUrl: String, authToken: String, path: String = ""): FileListResponse? {
        return try {
            val encodedPath = java.net.URLEncoder.encode(path, "UTF-8")
            val request = Request.Builder()
                .url("$bridgeUrl/files?path=$encodedPath")
                .header("Authorization", "Bearer $authToken")
                .build()
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use null
                response.body?.string()?.let { body ->
                    json.decodeFromString(FileListResponse.serializer(), body)
                }
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Read text file content from the workspace.
     *
     * @param bridgeUrl Base URL of bridge server
     * @param authToken Bearer token for authentication
     * @param path Relative path to file within workspace
     * @return FileContentResponse with file content, or null on error
     */
    suspend fun readFile(bridgeUrl: String, authToken: String, path: String): FileContentResponse? {
        return try {
            val encodedPath = java.net.URLEncoder.encode(path, "UTF-8")
            val request = Request.Builder()
                .url("$bridgeUrl/files/content?path=$encodedPath")
                .header("Authorization", "Bearer $authToken")
                .build()
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use null
                response.body?.string()?.let { body ->
                    json.decodeFromString(FileContentResponse.serializer(), body)
                }
            }
        } catch (e: Exception) {
            null
        }
    }
}

@kotlinx.serialization.Serializable
data class FileEntry(
    val name: String,
    val path: String,
    val type: String,
    val size: Long = 0,
    val modified: String = "",
    val extension: String = ""
)

@kotlinx.serialization.Serializable
data class FileListResponse(
    val path: String = "",
    val entries: List<FileEntry> = emptyList(),
    val parent: String? = null
)

@kotlinx.serialization.Serializable
data class FileContentResponse(
    val path: String,
    val name: String,
    val extension: String = "",
    val size: Int = 0,
    val lines: Int = 0,
    val content: String = ""
)

@kotlinx.serialization.Serializable
internal data class BridgeRequest(
    val message: String,
    val session_id: String,
    val system_prompt: String? = null,
    val interactive: Boolean = false
)

@kotlinx.serialization.Serializable
internal data class BridgeStreamEvent(
    val type: String,
    val text: String? = null,
    val tool: String? = null,
    val request_id: String? = null,
    val tool_name: String? = null,
    val tool_input: Map<String, String>? = null,
    val description: String? = null
)

@kotlinx.serialization.Serializable
internal data class PermissionResponseRequest(
    val session_id: String,
    val request_id: String,
    val behavior: String
)

@kotlinx.serialization.Serializable
internal data class RegisterRequest(
    val username: String
)

@kotlinx.serialization.Serializable
internal data class RegisterResponse(
    val user_token: String,
    val username: String
)
