import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import EmptyState from '../../components/EmptyState.vue'

describe('EmptyState', () => {
  it('renders the required title prop', () => {
    const wrapper = mount(EmptyState, { props: { title: 'No data found' } })
    expect(wrapper.find('.empty-title').text()).toBe('No data found')
  })

  it('renders icon when provided', () => {
    const wrapper = mount(EmptyState, { props: { title: 'Empty', icon: '📭' } })
    expect(wrapper.find('.empty-icon').text()).toBe('📭')
  })

  it('does not render icon element when not provided', () => {
    const wrapper = mount(EmptyState, { props: { title: 'Empty' } })
    expect(wrapper.find('.empty-icon').exists()).toBe(false)
  })

  it('renders description when provided', () => {
    const wrapper = mount(EmptyState, {
      props: { title: 'Empty', description: 'Try again later' },
    })
    expect(wrapper.find('.empty-desc').text()).toBe('Try again later')
  })

  it('does not render description when not provided', () => {
    const wrapper = mount(EmptyState, { props: { title: 'Empty' } })
    expect(wrapper.find('.empty-desc').exists()).toBe(false)
  })

  it('renders slot content', () => {
    const wrapper = mount(EmptyState, {
      props: { title: 'Empty' },
      slots: { default: '<button>Retry</button>' },
    })
    expect(wrapper.find('button').text()).toBe('Retry')
  })
})
