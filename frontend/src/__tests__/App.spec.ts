import { afterEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import App from '../App.vue'

const response = (ok: boolean) => ({ ok, json: async () => ({ status: 'ok' }) })

afterEach(() => {
  vi.unstubAllGlobals()
  vi.useRealTimers()
})

describe('Application connection', () => {
  it('shows loading while the backend request is pending and then availability', async () => {
    let completeRequest!: (value: ReturnType<typeof response>) => void
    const pendingResponse = new Promise<ReturnType<typeof response>>((resolve) => {
      completeRequest = resolve
    })
    const fetchMock = vi.fn().mockReturnValue(pendingResponse)
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(App)
    await nextTick()

    expect(wrapper.get('[role="status"]').text()).toContain('Comprobando conexión')
    expect(wrapper.get('button').attributes('disabled')).toBeDefined()

    completeRequest(response(true))
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/v1/health', expect.any(Object))
    expect(wrapper.get('[role="status"]').text()).toBe('Servicio disponible.')
    wrapper.unmount()
  })

  it('shows an actionable message for an unavailable backend and allows retry', async () => {
    vi.stubGlobal('fetch', vi.fn()
      .mockResolvedValueOnce(response(false))
      .mockResolvedValueOnce(response(true)))
    const wrapper = mount(App)
    await flushPromises()

    expect(wrapper.get('[role="status"]').text()).toContain('No pudimos conectar')
    await wrapper.get('button').trigger('click')
    await flushPromises()

    expect(wrapper.get('[role="status"]').text()).toBe('Servicio disponible.')
    wrapper.unmount()
  })

  it('handles network failures without displaying technical details', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('internal host details')))
    const wrapper = mount(App)
    await flushPromises()

    expect(wrapper.text()).toContain('No pudimos conectar')
    expect(wrapper.text()).not.toContain('internal host details')
    wrapper.unmount()
  })

  it('ends loading and allows retry after a five-second timeout', async () => {
    vi.useFakeTimers()
    vi.stubGlobal('fetch', vi.fn((_url: string, options: RequestInit) => {
      return new Promise((_resolve, reject) => {
        options.signal?.addEventListener('abort', () => reject(new Error('Request aborted')))
      })
    }))
    const wrapper = mount(App)

    await vi.advanceTimersByTimeAsync(5000)
    await nextTick()

    expect(wrapper.get('[role="status"]').text()).toContain('No pudimos conectar')
    expect(wrapper.get('button').attributes('disabled')).toBeUndefined()
    wrapper.unmount()
  })
})
