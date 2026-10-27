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
      <button class="secondary" :disabled="busy || contactsLoading" @click="load()">Actualizar</button>
      <button class="secondary" @click="logout">Salir</button>
    </div>
    <div role="tablist" aria-label="Secciones de Comercial" class="mb-6 flex gap-1 overflow-x-auto border-b border-slate-200">
      <button v-for="(tab, index) in tabs" :id="'commercial-tab-' + tab.id" :key="tab.id"
        role="tab" type="button" :aria-selected="activeTab === tab.id"
        :aria-controls="'commercial-panel-' + tab.id" :tabindex="activeTab === tab.id ? 0 : -1"
        class="shrink-0 whitespace-nowrap border-b-2 px-4 py-3 text-sm font-semibold outline-none transition-colors duration-200 motion-reduce:transition-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-blue-600"
        :class="activeTab === tab.id ? 'border-blue-700 bg-blue-50 text-blue-800' : 'border-transparent text-slate-500 hover:bg-slate-100 hover:text-slate-900'"
        @click="activeTab = tab.id" @keydown="changeTab($event, index)">
        {{ tab.label }}
      </button>
    </div>
    <p role="status" class="sr-only">{{ busy ? 'Cargando información…' : '' }}</p>
    <section v-show="activeTab === 'stats'" id="commercial-panel-stats" role="tabpanel"
      aria-labelledby="commercial-tab-stats" tabindex="0" class="commercial-panel panel overflow-x-auto">
      <h2 class="mb-3 text-xl font-semibold">Cotizaciones por día</h2>
      <p class="mb-4 text-xs text-slate-500">Fechas en horario de Monterrey. Web y capturas manuales separadas. Sin opciones cuenta solicitudes terminadas, incluidos errores.</p>
      <p v-if="!stats.length && !busy" class="text-sm text-slate-600">Sin actividad registrada.</p>
      <table v-else class="w-full text-left text-sm">
        <thead><tr><th>Fecha</th><th>Origen</th><th>Total</th><th>Sin opciones</th></tr></thead>
        <tbody><tr v-for="row in stats" :key="row.date + row.source" class="border-t border-slate-100">
          <td class="py-2">{{ row.date }}</td><td>{{ row.source === 'manual' ? 'Manual' : 'Web' }}</td>
          <td>{{ row.total }}</td><td>{{ row.without_options }}</td>
        </tr></tbody>
      </table>
    </section>
    <section v-show="activeTab === 'leads'" id="commercial-panel-leads" role="tabpanel"
      aria-labelledby="commercial-tab-leads" :aria-busy="busy || contactsLoading" tabindex="0" class="commercial-panel space-y-5">
      <h2 class="text-xl font-semibold">Contactos y cotizaciones</h2>
      <form class="contact-search panel flex flex-wrap items-end gap-3" role="search" @submit.prevent="searchContacts">
        <div class="min-w-0 flex-1 basis-60">
          <label for="lead-email-search" class="label">Buscar por correo</label>
          <div class="relative">
            <input id="lead-email-search" v-model="emailSearch" class="field pr-10" type="search" maxlength="254"
              placeholder="Correo completo o parte del correo" :disabled="busy" @input="scheduleSearch" />
            <span v-show="contactsLoading" aria-hidden="true" class="pointer-events-none absolute inset-y-0 right-3 flex items-center text-blue-700">
              <svg class="h-4 w-4 animate-spin motion-reduce:animate-none" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="3" opacity="0.2" />
                <path d="M12 3a9 9 0 0 1 9 9" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
              </svg>
            </span>
          </div>
        </div>
        <button class="primary" type="submit" :disabled="busy">Buscar</button>
        <button class="secondary" type="button" :disabled="busy" @click="clearSearch">Limpiar</button>
      </form>
      <p role="status" aria-live="polite" class="h-5 truncate text-sm text-slate-500">
        <span v-if="contactsError" role="alert" class="text-red-700" :title="contactsError">{{ contactsError }}</span>
        <span v-else-if="contactsLoading">Buscando contactos…</span>
        <span v-else-if="appliedSearch">Resultados para “{{ appliedSearch }}”.</span>
        <span v-else aria-hidden="true">&nbsp;</span>
      </p>
      <nav aria-label="Paginación superior de contactos" class="flex flex-wrap items-center gap-4">
        <button class="secondary" :disabled="page === 1 || busy || contactsLoading" @click="changePage(-1)">Anterior</button>
        <span class="text-sm">Página {{ page }} · 10 contactos por página</span>
        <button class="secondary" :disabled="!hasNext || busy || contactsLoading" @click="changePage(1)">Siguiente</button>
      </nav>
      <p v-if="!leads.length && !busy" class="panel text-slate-600">
        {{ appliedSearch ? 'No se encontraron contactos para ese correo.' : 'Todavía no hay contactos en esta página.' }}
      </p>
      <article v-for="lead in leads" :key="lead.email" class="panel overflow-x-auto">
        <h3 class="mb-4 font-semibold text-blue-800">{{ lead.email }}</h3>
        <table class="w-full min-w-[650px] text-left text-sm">
          <thead class="border-b text-slate-500"><tr><th class="pb-3">Fecha / ID</th><th>Ruta</th><th>Peso</th><th>Resultado</th><th>Opciones mostradas</th></tr></thead>
          <tbody>
            <tr v-for="quote in lead.quotes" :key="quote.id" class="border-b border-slate-100 align-top last:border-0">
              <td class="py-4 pr-3">{{ date(quote.quoted_at) }}<br /><span class="text-slate-400">#{{ quote.id }} · {{ quote.source === 'manual' ? 'Manual' : 'Web' }} {{ quote.external_reference }}</span>
                <p v-if="quote.valid_until && quote.options.length" class="mt-2 text-xs">
                  {{ quote.price_status === 'not_started' ? 'Fecha futura; vigencia hasta ' : quote.price_honored ? 'Precio vigente hasta ' : 'Precio vencido desde ' }}{{ date(quote.valid_until) }}
                </p>
              </td>
              <td class="py-4 pr-3">{{ quote.origin_postal_code }} → {{ quote.destination_postal_code }}</td>
              <td class="py-4 pr-3">{{ quote.weight_kg }} kg
                <p v-if="quote.length_cm" class="mt-1 text-xs">{{ quote.length_cm }} × {{ quote.width_cm }} × {{ quote.height_cm }} cm</p>
              </td>
              <td class="py-4 pr-3">{{ statusNames[quote.status] || quote.status }}</td>
              <td class="py-4"><div v-for="(option, index) in quote.options" :key="index" class="mb-2">
                {{ option.carrier_name }} · {{ money(option.price_mxn) }} · {{ delivery(option) }}
                <p v-if="option.billable_weight_kg" class="text-xs text-slate-500">Peso aplicado: {{ option.billable_weight_kg }} kg</p>
              </div><span v-if="!quote.options.length" class="text-slate-500">{{ quote.message }}</span></td>
            </tr>
          </tbody>
        </table>
      </article>
      <nav aria-label="Paginación inferior de contactos" class="flex flex-wrap items-center gap-4">
        <button class="secondary" :disabled="page === 1 || busy || contactsLoading" @click="changePage(-1)">Anterior</button>
        <span class="text-sm">Página {{ page }} · 10 contactos por página</span>
        <button class="secondary" :disabled="!hasNext || busy || contactsLoading" @click="changePage(1)">Siguiente</button>
      </nav>
    </section>

    <section v-show="activeTab === 'imports'" id="commercial-panel-imports" role="tabpanel"
      aria-labelledby="commercial-tab-imports" tabindex="0" class="commercial-panel">
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
          <button class="secondary mt-2 cursor-pointer" type="button" @click="openReport(report.id)">Ver filas y motivos</button>
        </article>
      </div>
    </section>

    <dialog ref="reportDialog" aria-labelledby="import-dialog-title" aria-modal="true" :aria-busy="reportLoading"
      class="import-dialog m-auto max-h-[85dvh] w-11/12 max-w-5xl overflow-hidden rounded-2xl border-0 bg-white p-0 text-slate-900 shadow-2xl"
      @cancel.prevent="closeReport" @close="resetReport" @click="closeOutsideReport">
      <header class="flex shrink-0 items-start justify-between gap-4 border-b border-slate-200 bg-white p-5 sm:p-6">
        <div>
          <h2 id="import-dialog-title" class="text-xl font-semibold">Filas y motivos de importación</h2>
          <p v-if="selected" class="mt-1 break-all text-sm text-slate-500">{{ selected.file_name }} · Importación #{{ selected.id }}</p>
        </div>
        <button class="secondary shrink-0 cursor-pointer" type="button" autofocus @click="closeReport">Cerrar</button>
      </header>
      <div class="import-dialog-body m-2 min-h-0 overflow-y-auto rounded-xl p-3 sm:p-4">
        <p v-if="reportLoading" role="status" class="text-sm text-slate-600">Cargando filas y motivos…</p>
        <p v-else-if="reportError" role="alert" class="error">{{ reportError }}</p>
        <template v-else-if="selected">
          <p class="mb-4 break-all text-xs text-slate-500">SHA-256: {{ selected.checksum }}</p>
          <p v-if="!selected.rows?.length" class="text-sm text-slate-600">Esta importación no contiene filas para mostrar.</p>
          <details v-for="row in selected.rows" :key="row.line" class="border-t border-slate-200 py-3">
          <summary class="cursor-pointer text-sm font-medium">Fila {{ row.line }} · {{ row.status }}</summary>
          <ul class="my-3 list-inside list-disc text-sm text-slate-600"><li v-for="reason in row.reasons" :key="reason">{{ reason }}</li></ul>
          <div class="grid gap-3 md:grid-cols-2">
            <div><p class="label">Original</p><pre class="overflow-auto rounded-lg bg-slate-50 p-3 text-xs">{{ JSON.stringify(row.original, null, 2) }}</pre></div>
            <div><p class="label">Normalizado</p><pre class="overflow-auto rounded-lg bg-slate-50 p-3 text-xs">{{ JSON.stringify(row.normalized, null, 2) }}</pre></div>
          </div>
          </details>
        </template>
      </div>
    </dialog>
  </template>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'
