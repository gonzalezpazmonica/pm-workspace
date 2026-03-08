# Savia Mobile Android - Bridge Migration

## Overview

The Savia Mobile Android app has been updated to connect to a local HTTP bridge server (`savia-bridge.py`) instead of the Anthropic API directly. This allows users to run a local bridge server on their PC and have the Android app communicate with it.

## Architecture Changes

### New Components

1. **SaviaBridgeService** (`data/src/main/kotlin/com/savia/data/api/SaviaBridgeService.kt`)
   - OkHttp-based client for the bridge server
   - Handles SSE streaming responses with bridge protocol format
   - Implements `/chat` and `/health` endpoints
   - Uses Bearer token authentication

2. **SecurityRepository Interface Updates**
   - Added bridge configuration methods: `saveBridgeConfig()`, `getBridgeHost()`, `getBridgePort()`, `getBridgeToken()`, `hasBridgeConfig()`, `getBridgeUrl()`, `deleteBridgeConfig()`
   - Maintains backward compatibility with API key methods

3. **SecurityRepositoryImpl Implementation**
   - Securely stores bridge configuration (host, port, token) using Tink AEAD
   - Storage keys: `bridge_host`, `bridge_port`, `bridge_token`

4. **NetworkModule Updates**
   - Added provider for `SaviaBridgeService`
   - Maintains Retrofit configuration for fallback to Anthropic API
   - Supports configurable base URLs for testing

### Modified Components

**ChatRepositoryImpl**
- Added dependency on `SaviaBridgeService`
- Implements dynamic routing: checks `hasBridgeConfig()` to decide between bridge and API
- If bridge is configured: uses `bridgeService.sendMessageStream()`
- If bridge is not configured: falls back to original Anthropic API flow
- Message saving and conversation management works identically for both modes

## Bridge Server Protocol

### Request Format (POST /chat)

```json
{
  "message": "user text here",
  "session_id": "conversation-uuid",
  "system_prompt": "optional system instructions"
}
```

### Headers

```
Authorization: Bearer {token}
Accept: text/event-stream
Content-Type: application/json
```

### Response (Server-Sent Events)

Streaming text chunks:
```
data: {"type":"text","text":"response chunk"}
```

End of stream:
```
data: {"type":"done"}
```

Errors:
```
data: {"type":"error","text":"error message"}
```

### Health Check Endpoint (GET /health)

```
GET /health
Authorization: Bearer {token}

Response (200 OK):
{"status": "ok"}
```

## Configuration Management

### Storing Bridge Configuration

```kotlin
// In a configuration screen or setup flow:
securityRepository.saveBridgeConfig(
    host = "192.168.1.100",  // User's PC IP
    port = 8000,
    token = "user-provided-token"
)
```

### Checking if Bridge is Configured

```kotlin
if (securityRepository.hasBridgeConfig()) {
    // Bridge is configured, will use it
} else {
    // Fall back to API key configuration
}
```

### Getting Bridge URL

```kotlin
val bridgeUrl = securityRepository.getBridgeUrl()  // Returns "http://192.168.1.100:8000"
```

## Message Flow

1. User sends a message in the chat UI
2. `ChatRepositoryImpl.sendMessage()` is called
3. Check if bridge is configured:
   - **If YES**: Use `SaviaBridgeService.sendMessageStream()`
     - Build bridge request format: `{"message": "...", "session_id": "...", "system_prompt": "..."}`
     - Send to `{bridgeUrl}/chat` with Bearer token
     - Parse SSE response and emit `StreamDelta` events
   - **If NO**: Use original Anthropic API flow
4. Collect response text and save assistant message to local database
5. Update conversation timestamp
4. Auto-generate title if first exchange

## Key Differences from Anthropic API

