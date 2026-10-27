import { afterEach, expect, it, vi } from 'vitest'
import { getJson } from '../api'
import { http } from '../http'

afterEach(() => vi.restoreAllMocks())

it('loads internal data with the authorization header for that request', async () => {
  const get = vi.spyOn(http, 'get').mockResolvedValue({ data: { leads: [] } })
  await expect(getJson('leads?page=1', 'Basic test')).resolves.toEqual({ leads: [] })
  expect(get).toHaveBeenCalledWith('/admin/leads?page=1', {
    headers: { Authorization: 'Basic test' },
  })
  expect(http.defaults.headers.common.Authorization).toBeUndefined()
})

it('shows a login message when Rails rejects the credentials', async () => {
  vi.spyOn(http, 'get').mockRejectedValue({ isAxiosError: true, response: { status: 401 } })
  await expect(getJson('leads', 'Basic incorrect'))
    .rejects.toThrow('Usuario o contraseña incorrectos.')
})

it('shows an actionable message for an unavailable internal API', async () => {
  vi.spyOn(http, 'get').mockRejectedValue(new Error('private network details'))
  await expect(getJson('imports', 'Basic test'))
    .rejects.toThrow('No pudimos cargar los datos. Intenta de nuevo.')
})