import { delivery, getJson, money, type DailyStat, type ImportReport, type QuoteResult } from '../api'

const username = ref('')
const password = ref('')
const authorization = ref('')
const error = ref('')
const busy = ref(false)
const page = ref(1)
const hasNext = ref(false)
const emailSearch = ref('')
const appliedSearch = ref('')
const contactsBusy = ref(false)
const searchPending = ref(false)
const contactsLoading = computed(() => contactsBusy.value || searchPending.value)
const contactsError = ref('')
let searchTimer: ReturnType<typeof setTimeout> | undefined
let loadRequest = 0
const leads = ref<Array<{ email: string; quotes: QuoteResult[] }>>([])
const imports = ref<ImportReport[]>([])
const selected = ref<ImportReport | null>(null)
const reportDialog = ref<HTMLDialogElement | null>(null)
const reportLoading = ref(false)
const reportError = ref('')
let reportRequest = 0
let previousOverflow: string | null = null
const stats = ref<DailyStat[]>([])
const tabs = [
  { id: 'leads', label: 'Contactos y cotizaciones' },
  { id: 'stats', label: 'Indicadores diarios' },
  { id: 'imports', label: 'Importaciones' },
] as const
const activeTab = ref<(typeof tabs)[number]['id']>('leads')

async function changeTab(event: KeyboardEvent, index: number) {
  let next: number
  switch (event.key) {
    case 'ArrowRight': next = (index + 1) % tabs.length; break
    case 'ArrowLeft': next = (index + tabs.length - 1) % tabs.length; break
    case 'Home': next = 0; break
    case 'End': next = tabs.length - 1; break
    default: return
  }
  event.preventDefault()
  activeTab.value = tabs[next]!.id
  await nextTick()
  document.getElementById('commercial-tab-' + activeTab.value)?.focus()
}
const statusNames: Record<string, string> = {
  pending: 'En proceso', quoted: 'Cotizada', no_rates: 'Sin tarifas',
  weight_out_of_range: 'Sin rango de peso', postal_code_not_found: 'CP no localizado',
  external_service_unavailable: 'Servicio postal no disponible', failed: 'Error',
  dimensions_required: 'Faltan dimensiones',
}
const date = (value: string) => new Date(value).toLocaleString('es-MX', { timeZone: 'America/Monterrey' })

