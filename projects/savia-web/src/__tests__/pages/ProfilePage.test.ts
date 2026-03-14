import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import ProfilePage from '../../pages/ProfilePage.vue'

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: vi.fn().mockResolvedValue(null) }),
}))

describe('ProfilePage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(ProfilePage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the Profile heading', () => {
    const wrapper = shallowMount(ProfilePage)
    expect(wrapper.find('h1').text()).toBe('Profile')
  })
})
