import { describe, it, expect, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import PipelinesPage from '../../pages/PipelinesPage.vue'

describe('PipelinesPage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(PipelinesPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the page title', () => {
    const wrapper = shallowMount(PipelinesPage)
    expect(wrapper.find('.page-title').text()).toContain('Pipelines')
  })
})
