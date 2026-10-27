import { afterEach, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import AdminDashboard from '../components/AdminDashboard.vue'
import { http } from '../http'

afterEach(() => vi.restoreAllMocks())

it('shows protected daily figures and the imported quote with its price validity', async () => {
  const get = vi.spyOn(http, 'get')
    .mockResolvedValueOnce({ data: { leads: [{ email: 'manual@example.test', quotes: [{
      id: 1, source: 'manual', external_reference: 'COT-0001', quoted_at: '2026-11-20T12:00:00-06:00',
      valid_until: '2026-12-20T23:59:59-06:00', price_honored: true,
      origin_postal_code: '06600', destination_postal_code: '64000', weight_kg: '15',
      status: 'quoted', options: [{ carrier_name: 'DHL', price_mxn: '1514.24',
        delivery_days_min: null, delivery_days_max: null }],
    }] }] } })
    .mockResolvedValueOnce({ data: { imports: [] } })
    .mockResolvedValueOnce({ data: { days: [
      { date: '2026-11-20', source: 'web', total: 12, without_options: 3 },
    ] } })
  const wrapper = mount(AdminDashboard)
  expect(get).not.toHaveBeenCalled()
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
  wrapper.unmount()
})
