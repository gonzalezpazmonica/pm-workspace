package com.savia.domain.model

/**
 * Represents a chunk of data from Claude's streaming API response via the Savia Bridge.
 *
 * This sealed class models the different events that can occur during a streaming conversation
 * with Claude. The Bridge server streams responses using Server-Sent Events (SSE), and each
 * event is transformed into a corresponding [StreamDelta] subtype.
 *
 * ## Role in Clean Architecture
 * [StreamDelta] is a domain model that represents the streaming protocol at the business logic
 * level. It abstracts away the raw HTTP/SSE details while providing type-safe handling of
 * stream events in use cases and UI layers.
 *
 * ## Usage Flow
 * 1. Stream begins → emit [Start] with message ID and model info
 * 2. Content arrives → emit [Text] chunks (may occur multiple times)
 * 3. Stream ends → emit either [Done] (success) or [Error] (failure)
 *
 * UI layer observes the flow of [StreamDelta] events and updates the message content
 * and UI state accordingly.
 *
 * ## Streaming Properties
 * - Text chunks arrive independently and may be recombined by the UI
 * - Multiple [Text] events are emitted in order during a single response
 * - A stream should have exactly one [Start] and one terminal event ([Done] or [Error])
 * - Token counting happens at the use case layer after the stream completes
 */
sealed class StreamDelta {
    /**
     * A text fragment from a streaming response.
     *
     * Emitted whenever Claude generates content. Multiple [Text] events
     * may be received for a single assistant message.
     *
     * @property text A portion of the assistant's response
     */
    data class Text(val text: String) : StreamDelta()

    /**
     * Stream initialization event.
     *
     * Emitted at the start of a streaming response. Contains the message ID
     * assigned by the server and the model name being used.
     *
     * @property messageId Server-assigned identifier for the response message
     * @property model Name of the Claude model (e.g., "claude-3-5-sonnet")
     */
    data class Start(val messageId: String, val model: String) : StreamDelta()

    /**
     * Stream completion event (success).
     *
     * Emitted when the stream finishes successfully. No more [Text] events
     * will be received after this.
     */
    data object Done : StreamDelta()

    /**
     * Stream error event.
     *
     * Emitted when the streaming connection fails or the Bridge server returns
     * an error. The stream is terminated after this event.
     *
     * @property message Human-readable error description
     */
    data class Error(val message: String) : StreamDelta()

    /**
     * Tool usage event from Bridge.
     *
     * Emitted when Claude invokes a tool (Read, Write, Bash, etc.) during
     * a streaming response. Shows the user what actions Claude is taking.
     *
     * @property toolName Name of the tool being used (e.g., "Read", "Bash")
     */
    data class ToolUse(val toolName: String) : StreamDelta()
}
