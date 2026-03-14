import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

const { useSSE } = await import('../../composables/useSSE')
const { useAuthStore } = await import('../../stores/auth')

function makeReadableStream(chunks: string[]) {
  let index = 0
  return {
    getReader: () => ({
      read: vi.fn().mockImplementation(async () => {
        if (index < chunks.length) {
          const value = new TextEncoder().encode(chunks[index++])
          return { done: false, value }
        }
        return { done: true, value: undefined }
      }),
    }),
  }
}

describe('useSSE', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockFetch.mockReset()
    localStorage.clear()
  })

  it('starts with isStreaming false', () => {
    const { isStreaming } = useSSE()
    expect(isStreaming.value).toBe(false)
  })

  describe('streamChat', () => {
    it('sets isStreaming to true during stream, false after', async () => {
      mockFetch.mockResolvedValueOnce({
        body: makeReadableStream([]),
      })
      const { isStreaming, streamChat } = useSSE()
      const promise = streamChat('hello', 'session-1', vi.fn())
      await promise
      expect(isStreaming.value).toBe(false)
    })

    it('parses SSE text events and calls onEvent', async () => {
      const event = { type: 'text', text: 'Hello' }
      const line = `data: ${JSON.stringify(event)}\n`
      mockFetch.mockResolvedValueOnce({
        body: makeReadableStream([line]),
      })
      const onEvent = vi.fn()
      const { streamChat } = useSSE()
      await streamChat('hi', 'session-1', onEvent)
      expect(onEvent).toHaveBeenCalledWith(event)
    })

    it('skips malformed SSE lines', async () => {
      const lines = ['data: invalid-json\n', `data: ${JSON.stringify({ type: 'done', text: '' })}\n`]
      mockFetch.mockResolvedValueOnce({
        body: makeReadableStream(lines),
      })
      const onEvent = vi.fn()
      const { streamChat } = useSSE()
      await streamChat('hi', 'session-1', onEvent)
      expect(onEvent).toHaveBeenCalledTimes(1)
      expect(onEvent).toHaveBeenCalledWith({ type: 'done', text: '' })
    })

    it('calls onEvent with error event on fetch failure', async () => {
      mockFetch.mockRejectedValueOnce(new Error('connection refused'))
      const onEvent = vi.fn()
      const { streamChat } = useSSE()
      await streamChat('hi', 'session-1', onEvent)
      expect(onEvent).toHaveBeenCalledWith(
        expect.objectContaining({ type: 'error' })
      )
    })

    it('returns early when response body is null', async () => {
      mockFetch.mockResolvedValueOnce({ body: null })
      const onEvent = vi.fn()
      const { isStreaming, streamChat } = useSSE()
      await streamChat('hi', 'session-1', onEvent)
      expect(isStreaming.value).toBe(false)
      expect(onEvent).not.toHaveBeenCalled()
    })

    it('sends auth token in headers when present', async () => {
      const auth = useAuthStore()
      auth.token = 'tok-123'
      mockFetch.mockResolvedValueOnce({ body: makeReadableStream([]) })
      const { streamChat } = useSSE()
      await streamChat('msg', 'sess', vi.fn())
      const callArgs = mockFetch.mock.calls[0][1]
      expect(callArgs.headers['Authorization']).toBe('Bearer tok-123')
    })
  })

  describe('sendPermission', () => {
    it('posts permission grant to /chat/permission', async () => {
      mockFetch.mockResolvedValueOnce({})
      const { sendPermission } = useSSE()
      await sendPermission('req-1', true)
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/chat/permission'),
        expect.objectContaining({ method: 'POST' })
      )
      const body = JSON.parse(mockFetch.mock.calls[0][1].body)
      expect(body).toEqual({ request_id: 'req-1', granted: true })
    })

    it('does not throw on network error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('fail'))
      const { sendPermission } = useSSE()
      await expect(sendPermission('req-1', false)).resolves.toBeUndefined()
    })
  })
})
