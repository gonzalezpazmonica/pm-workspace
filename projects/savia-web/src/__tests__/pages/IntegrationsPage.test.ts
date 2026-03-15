import { describe, it, expect, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import IntegrationsPage from '../../pages/IntegrationsPage.vue'

describe('IntegrationsPage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(IntegrationsPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the page title', () => {
    const wrapper = shallowMount(IntegrationsPage)
    expect(wrapper.find('.page-title').text()).toContain('Integrations')
  })
})
