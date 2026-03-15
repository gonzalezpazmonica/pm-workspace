import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import RegisterWizard from '../../components/RegisterWizard.vue'

vi.stubGlobal('fetch', vi.fn())

describe('RegisterWizard', () => {
  const baseProps = { slug: 'alice', serverUrl: 'https://localhost:8922', token: 'tok' }

  beforeEach(() => {
    setActivePinia(createPinia())
    vi.mocked(fetch).mockReset()
  })

  it('renders the welcome message with slug', () => {
    const wrapper = shallowMount(RegisterWizard, { props: baseProps })
    expect(wrapper.find('h2').text()).toContain('@alice')
  })

  it('renders name, role and email fields', () => {
    const wrapper = shallowMount(RegisterWizard, { props: baseProps })
    expect(wrapper.find('input[placeholder="Your name"]').exists()).toBe(true)
    expect(wrapper.find('select').exists()).toBe(true)
    expect(wrapper.find('input[type="email"]').exists()).toBe(true)
  })

  it('shows error if name is empty on submit', async () => {
    const wrapper = shallowMount(RegisterWizard, { props: baseProps })
    await wrapper.find('.btn-register').trigger('click')
    expect(wrapper.find('.error-msg').text()).toContain('Name is required')
  })

  it('calls PUT /team on valid submission', async () => {
    vi.mocked(fetch).mockResolvedValueOnce({ ok: true, json: async () => ({ status: 'added' }) } as Response)
    const wrapper = shallowMount(RegisterWizard, { props: baseProps })
    await wrapper.find('input[placeholder="Your name"]').setValue('Alice Smith')
    await wrapper.find('.btn-register').trigger('click')
    await vi.waitFor(() => {
      expect(fetch).toHaveBeenCalledWith(
        'https://localhost:8922/team',
        expect.objectContaining({ method: 'PUT' }),
      )
    })
  })

  it('emits cancel when Back is clicked', async () => {
    const wrapper = shallowMount(RegisterWizard, { props: baseProps })
    await wrapper.find('.btn-cancel').trigger('click')
    expect(wrapper.emitted('cancel')).toBeTruthy()
  })
})
