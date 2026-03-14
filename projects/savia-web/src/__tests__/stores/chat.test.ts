import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useChatStore } from '../../stores/chat'
import type { ChatMessage } from '../../types/chat'

function makeMsg(overrides: Partial<ChatMessage> = {}): ChatMessage {
  return {
    id: 'msg-1',
    role: 'user',
    content: 'Hello',
    timestamp: Date.now(),
    isStreaming: false,
    ...overrides,
  }
}

describe('useChatStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('starts with empty messages array', () => {
    const store = useChatStore()
    expect(store.messages).toHaveLength(0)
  })

  it('starts with a valid sessionId', () => {
    const store = useChatStore()
    expect(store.sessionId).toBeTruthy()
    expect(typeof store.sessionId).toBe('string')
  })

  it('starts with null currentTool and pendingPermission', () => {
    const store = useChatStore()
    expect(store.currentTool).toBeNull()
    expect(store.pendingPermission).toBeNull()
  })

  describe('addMessage', () => {
    it('appends a message to the list', () => {
      const store = useChatStore()
      store.addMessage(makeMsg())
      expect(store.messages).toHaveLength(1)
      expect(store.messages[0].content).toBe('Hello')
    })

    it('appends multiple messages in order', () => {
      const store = useChatStore()
      store.addMessage(makeMsg({ id: '1', content: 'First' }))
      store.addMessage(makeMsg({ id: '2', content: 'Second' }))
      expect(store.messages[0].content).toBe('First')
      expect(store.messages[1].content).toBe('Second')
    })
  })

  describe('updateLastAssistant', () => {
    it('appends text to last streaming assistant message', () => {
      const store = useChatStore()
      store.addMessage(makeMsg({ role: 'assistant', content: 'Start', isStreaming: true }))
      store.updateLastAssistant(' more')
      expect(store.messages[0].content).toBe('Start more')
    })

    it('does nothing when no streaming assistant message exists', () => {
      const store = useChatStore()
      store.addMessage(makeMsg({ role: 'user', content: 'User msg', isStreaming: false }))
      expect(() => store.updateLastAssistant('text')).not.toThrow()
      expect(store.messages[0].content).toBe('User msg')
    })

    it('updates only the last streaming assistant', () => {
      const store = useChatStore()
      store.addMessage(makeMsg({ id: '1', role: 'assistant', content: 'A', isStreaming: false }))
      store.addMessage(makeMsg({ id: '2', role: 'assistant', content: 'B', isStreaming: true }))
      store.updateLastAssistant('!')
      expect(store.messages[0].content).toBe('A')
      expect(store.messages[1].content).toBe('B!')
    })
  })

  describe('finishStreaming', () => {
    it('sets isStreaming to false on all messages', () => {
      const store = useChatStore()
      store.addMessage(makeMsg({ role: 'assistant', isStreaming: true }))
      store.finishStreaming()
      expect(store.messages[0].isStreaming).toBe(false)
    })

    it('clears currentTool', () => {
      const store = useChatStore()
      store.currentTool = 'Bash'
      store.finishStreaming()
      expect(store.currentTool).toBeNull()
    })
  })

  describe('clearMessages', () => {
    it('empties the messages array', () => {
      const store = useChatStore()
      store.addMessage(makeMsg())
      store.clearMessages()
      expect(store.messages).toHaveLength(0)
    })

    it('resets to a new sessionId', () => {
      const store = useChatStore()
      const oldSession = store.sessionId
      store.clearMessages()
      expect(store.sessionId).not.toBe(oldSession)
    })
  })
})
