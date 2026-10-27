import axios from 'axios'
import { http } from './http'

export interface QuoteOption {
  carrier_name: string
  price_mxn: string
  currency: string
  delivery_days_min: number | null
  delivery_days_max: number | null
}

export interface QuoteResult {
  id: number
  origin_postal_code: string
  destination_postal_code: string
  weight_kg: string
  distance_km: string | null
  zone: number | null
  status: string
  message: string
  options: QuoteOption[]
  quoted_at: string
}

export interface ImportRow {
  line: number
  status: string
  reasons: string[]
  original: Record<string, unknown>
  normalized: Record<string, unknown>
}

export interface ImportReport {
  id: number
  file_name: string
  status: string
  checksum: string
  created_at: string
  summary: { total?: number; accepted?: number; normalized?: number; rejected?: number; error?: string }
  rows?: ImportRow[]
}

export const money = (value: string) =>
  new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(Number(value))

export function delivery(option: QuoteOption) {
  if (option.delivery_days_min == null) return 'Plazo por confirmar'
  return option.delivery_days_min === option.delivery_days_max
    ? String(option.delivery_days_min) + ' días'
    : String(option.delivery_days_min) + '–' + String(option.delivery_days_max) + ' días'
}

export async function getJson<T>(path: string, authorization: string): Promise<T> {
  try {
    const response = await http.get<T>('/admin/' + path, {
      headers: { Authorization: authorization },
    })
    return response.data
  } catch (error) {
    throw new Error(axios.isAxiosError(error) && error.response?.status === 401
      ? 'Usuario o contraseña incorrectos.' : 'No pudimos cargar los datos. Intenta de nuevo.')
  }
}