| Aspect | Anthropic API | Bridge Server |
|--------|---------------|---------------|
| **Auth** | `x-api-key` header | `Authorization: Bearer` header |
| **Request** | Complex `CreateMessageRequest` with message array | Simple JSON: `message`, `session_id`, `system_prompt` |
| **Base URL** | `https://api.anthropic.com` | `http://{host}:{port}` |
| **Streaming** | Claude-specific SSE format | Simple format: `{"type":"text","text":"..."}`  |
| **Message History** | Sent with each request | Managed by bridge server |

## Data Storage

Bridge configuration is stored securely using Android Keystore + Tink encryption:

- **Key: `bridge_host`** — Server IP/hostname
- **Key: `bridge_port`** — Server port (stored as string, parsed as Int)
- **Key: `bridge_token`** — Bearer token for authentication

All keys are stored in `secureStorage` (Tink-encrypted shared preferences).

## Backward Compatibility

The app maintains full backward compatibility with the Anthropic API:

- If bridge config is not set, the app automatically uses the API key
- Users can switch between bridge and API by:
  - Having bridge configured: uses bridge
  - Deleting bridge config + having API key: uses API
  - Both configured: bridge takes precedence

## Testing the Bridge Integration

### Manual Testing

1. Configure bridge in settings:
   ```kotlin
   securityRepository.saveBridgeConfig(
       host = "192.168.1.100",
       port = 8000,
       token = "test-token"
   )
   ```

2. Send a message in the chat UI
3. Verify response arrives via bridge (check bridge server logs)

### Unit Testing

```kotlin
// Mock SaviaBridgeService
val mockBridgeService = mockk<SaviaBridgeService>()
every { mockBridgeService.sendMessageStream(...) } returns flowOf(
    StreamDelta.Text("Hello "),
    StreamDelta.Text("World"),
    StreamDelta.Done
)

// Mock security repository
val mockSecurity = mockk<SecurityRepository>()
every { mockSecurity.hasBridgeConfig() } returns true
every { mockSecurity.getBridgeUrl() } returns "http://localhost:8000"
every { mockSecurity.getBridgeToken() } returns "test-token"

// Create repository with mocks
val chatRepo = ChatRepositoryImpl(
    apiService = mockk(),
    bridgeService = mockBridgeService,
    streamParser = mockk(),
    conversationDao = mockk(),
    securityRepository = mockSecurity
)

// Test sending message
chatRepo.sendMessage("conv-1", "Hi").collect { delta ->
    // Verify delta events
}
```

## File Changes Summary

| File | Changes |
|------|---------|
| `data/src/main/kotlin/com/savia/data/api/SaviaBridgeService.kt` | **NEW** - Bridge server client |
| `domain/src/main/kotlin/com/savia/domain/repository/SecurityRepository.kt` | Added bridge config methods |
| `data/src/main/kotlin/com/savia/data/repository/SecurityRepositoryImpl.kt` | Implemented bridge methods |
| `app/src/main/kotlin/com/savia/mobile/di/NetworkModule.kt` | Added `provideSaviaBridgeService()` |
| `data/src/main/kotlin/com/savia/data/repository/ChatRepositoryImpl.kt` | Added bridge routing logic |

## Migration Checklist

- [x] Create `SaviaBridgeService` for OkHttp-based bridge communication
- [x] Update `SecurityRepository` interface with bridge configuration methods
- [x] Implement bridge methods in `SecurityRepositoryImpl`
- [x] Update `NetworkModule` to provide `SaviaBridgeService`
- [x] Update `ChatRepositoryImpl` to support dynamic routing
- [x] Maintain backward compatibility with Anthropic API
- [ ] Add UI screens for bridge configuration (Settings)
- [ ] Add health check functionality to verify bridge connectivity
- [ ] Add tests for bridge service
- [ ] Add documentation for users on setting up the bridge

## Next Steps

1. **UI Implementation**: Add settings screen to configure bridge host, port, and token
2. **Health Check UI**: Show connectivity status to bridge server
3. **Error Handling**: Enhanced error messages when bridge is unreachable
4. **Testing**: Unit and integration tests for bridge service
5. **Documentation**: User guide for bridge setup and configuration
