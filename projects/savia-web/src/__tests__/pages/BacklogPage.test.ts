import { describe, it, expect, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import BacklogPage from '../../pages/BacklogPage.vue'

describe('BacklogPage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(BacklogPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the backlog title', () => {
    const wrapper = shallowMount(BacklogPage)
    expect(wrapper.find('.backlog-title').text()).toBe('Backlog')
  })

  it('renders view toggle buttons', () => {
    const wrapper = shallowMount(BacklogPage)
    const buttons = wrapper.findAll('.view-toggle button')
    expect(buttons.length).toBe(2)
  })
})