async function load(contactsOnly = false) {
  const request = ++loadRequest
  if (contactsOnly) contactsBusy.value = true
  else busy.value = true
  contactsError.value = ''
  error.value = ''
  try {
    const query = new URLSearchParams({ page: String(page.value) })
    if (appliedSearch.value) query.set('q', appliedSearch.value)
    const contactsRequest = getJson<{ leads: typeof leads.value; page: number; has_next: boolean }>(
      'leads?' + query.toString(), authorization.value)
    const [contacts, reports, daily] = await Promise.all([
      contactsRequest,
      contactsOnly ? null : getJson<{ imports: ImportReport[] }>('imports', authorization.value),
      contactsOnly ? null : getJson<{ days: DailyStat[] }>('stats', authorization.value),
    ])
    if (request !== loadRequest) return
    leads.value = contacts.leads
    page.value = contacts.page || page.value
    hasNext.value = contacts.has_next === true
    if (reports) imports.value = reports.imports
    if (daily) stats.value = daily.days
  } catch (caught) {
    if (request !== loadRequest) return
    const message = caught instanceof Error ? caught.message : 'No pudimos cargar los datos.'
    if (contactsOnly) contactsError.value = message
    else {
      closeReport()
      resetReport()
      error.value = message
      authorization.value = ''
    }
  } finally {
    if (request === loadRequest) {
      contactsBusy.value = false
      busy.value = false
    }
  }
}

