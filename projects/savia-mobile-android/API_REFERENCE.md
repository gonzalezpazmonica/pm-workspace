# Savia Mobile — Referencia de API

> Documentación de endpoints del servidor Savia Bridge (savia-bridge.py) que Savia Mobile consume.

## Visión General

Savia Mobile se comunica con Claude Code CLI a través de un servidor bridge HTTP/HTTPS llamado **Savia Bridge**. Este servidor:

1. Recibe solicitudes de chat de la app Android
2. Llama a Claude Code CLI localmente
3. Streamea la respuesta de vuelta a la app

No hay API remota pública — todo corre en la máquina del usuario.

## Base URL

```
http://{bridge-host}:{bridge-port}
```

Example:
```
http://<YOUR_PC_IP>:8000
```

## Authentication

All requests require a Bearer token in the `Authorization` header:

```
Authorization: Bearer {token}
```

Example:
```
Authorization: Bearer eJydUMtOwzAM/BXLZ...
```

## Endpoints

### POST /chat

Send a message and receive a streaming response.

**Request:**

```
POST /chat HTTP/1.1
Host: {bridge-host}:{bridge-port}
Authorization: Bearer {token}
Accept: text/event-stream
Content-Type: application/json

{
  "message": "Hello, how are you?",
  "session_id": "conv-12345",
  "system_prompt": "You are a helpful assistant"
}
```

**Request Body Schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | string | Yes | The user message to send |
| `session_id` | string | Yes | Conversation/session identifier (UUID) |
| `system_prompt` | string | No | System instructions for this request |

**Response Format:**

Server-Sent Events (SSE) with JSON data:

```
data: {"type":"text","text":"Hello! I'm "}
data: {"type":"text","text":"doing great, "}
data: {"type":"text","text":"thanks for asking!"}
data: {"type":"done"}
```

**Response Event Types:**

| Type | Fields | Meaning |
|------|--------|---------|
| `text` | `text: string` | Text chunk to append to response |
| `done` | (none) | Stream complete |
| `error` | `text: string` | Error occurred (includes error message) |

**Example Response Stream:**

```
data: {"type":"text","text":"The "}
data: {"type":"text","text":"quick brown fox "}
data: {"type":"text","text":"jumps over the lazy dog"}
data: {"type":"done"}
```

**HTTP Status Codes:**

| Code | Meaning |
|------|---------|
| 200 | Success, stream follows |
| 401 | Unauthorized (invalid token) |
| 400 | Bad request (invalid JSON or missing fields) |
| 500 | Server error |

### GET /health

Check if the bridge server is running and accessible.

**Request:**

```
GET /health HTTP/1.1
Host: {bridge-host}:{bridge-port}
Authorization: Bearer {token}
```

**Response (200 OK):**

```json
{
  "status": "ok"
}
```

**Response (401 Unauthorized):**

```
Invalid or missing Authorization header
```

## Data Types

### Message Request

```kotlin
@Serializable
data class BridgeRequest(
    val message: String,           // User message text
    val session_id: String,        // Conversation ID
    val system_prompt: String? = null  // Optional system instructions
)
```

### Stream Event

```kotlin
@Serializable
data class BridgeStreamEvent(
    val type: String,     // "text" | "done" | "error"
    val text: String? = null  // For "text" and "error" types
)
```

### StreamDelta (Android App Internal)

```kotlin
sealed class StreamDelta {
    data class Start(val messageId: String, val model: String) : StreamDelta()
    data class Text(val text: String) : StreamDelta()
    object Done : StreamDelta()
    data class Error(val message: String) : StreamDelta()
}
```

## Implementation in Android App

### SaviaBridgeService Usage

```kotlin
// Inject the service
@Inject
lateinit var bridgeService: SaviaBridgeService

// Send message with streaming response
val flow = bridgeService.sendMessageStream(
    bridgeUrl = "http://<YOUR_PC_IP>:8000",
    authToken = "user-provided-token",
    message = "What is Kotlin?",
    sessionId = "conv-12345",
    systemPrompt = null  // Optional
)

// Collect responses
flow.collect { delta ->
    when (delta) {
        is StreamDelta.Text -> {
            // Append text to UI
            responseText += delta.text
        }
        is StreamDelta.Done -> {
            // Save message to database
            saveMessage(Message(content = responseText))
        }
        is StreamDelta.Error -> {
            // Show error to user
            showErrorDialog(delta.message)
        }
        else -> {}
    }
}
```

### Security Repository Usage

```kotlin
// Save bridge configuration
securityRepository.saveBridgeConfig(
    host = "<YOUR_PC_IP>",
    port = 8000,
    token = "user-provided-token"
)

// Check if configured
if (securityRepository.hasBridgeConfig()) {
    val url = securityRepository.getBridgeUrl()  // "http://<YOUR_PC_IP>:8000"
    val token = securityRepository.getBridgeToken()  // User's token
    // Use bridge
}

// Verify connectivity
val isHealthy = bridgeService.healthCheck(
    bridgeUrl = "http://<YOUR_PC_IP>:8000",
    authToken = "token"
)
```

## Message Flow Example

### Request-Response Sequence

