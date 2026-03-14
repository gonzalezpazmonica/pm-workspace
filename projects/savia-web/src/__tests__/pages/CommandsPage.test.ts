import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'

const { default: CommandsPage } = await import('../../pages/CommandsPage.vue')

describe('CommandsPage', () => {
  it('renders without errors', () => {
    const wrapper = mount(CommandsPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the Commands heading', () => {
    const wrapper = mount(CommandsPage)
    expect(wrapper.find('h1').text()).toBe('Commands')
  })

  it('renders command family cards', () => {
    const wrapper = mount(CommandsPage)
    const cards = wrapper.findAll('.family-card')
    expect(cards.length).toBeGreaterThanOrEqual(6)
  })

  it('renders command items inside the cards', () => {
    const wrapper = mount(CommandsPage)
    const items = wrapper.findAll('.cmd-item')
    expect(items.length).toBeGreaterThan(0)
    expect(items[0].text()).toMatch(/^\//)
  })
})
