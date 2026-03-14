import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import FileBrowserPage from '../../pages/FileBrowserPage.vue'

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: vi.fn().mockResolvedValue({ entries: [] }) }),
}))

describe('FileBrowserPage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(FileBrowserPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the Files heading', () => {
    const wrapper = shallowMount(FileBrowserPage)
    expect(wrapper.find('h1').text()).toBe('Files')
  })

  it('renders the path display', () => {
    const wrapper = shallowMount(FileBrowserPage)
    expect(wrapper.find('.path').exists()).toBe(true)
  })
})
