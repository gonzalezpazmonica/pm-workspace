import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import LoadingSpinner from '../../components/LoadingSpinner.vue'

describe('LoadingSpinner', () => {
  it('renders the spinner element', () => {
    const wrapper = mount(LoadingSpinner)
    expect(wrapper.find('.spinner').exists()).toBe(true)
  })

  it('does not render spinner-text when no slot content', () => {
    const wrapper = mount(LoadingSpinner)
    expect(wrapper.find('.spinner-text').exists()).toBe(false)
  })

  it('renders slot text when provided', () => {
    const wrapper = mount(LoadingSpinner, {
      slots: { default: 'Loading data...' },
    })
    expect(wrapper.find('.spinner-text').text()).toBe('Loading data...')
  })

  it('renders slot with html content', () => {
    const wrapper = mount(LoadingSpinner, {
      slots: { default: '<strong>Please wait</strong>' },
    })
    expect(wrapper.find('.spinner-text').text()).toBe('Please wait')
  })
})
