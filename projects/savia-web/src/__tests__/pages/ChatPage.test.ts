import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useChatStore } from '../../stores/chat'

vi.mock('../../composables/useSSE', () => ({
  useSSE: () => ({
    isStreaming: { value: false },
    streamChat: vi.fn(),
    sendPermission: vi.fn(),
  }),
}))

const { default: ChatPage } = await import('../../pages/ChatPage.vue')

describe('ChatPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders without errors', () => {
    const wrapper = mount(ChatPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the messages container', () => {
    const wrapper = mount(ChatPage)
    expect(wrapper.find('.messages').exists()).toBe(true)
  })

  it('renders the input form', () => {
    const wrapper = mount(ChatPage)
    expect(wrapper.find('form.input-bar').exists()).toBe(true)
    expect(wrapper.find('input').exists()).toBe(true)
  })

  it('renders stored messages', () => {
    const store = useChatStore()
    store.messages = [
      { id: '1', role: 'user', content: 'Hello Savia', timestamp: Date.now(), isStreaming: false },
      { id: '2', role: 'assistant', content: 'Hi there', timestamp: Date.now(), isStreaming: false },
    ]
    const wrapper = mount(ChatPage)
    expect(wrapper.findAll('.msg').length).toBe(2)
  })

  it('renders permission bar when pending permission exists', () => {
    const store = useChatStore()
    store.pendingPermission = {
      requestId: 'req1',
      toolName: 'Bash',
      toolInput: {},
      description: 'Run a command',
    }
    const wrapper = mount(ChatPage)
    expect(wrapper.find('.permission-bar').exists()).toBe(true)
    expect(wrapper.find('.permission-bar').text()).toContain('Bash')
  })
})
