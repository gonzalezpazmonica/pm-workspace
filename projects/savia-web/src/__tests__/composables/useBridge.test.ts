import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

// Mock fetch globally
const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

// Must import after stubbing globals
const { useBridge } = await import('../../composables/useBridge')
const { useAuthStore } = await import('../../stores/auth')

describe('useBridge', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockFetch.mockReset()
    localStorage.clear()
  })

  describe('baseUrl', () => {
    it('builds http url when TLS is off', () => {
      const auth = useAuthStore()
      auth.save('localhost', '8922', '', false)
      const { baseUrl } = useBridge()
      expect(baseUrl()).toBe('http://localhost:8922')
    })

    it('builds https url from serverUrl', () => {
      const auth = useAuthStore()
      auth.save('myserver.local', '9443', '', true)
      const { baseUrl } = useBridge()
      expect(baseUrl()).toBe('https://myserver.local:9443')
    })
  })

  describe('headers', () => {
    it('includes Content-Type always', () => {
      const { headers } = useBridge()
      const h = headers() as Record<string, string>
      expect(h['Content-Type']).toBe('application/json')
    })

    it('includes Authorization header when token is present', () => {
      const auth = useAuthStore()
      auth.token = 'my-secret-token'
      const { headers } = useBridge()
      const h = headers() as Record<string, string>
      expect(h['Authorization']).toBe('Bearer my-secret-token')
    })

    it('omits Authorization header when token is empty', () => {
      const auth = useAuthStore()
      auth.token = ''
      const { headers } = useBridge()
      const h = headers() as Record<string, string>
      expect(h['Authorization']).toBeUndefined()
    })
  })

  describe('get', () => {
    it('returns parsed json on successful response', async () => {
      const payload = { id: 1, name: 'test' }
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => payload,
      })
      const { get } = useBridge()
      const result = await get('/dashboard')
      expect(result).toEqual(payload)
    })

    it('returns null when response is not ok', async () => {
      mockFetch.mockResolvedValueOnce({ ok: false })
      const { get } = useBridge()
      const result = await get('/dashboard')
      expect(result).toBeNull()
    })

    it('returns null on network error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network Error'))
      const { get } = useBridge()
      const result = await get('/dashboard')
      expect(result).toBeNull()
    })
  })

  describe('post', () => {
    it('sends POST with JSON body and returns parsed response', async () => {
      const payload = { success: true }
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => payload,
      })
      const { post } = useBridge()
      const result = await post('/chat', { message: 'hello' })
      expect(result).toEqual(payload)
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/chat'),
        expect.objectContaining({ method: 'POST' })
      )
    })

    it('returns null when post response is not ok', async () => {
      mockFetch.mockResolvedValueOnce({ ok: false })
      const { post } = useBridge()
      const result = await post('/chat', {})
      expect(result).toBeNull()
    })

    it('returns null on network error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('timeout'))
      const { post } = useBridge()
      const result = await post('/chat', {})
      expect(result).toBeNull()
    })
  })

  describe('healthCheck', () => {
    it('returns true when /dashboard responds ok', async () => {
      mockFetch.mockResolvedValueOnce({ ok: true })
      const { healthCheck } = useBridge()
      expect(await healthCheck()).toBe(true)
    })

    it('returns false when response is not ok', async () => {
      mockFetch.mockResolvedValueOnce({ ok: false })
      const { healthCheck } = useBridge()
      expect(await healthCheck()).toBe(false)
    })

    it('returns false on network error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('refused'))
      const { healthCheck } = useBridge()
      expect(await healthCheck()).toBe(false)
    })
  })
})
