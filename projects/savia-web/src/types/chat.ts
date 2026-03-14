export interface ChatMessage {
  id: string
  role: 'user' | 'assistant' | 'system'
  content: string
  timestamp: number
  isStreaming: boolean
}

export type StreamEventType =
  | 'text'
  | 'start'
  | 'done'
  | 'error'
  | 'tool_use'
  | 'permission_request'

export interface StreamEvent {
  type: StreamEventType
  text: string
  messageId?: string
  model?: string
  toolName?: string
  requestId?: string
  toolInput?: Record<string, string>
  description?: string
}

export interface PermissionInfo {
  requestId: string
  toolName: string
  toolInput: Record<string, string>
  description: string
}