async function login() {
  authorization.value = 'Basic ' + btoa(String.fromCharCode(...new TextEncoder().encode(username.value + ':' + password.value)))
  password.value = ''
  await load()
}

async function openReport(id: number) {
  const request = ++reportRequest
  selected.value = null
  reportError.value = ''
  reportLoading.value = true
  if (!reportDialog.value?.open) {
    reportDialog.value?.showModal()
    previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
  }
  try {
    const result = await getJson<{ import: ImportReport }>('imports/' + id, authorization.value)
    if (request === reportRequest) selected.value = result.import
  } catch (caught) {
    if (request === reportRequest)
      reportError.value = caught instanceof Error ? caught.message : 'No pudimos abrir el reporte.'
  } finally {
    if (request === reportRequest) reportLoading.value = false
  }
}

function closeReport() {
  if (reportDialog.value?.open) reportDialog.value.close()
}

function resetReport() {
  reportRequest++
  selected.value = null
  reportError.value = ''
  reportLoading.value = false
  if (previousOverflow !== null) {
    document.body.style.overflow = previousOverflow
    previousOverflow = null
  }
}

function closeOutsideReport(event: MouseEvent) {
  const dialog = reportDialog.value
  if (!dialog || event.target !== dialog) return
  const bounds = dialog.getBoundingClientRect()
  if (event.clientX < bounds.left || event.clientX > bounds.right ||
      event.clientY < bounds.top || event.clientY > bounds.bottom) closeReport()
}

onBeforeUnmount(() => {
  cancelSearchTimer()
  loadRequest++
  resetReport()
})

function logout() {
  cancelSearchTimer()
  loadRequest++
  contactsBusy.value = false
  busy.value = false
  contactsError.value = ''
  closeReport()
  resetReport()
  authorization.value = ''
  leads.value = []
  imports.value = []
  selected.value = null
  stats.value = []
  activeTab.value = 'leads'
  page.value = 1
  hasNext.value = false
  emailSearch.value = ''
  appliedSearch.value = ''
}

async function changePage(change: number) {
  if (busy.value || contactsLoading.value) return
  page.value = Math.max(1, page.value + change)
  await load(true)
}

async function searchContacts() {
  if (busy.value) return
  cancelSearchTimer()
  appliedSearch.value = emailSearch.value.trim()
  emailSearch.value = appliedSearch.value
  page.value = 1
  await load(true)
}

async function clearSearch() {
  emailSearch.value = ''
  await searchContacts()
}

function cancelSearchTimer() {
  clearTimeout(searchTimer)
  searchTimer = undefined
  searchPending.value = false
}

function scheduleSearch() {
  cancelSearchTimer()
  loadRequest++
  contactsBusy.value = false
  contactsError.value = ''
  searchPending.value = true
  searchTimer = setTimeout(() => {
    void searchContacts()
  }, 400)
}
</script>
