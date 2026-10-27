import { afterEach, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import QuoteForm from '../components/QuoteForm.vue'
import { http } from '../http'

afterEach(() => vi.restoreAllMocks())

async function fill(wrapper: ReturnType<typeof mount>) {
  await wrapper.get('#origin').setValue('06600')
  await wrapper.get('#destination').setValue('64000')
  await wrapper.get('#weight').setValue('2.5')
  await wrapper.get('#email').setValue('cliente@example.test')
}

it('validates the form before contacting the API', async () => {
  const post = vi.spyOn(http, 'post')
  const wrapper = mount(QuoteForm)
  await wrapper.get('form').trigger('submit')
  expect(post).not.toHaveBeenCalled()
  expect(wrapper.get('#origin-error').text()).not.toBe('')
  expect(wrapper.get('#email-error').text()).not.toBe('')
  wrapper.unmount()
})

it('sends the contact and displays the returned rate and delivery estimate', async () => {
  const post = vi.spyOn(http, 'post').mockResolvedValue({ data: { quote: {
    id: 1, status: 'quoted', distance_km: '100', zone: 1, message: 'Opciones disponibles',
    options: [{ carrier_name: 'Estafeta', price_mxn: '198.55', delivery_days_min: 3, delivery_days_max: 3 }],
  } } })
  const wrapper = mount(QuoteForm)
  await fill(wrapper)
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  expect(post).toHaveBeenCalledWith('/quotes',
    expect.objectContaining({ email: 'cliente@example.test', weight_kg: 2.5 }),
    expect.objectContaining({ validateStatus: expect.any(Function) }))
  expect(wrapper.text()).toContain('Estafeta')
  expect(wrapper.text()).toContain('198.55')
  expect(wrapper.text()).toContain('3 días')
  wrapper.unmount()
})

it('shows a service failure without inventing options and allows another attempt', async () => {
  vi.spyOn(http, 'post').mockResolvedValue({ status: 503, data: { quote: {
    id: 2, status: 'external_service_unavailable', options: [], message: 'Servicio no disponible',
  } } })
  const wrapper = mount(QuoteForm)
  await fill(wrapper)
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  expect(wrapper.text()).toContain('Servicio no disponible')
  expect(wrapper.findAll('article')).toHaveLength(0)
  expect(wrapper.get('button').attributes('disabled')).toBeUndefined()
  wrapper.unmount()
})

it('handles a rejected connection and enables the form again', async () => {
  vi.spyOn(http, 'post').mockRejectedValue(new Error('private network details'))
  const wrapper = mount(QuoteForm)
  await fill(wrapper)
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  expect(wrapper.get('[role="alert"]').text()).toContain('No pudimos completar la conexión')
  expect(wrapper.text()).not.toContain('private network details')
  expect(wrapper.get('button').attributes('disabled')).toBeUndefined()
  wrapper.unmount()
})

it('trims postal spaces and sends all dimensions as entered', async () => {
  const post = vi.spyOn(http, 'post').mockResolvedValue({ data: { quote: {
    id: 3, status: 'quoted', options: [], message: 'Solicitud registrada',
  } } })
  const wrapper = mount(QuoteForm)
  await fill(wrapper)
  await wrapper.get('#origin').setValue('06600 ')
  await wrapper.get('#length_cm').setValue('40')
  await wrapper.get('#width_cm').setValue('30')
  await wrapper.get('#height_cm').setValue('20')
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  expect(post).toHaveBeenCalledWith('/quotes', expect.objectContaining({
    origin_postal_code: '06600', length_cm: 40, width_cm: 30, height_cm: 20,
  }), expect.any(Object))
  wrapper.unmount()
})

it('rejects a city name and incomplete dimensions without sending a request', async () => {
  const post = vi.spyOn(http, 'post')
  const wrapper = mount(QuoteForm)
  await fill(wrapper)
  await wrapper.get('#origin').setValue('Monterrey')
  await wrapper.get('#length_cm').setValue('40')
  await wrapper.get('form').trigger('submit')
  expect(post).not.toHaveBeenCalled()
  expect(wrapper.get('#origin-error').text()).toContain('no el nombre de la ciudad')
  expect(wrapper.get('#width_cm-error').text()).not.toBe('')
  wrapper.unmount()
})

it('shows missing-dimension warnings alongside the remaining real-weight options', async () => {
  vi.spyOn(http, 'post').mockResolvedValue({ data: { quote: {
    id: 4, status: 'quoted', message: 'Opciones disponibles',
    valid_until: '2026-12-31T00:00:00-06:00',
    warnings: ['Agrega largo, ancho y alto para cotizar con DHL.'],
    options: [{ carrier_name: 'Estafeta', price_mxn: '198.55', billable_weight_kg: '2.5',
      delivery_days_min: 3, delivery_days_max: 3 }],
  } } })
  const wrapper = mount(QuoteForm)
  await fill(wrapper)
  await wrapper.get('form').trigger('submit')
  await flushPromises()
  expect(wrapper.text()).toContain('Agrega largo, ancho y alto para cotizar con DHL.')
  expect(wrapper.text()).toContain('Peso para esta tarifa: 2.5 kg')
  expect(wrapper.text()).toContain('Precio respetado hasta')
  expect(wrapper.findAll('article')).toHaveLength(1)
  wrapper.unmount()
})
