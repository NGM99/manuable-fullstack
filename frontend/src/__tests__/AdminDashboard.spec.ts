import { afterEach, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import AdminDashboard from '../components/AdminDashboard.vue'
import { http } from '../http'

const dialogMethods = ['showModal', 'close'] as const
const originalDialogMethods = dialogMethods.map((name) =>
  Object.getOwnPropertyDescriptor(HTMLDialogElement.prototype, name))

afterEach(() => {
  vi.restoreAllMocks()
  vi.useRealTimers()
  dialogMethods.forEach((name, index) => {
    const descriptor = originalDialogMethods[index]
    if (descriptor) Object.defineProperty(HTMLDialogElement.prototype, name, descriptor)
    else Reflect.deleteProperty(HTMLDialogElement.prototype, name)
  })
})

it('separates contacts, daily figures and imports into accessible tabs without reloading data', async () => {
  const get = vi.spyOn(http, 'get')
    .mockResolvedValueOnce({ data: { leads: [{ email: 'manual@example.test', quotes: [{
      id: 1, source: 'manual', external_reference: 'COT-0001', quoted_at: '2026-11-20T12:00:00-06:00',
      valid_until: '2026-12-20T23:59:59-06:00', price_honored: true,
      origin_postal_code: '06600', destination_postal_code: '64000', weight_kg: '15',
      status: 'quoted', options: [{ carrier_name: 'DHL', price_mxn: '1514.24',
        delivery_days_min: null, delivery_days_max: null }],
    }] }] } })
    .mockResolvedValueOnce({ data: { imports: [{
      id: 1, file_name: 'tarifas.csv', created_at: '2026-11-20T12:00:00-06:00',
      summary: { total: 108, accepted: 0, normalized: 25, rejected: 83 },
    }] } })
    .mockResolvedValueOnce({ data: { days: [
      { date: '2026-11-20', source: 'web', total: 12, without_options: 3 },
    ] } })
  const wrapper = mount(AdminDashboard, { attachTo: document.body })
  expect(get).not.toHaveBeenCalled()
  expect(wrapper.find('[role="tablist"]').exists()).toBe(false)
  await wrapper.get('#admin-user').setValue('comercial')
  await wrapper.get('#admin-password').setValue('test-password')
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  expect(get).toHaveBeenCalledWith('/admin/stats', expect.objectContaining({
    headers: { Authorization: 'Basic ' + btoa('comercial:test-password') },
  }))
  expect(wrapper.text()).toContain('2026-11-20')
  expect(wrapper.text()).toContain('COT-0001')
  expect(wrapper.text()).toContain('Precio vigente hasta')
  expect(wrapper.text()).toContain('1,514.24')
  const contacts = wrapper.get('#commercial-panel-leads')
  const daily = wrapper.get('#commercial-panel-stats')
  const imports = wrapper.get('#commercial-panel-imports')
  expect(contacts.isVisible()).toBe(true)
  expect(daily.isVisible()).toBe(false)
  expect(imports.isVisible()).toBe(false)

  await wrapper.get('#commercial-tab-stats').trigger('click')
  expect(daily.isVisible()).toBe(true)
  expect(contacts.isVisible()).toBe(false)
  expect(wrapper.get('#commercial-tab-stats').attributes('aria-selected')).toBe('true')

  await wrapper.get('#commercial-tab-stats').trigger('keydown', { key: 'ArrowRight' })
  expect(imports.isVisible()).toBe(true)
  expect(daily.isVisible()).toBe(false)
  expect(imports.text()).toContain('tarifas.csv')
  expect(document.activeElement?.id).toBe('commercial-tab-imports')

  await wrapper.get('#commercial-tab-imports').trigger('keydown', { key: 'Home' })
  expect(contacts.isVisible()).toBe(true)
  expect(contacts.text()).toContain('COT-0001')
  expect(wrapper.get('#commercial-tab-leads').attributes('tabindex')).toBe('0')
  expect(get).toHaveBeenCalledTimes(3)
  wrapper.unmount()
})

it('opens import details in a modal, closes with Escape or outside click and displays request errors inside it', async () => {
  // jsdom does not implement the native dialog methods.
  Object.defineProperties(HTMLDialogElement.prototype, {
    showModal: { configurable: true, value(this: HTMLDialogElement) { this.setAttribute('open', '') } },
    close: { configurable: true, value(this: HTMLDialogElement) {
      this.removeAttribute('open')
      this.dispatchEvent(new Event('close'))
    } },
  })
  const report = {
    id: 1, file_name: 'tarifas.csv', created_at: '2026-11-20T12:00:00-06:00',
    checksum: 'test-checksum', summary: { total: 1, accepted: 0, normalized: 0, rejected: 1 },
    rows: [{ line: 2, status: 'RECHAZADO', reasons: ['Unidad de peso ausente'],
      original: { unidad: '' }, normalized: { weight_min_kg: '1.0' } }],
  }
  vi.spyOn(http, 'get')
    .mockResolvedValueOnce({ data: { leads: [] } })
    .mockResolvedValueOnce({ data: { imports: [report] } })
    .mockResolvedValueOnce({ data: { days: [] } })
    .mockResolvedValueOnce({ data: { import: report } })
    .mockResolvedValueOnce({ data: { import: report } })
    .mockRejectedValueOnce(new Error('private details'))
  const wrapper = mount(AdminDashboard, { attachTo: document.body })
  await wrapper.get('#admin-user').setValue('comercial')
  await wrapper.get('#admin-password').setValue('test-password')
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  await wrapper.get('#commercial-tab-imports').trigger('click')
  const button = wrapper.get('#commercial-panel-imports button')
  const dialog = wrapper.get('dialog')
  expect(button.classes()).toContain('cursor-pointer')
  expect(dialog.attributes('open')).toBeUndefined()

  await button.trigger('click')
  await flushPromises()
  expect(dialog.attributes('open')).toBeDefined()
  expect(dialog.attributes('aria-modal')).toBe('true')
  expect(dialog.text()).toContain('Unidad de peso ausente')
  expect(dialog.text()).toContain('Original')
  expect(dialog.text()).toContain('Normalizado')
  expect(wrapper.get('#commercial-panel-imports').text()).not.toContain('Unidad de peso ausente')
  expect(document.body.style.overflow).toBe('hidden')

  await dialog.trigger('cancel')
  expect(dialog.attributes('open')).toBeUndefined()
  expect(document.body.style.overflow).not.toBe('hidden')
  await button.trigger('click')
  await flushPromises()
  await dialog.trigger('click', { clientX: -10, clientY: -10 })
  expect(dialog.attributes('open')).toBeUndefined()

  await button.trigger('click')
  await flushPromises()
  expect(dialog.get('[role="alert"]').text()).toContain('No pudimos cargar los datos')
  expect(dialog.text()).not.toContain('private details')
  await dialog.get('button').trigger('click')
  expect(dialog.attributes('open')).toBeUndefined()
  expect(document.body.style.overflow).not.toBe('hidden')
  wrapper.unmount()
})

it('searches email on the backend, resets the page and keeps the filter while paging', async () => {
  const get = vi.spyOn(http, 'get')
    .mockResolvedValueOnce({ data: { leads: [], page: 1, has_next: true } })
    .mockResolvedValueOnce({ data: { imports: [] } })
    .mockResolvedValueOnce({ data: { days: [] } })
    .mockResolvedValueOnce({ data: { leads: [], page: 2, has_next: false } })
    .mockResolvedValueOnce({ data: { leads: [], page: 1, has_next: true } })
    .mockResolvedValueOnce({ data: { leads: [], page: 2, has_next: false } })
    .mockResolvedValueOnce({ data: { leads: [], page: 1, has_next: false } })
  const wrapper = mount(AdminDashboard)
  await wrapper.get('#admin-user').setValue('comercial')
  await wrapper.get('#admin-password').setValue('test-password')
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  expect(wrapper.get('[role="search"]').text()).toContain('Limpiar')
  expect(wrapper.findAll('nav[aria-label$="de contactos"]')).toHaveLength(2)
  const nextButton = () => wrapper.findAll('button').find((button) => button.text() === 'Siguiente')!
  await nextButton().trigger('click')
  await flushPromises()
  expect(get).toHaveBeenLastCalledWith('/admin/leads?page=2', expect.any(Object))
  expect(nextButton().attributes('disabled')).toBeDefined()
  expect(wrapper.get('nav[aria-label="Paginación inferior de contactos"]').text()).toContain('Página 2')

  await wrapper.get('#lead-email-search').setValue(' cliente+tag@example.test ')
  await wrapper.get('[role="search"]').trigger('submit')
  await flushPromises()
  expect(get).toHaveBeenLastCalledWith(
    '/admin/leads?page=1&q=cliente%2Btag%40example.test', expect.any(Object))
  expect(wrapper.get('#lead-email-search').element).toHaveProperty('value', 'cliente+tag@example.test')
  await nextButton().trigger('click')
  await flushPromises()
  expect(get).toHaveBeenLastCalledWith(
    '/admin/leads?page=2&q=cliente%2Btag%40example.test', expect.any(Object))

  await wrapper.findAll('button').find((button) => button.text() === 'Limpiar')!.trigger('click')
  await flushPromises()
  expect(get).toHaveBeenLastCalledWith('/admin/leads?page=1', expect.any(Object))
  expect(wrapper.get('#lead-email-search').element).toHaveProperty('value', '')
  expect(get).toHaveBeenCalledTimes(7)
  wrapper.unmount()
})

it('debounces typing, keeps the current results while searching and ignores outdated responses', async () => {
  let finishOldRequest!: () => void
  const get = vi.spyOn(http, 'get')
    .mockResolvedValueOnce({ data: { leads: [{ email: 'original@example.test', quotes: [] }], page: 1, has_next: false } })
    .mockResolvedValueOnce({ data: { imports: [] } })
    .mockResolvedValueOnce({ data: { days: [] } })
    .mockImplementationOnce(() => new Promise((resolve) => {
      finishOldRequest = () => resolve({ data: {
        leads: [{ email: 'outdated@example.test', quotes: [] }], page: 1, has_next: false,
      } } as Awaited<ReturnType<typeof http.get>>)
    }))
    .mockResolvedValueOnce({ data: { leads: [{ email: 'new@example.test', quotes: [] }], page: 1, has_next: false } })
  const wrapper = mount(AdminDashboard)
  await wrapper.get('#admin-user').setValue('comercial')
  await wrapper.get('#admin-password').setValue('test-password')
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  vi.useFakeTimers()
  const input = wrapper.get('#lead-email-search')
  await input.setValue('o')
  await vi.advanceTimersByTimeAsync(200)
  await input.setValue('old')
  await vi.advanceTimersByTimeAsync(399)
  expect(get).toHaveBeenCalledTimes(3)
  await vi.advanceTimersByTimeAsync(1)
  expect(get).toHaveBeenLastCalledWith('/admin/leads?page=1&q=old', expect.any(Object))
  expect(input.attributes('disabled')).toBeUndefined()
  expect(wrapper.text()).toContain('original@example.test')
  expect(wrapper.get('#commercial-panel-leads').attributes('aria-busy')).toBe('true')

  await input.setValue('new')
  finishOldRequest()
  await flushPromises()
  expect(wrapper.text()).toContain('original@example.test')
  expect(wrapper.text()).not.toContain('outdated@example.test')
  await vi.advanceTimersByTimeAsync(400)
  await flushPromises()
  expect(get).toHaveBeenLastCalledWith('/admin/leads?page=1&q=new', expect.any(Object))
  expect(get).toHaveBeenCalledTimes(5)
  expect(wrapper.text()).toContain('new@example.test')
  expect(wrapper.text()).not.toContain('original@example.test')
  expect(wrapper.get('#commercial-panel-leads').attributes('aria-busy')).toBe('false')

  await input.setValue('pending')
  wrapper.unmount()
  await vi.advanceTimersByTimeAsync(400)
  expect(get).toHaveBeenCalledTimes(5)
})