```
Client (Android App)                Bridge Server
        |                                    |
        |------ POST /chat ---------->      |
        |  Body: {                          |
        |    "message": "Hi",               |
        |    "session_id": "conv-123"       |
        |  }                                |
        |                                    |
        |<---- data: {"type":"text",...} --- |
        |<---- data: {"type":"text",...} --- |
        |<---- data: {"type":"done"} ------- |
        |                                    |
```

### Complete Flow

1. **User types:** "What is AI?"
2. **ChatRepositoryImpl.sendMessage()** called:
   - Checks if bridge is configured
   - Builds BridgeRequest: `{"message": "What is AI?", "session_id": "conv-123"}`
   - Calls `bridgeService.sendMessageStream()`
3. **SaviaBridgeService** handles:
   - Serializes request to JSON
   - Creates HTTP POST to `/chat`
   - Adds Authorization header with token
   - Opens SSE stream
4. **Bridge Server** processes:
   - Validates token
   - Processes message with Claude/LLM
   - Streams response chunks as SSE events
5. **App receives stream:**
   - Parses each `data: {...}` line
   - Emits StreamDelta.Text for chunks
   - Emits StreamDelta.Done at end
6. **ChatRepositoryImpl collects:**
   - Accumulates text chunks
   - On Done: saves MessageEntity to database
   - Updates conversation timestamp

## Error Handling

### Bridge Connection Errors

```kotlin
// When bridge is unreachable or times out
// SaviaBridgeService catches exception and emits:
trySend(StreamDelta.Error("Connection failed or timeout"))
```

### Authentication Errors

Bridge responds with 401:
```
No response body, just HTTP 401 status
```

App treats as error:
```kotlin
if (!response.isSuccessful) {
    trySend(StreamDelta.Error("Bridge server error: 401"))
}
```

### Malformed Response

If bridge returns invalid JSON:
```kotlin
try {
    val event = json.decodeFromString(BridgeStreamEvent.serializer(), data)
} catch (e: Exception) {
    // Skip malformed events, continue parsing
}
```

## Configuration Examples

### Using Bridge

```kotlin
// Setup
securityRepository.saveBridgeConfig("<YOUR_PC_IP>", 8000, "my-token")

// SendMessage will automatically use bridge
val deltas = chatRepository.sendMessage("conv-1", "Hello")
```

### Using API (Fallback)

```kotlin
// No bridge config
securityRepository.deleteBridgeConfig()

// Save API key instead
securityRepository.saveApiKey("sk-ant-...")

// SendMessage will use Anthropic API
val deltas = chatRepository.sendMessage("conv-1", "Hello")
```

## Performance Considerations

1. **Network Latency:** Bridge server should be on same LAN as Android device
2. **Timeout:** OkHttp configured with:
   - Connect: 30 seconds
   - Read: 120 seconds (for streaming)
   - Write: 30 seconds
3. **Streaming:** Response chunks streamed as received, no buffering
4. **Concurrency:** Multiple concurrent messages supported (separate connections)

## Security Best Practices

1. **Token Storage:** Never hardcode tokens, use SecurityRepository
2. **TLS:** Use HTTPS in production (HTTP OK for development/LAN)
3. **Token Rotation:** Implement token refresh mechanism
4. **Message Validation:** Bridge should validate message format
5. **Rate Limiting:** Bridge can implement rate limiting per token

## Debugging Tips

### Check Bridge Connectivity

```kotlin
// Manual health check
val isHealthy = bridgeService.healthCheck("http://<YOUR_PC_IP>:8000", "token")
```

### Monitor Network Traffic

```
adb shell tcpdump -i any -w /sdcard/bridge.pcap
# Then examine with Wireshark
```

### Check Logs

```
adb logcat | grep -i "bridge\|savia"
```

### Bridge Server Logs

Check bridge server's logs to see:
- Incoming requests
- Token validation
- Processing errors
- Response streaming

## Troubleshooting

### Bridge Returns 401 Unauthorized

- Verify token is correct
- Check Authorization header format: `Bearer {token}`
- Verify bridge server has same token configured

### Connection Timeouts

- Check host IP is correct
- Verify port is open
- Check firewall rules
- Ensure bridge server is running
- Check network connectivity between devices

### Garbled or Missing Responses

- Check Accept header is `text/event-stream`
- Verify bridge returns proper SSE format
- Check message encoding (should be UTF-8)

### App Crashes on StreamDelta

- Ensure StreamDelta classes match implementation
- Check Kotlin serialization version compatibility
- Verify Flow<> types are correct

## Examples

### Simple Message

Request:
```json
{
  "message": "Hello",
  "session_id": "conv-001"
}
```

Response:
```
data: {"type":"text","text":"Hi there! "}
data: {"type":"text","text":"How can I help?"}
data: {"type":"done"}
```

### With System Prompt

Request:
```json
{
  "message": "What is 2+2?",
  "session_id": "conv-002",
  "system_prompt": "You are a math tutor. Be concise."
}
```

Response:
```
data: {"type":"text","text":"2 + 2 = 4"}
data: {"type":"done"}
```

### Error Response

Response:
```
data: {"type":"error","text":"Invalid session ID format"}
data: {"type":"done"}
```
