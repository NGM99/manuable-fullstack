<template>
  <h1 class="mb-6 text-3xl font-bold text-slate-900">Comercial</h1>
  <p v-if="error" role="alert" class="mb-5 rounded-lg bg-red-50 p-4 text-red-800">{{ error }}</p>
  <form v-if="!authorization" class="panel mx-auto max-w-md space-y-5" @submit.prevent="login">
    <h2 class="text-xl font-semibold">Acceso interno</h2>
    <div><label for="admin-user" class="label">Usuario</label><input id="admin-user" v-model="username" class="field" autocomplete="username" required /></div>
    <div><label for="admin-password" class="label">Contraseña</label><input id="admin-password" v-model="password" class="field" type="password" autocomplete="current-password" required /></div>
    <button class="primary w-full" :disabled="busy">{{ busy ? 'Validando…' : 'Entrar' }}</button>
  </form>
  <template v-else>
    <div class="mb-6 flex gap-3">
      <button class="secondary" :disabled="busy" @click="load">Actualizar</button>
      <button class="secondary" @click="logout">Salir</button>
    </div>
    <p v-if="busy" role="status" class="mb-4">Cargando información…</p>
    <section class="space-y-5">
      <h2 class="text-xl font-semibold">Contactos y cotizaciones</h2>
      <p v-if="!leads.length && !busy" class="panel text-slate-600">Todavía no hay contactos en esta página.</p>
      <article v-for="lead in leads" :key="lead.email" class="panel overflow-x-auto">
        <h3 class="mb-4 font-semibold text-blue-800">{{ lead.email }}</h3>
        <table class="w-full min-w-[650px] text-left text-sm">
          <thead class="border-b text-slate-500"><tr><th class="pb-3">Fecha / ID</th><th>Ruta</th><th>Peso</th><th>Resultado</th><th>Opciones mostradas</th></tr></thead>
          <tbody>
            <tr v-for="quote in lead.quotes" :key="quote.id" class="border-b border-slate-100 align-top last:border-0">
              <td class="py-4 pr-3">{{ date(quote.quoted_at) }}<br /><span class="text-slate-400">#{{ quote.id }}</span></td>
              <td class="py-4 pr-3">{{ quote.origin_postal_code }} → {{ quote.destination_postal_code }}</td>
              <td class="py-4 pr-3">{{ quote.weight_kg }} kg</td>
              <td class="py-4 pr-3">{{ statusNames[quote.status] || quote.status }}</td>
              <td class="py-4"><div v-for="(option, index) in quote.options" :key="index" class="mb-2">
                {{ option.carrier_name }} · {{ money(option.price_mxn) }} · {{ delivery(option) }}
              </div><span v-if="!quote.options.length" class="text-slate-500">{{ quote.message }}</span></td>
            </tr>
          </tbody>
        </table>
      </article>
      <div class="flex items-center gap-4">
        <button class="secondary" :disabled="page === 1 || busy" @click="changePage(-1)">Anterior</button>
        <span class="text-sm">Página {{ page }}</span>
        <button class="secondary" :disabled="leads.length < 50 || busy" @click="changePage(1)">Siguiente</button>
      </div>
    </section>

    <section class="mt-10">
      <h2 class="mb-4 text-xl font-semibold">Calidad de los archivos importados</h2>
      <div class="grid gap-4 sm:grid-cols-2">
        <article v-for="report in imports" :key="report.id" class="panel">
          <h3 class="font-semibold">{{ report.file_name }}</h3>
          <p class="mt-1 text-xs text-slate-500">Importación #{{ report.id }} · {{ date(report.created_at) }}</p>
          <p v-if="report.summary.error" class="error">{{ report.summary.error }}</p>
          <p v-else class="my-4 text-sm leading-7">
            Total: {{ report.summary.total }} · Aceptadas: {{ report.summary.accepted }}<br />
            Normalizadas: {{ report.summary.normalized }} · Rechazadas: {{ report.summary.rejected }}
          </p>
          <button class="secondary mt-2" @click="openReport(report.id)">Ver filas y motivos</button>
        </article>
      </div>
      <article v-if="selected" class="panel mt-5">
        <div class="mb-4 flex items-center justify-between gap-4">
          <h3 class="font-semibold">{{ selected.file_name }} · Importación #{{ selected.id }}</h3>
          <button class="secondary" @click="selected = null">Cerrar</button>
        </div>
        <p class="mb-4 break-all text-xs text-slate-500">SHA-256: {{ selected.checksum }}</p>
        <details v-for="row in selected.rows" :key="row.line" class="border-t border-slate-200 py-3">
          <summary class="cursor-pointer text-sm font-medium">Fila {{ row.line }} · {{ row.status }}</summary>
          <ul class="my-3 list-inside list-disc text-sm text-slate-600"><li v-for="reason in row.reasons" :key="reason">{{ reason }}</li></ul>
          <div class="grid gap-3 md:grid-cols-2">
            <div><p class="label">Original</p><pre class="overflow-auto rounded-lg bg-slate-50 p-3 text-xs">{{ JSON.stringify(row.original, null, 2) }}</pre></div>
            <div><p class="label">Normalizado</p><pre class="overflow-auto rounded-lg bg-slate-50 p-3 text-xs">{{ JSON.stringify(row.normalized, null, 2) }}</pre></div>
          </div>
        </details>
      </article>
    </section>
  </template>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { delivery, getJson, money, type ImportReport, type QuoteResult } from '../api'

const username = ref('')
const password = ref('')
const authorization = ref('')
const error = ref('')
const busy = ref(false)
const page = ref(1)
const leads = ref<Array<{ email: string; quotes: QuoteResult[] }>>([])
const imports = ref<ImportReport[]>([])
const selected = ref<ImportReport | null>(null)
const statusNames: Record<string, string> = {
  pending: 'En proceso', quoted: 'Cotizada', no_rates: 'Sin tarifas',
  weight_out_of_range: 'Sin rango de peso', postal_code_not_found: 'CP no localizado',
  external_service_unavailable: 'Servicio postal no disponible', failed: 'Error',
}
const date = (value: string) => new Date(value).toLocaleString('es-MX', { timeZone: 'America/Monterrey' })

async function load() {
  busy.value = true
  error.value = ''
  try {
    const [contacts, reports] = await Promise.all([
      getJson<{ leads: typeof leads.value }>('leads?page=' + page.value, authorization.value),
      getJson<{ imports: ImportReport[] }>('imports', authorization.value),
    ])
    leads.value = contacts.leads
    imports.value = reports.imports
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : 'No pudimos cargar los datos.'
    authorization.value = ''
  } finally {
    busy.value = false
  }
}

async function login() {
  authorization.value = 'Basic ' + btoa(String.fromCharCode(...new TextEncoder().encode(username.value + ':' + password.value)))
  password.value = ''
  await load()
}

async function openReport(id: number) {
  error.value = ''
  try {
    selected.value = (await getJson<{ import: ImportReport }>('imports/' + id, authorization.value)).import
  } catch (caught) {
    error.value = caught instanceof Error ? caught.message : 'No pudimos abrir el reporte.'
  }
}

function logout() {
  authorization.value = ''
  leads.value = []
  imports.value = []
  selected.value = null
}

async function changePage(change: number) {
  page.value = Math.max(1, page.value + change)
  await load()
}
</script>
