<template>
  <section class="grid gap-8 lg:grid-cols-[1fr_1.1fr]">
    <div>
      <p
        class="mb-3 text-sm font-semibold uppercase tracking-wider text-blue-700"
      >
        Cotiza tu envío
      </p>
      <h1 class="text-4xl font-bold tracking-tight text-slate-900 sm:text-5xl">
        Encuentra una tarifa para tu próximo envío.
      </h1>
      <p class="mt-5 max-w-lg text-lg leading-relaxed text-slate-600">
        Compara las opciones disponibles con tu código postal y el peso del
        paquete.
      </p>
      <p class="mt-6 text-sm leading-relaxed text-slate-500">
        Los importes son estimaciones basadas en tarifas registradas. La
        cobertura y el plazo deben confirmarse antes de contratar.
      </p>
    </div>

    <form class="panel space-y-5" novalidate @submit.prevent="submit">
      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <label for="origin" class="label">CP de origen</label>
          <input
            id="origin"
            v-model="form.origin_postal_code"
            class="field"
            inputmode="numeric"
            autocomplete="postal-code"
            placeholder="06600"
            :aria-invalid="!!errors.origin_postal_code"
            aria-describedby="origin-error"
          />
          <p id="origin-error" class="error">{{ errors.origin_postal_code }}</p>
        </div>
        <div>
          <label for="destination" class="label">CP de destino</label>
          <input
            id="destination"
            v-model="form.destination_postal_code"
            class="field"
            inputmode="numeric"
            placeholder="64000"
            :aria-invalid="!!errors.destination_postal_code"
            aria-describedby="destination-error"
          />
          <p id="destination-error" class="error">
            {{ errors.destination_postal_code }}
          </p>
        </div>
      </div>
      <div>
        <label for="weight" class="label">Peso del paquete en kg</label>
        <input
          id="weight"
          v-model="form.weight_kg"
          class="field"
          type="number"
          min="0.001"
          step="0.001"
          placeholder="Ej. 2.5"
          :aria-invalid="!!errors.weight_kg"
          aria-describedby="weight-error"
        />
        <p id="weight-error" class="error">{{ errors.weight_kg }}</p>
      </div>
      <div>
        <label for="email" class="label">Correo electrónico</label>
        <input
          id="email"
          v-model="form.email"
          class="field"
          type="email"
          autocomplete="email"
          placeholder="tu@tienda.mx"
          :aria-invalid="!!errors.email"
          aria-describedby="email-error email-help"
        />
        <p id="email-error" class="error">{{ errors.email }}</p>
        <p id="email-help" class="mt-2 text-xs text-slate-500">
          Tu correo se guardará para dar seguimiento a esta cotización.
        </p>
      </div>
      <button class="primary w-full" :disabled="busy" type="submit">
        {{ busy ? "Buscando opciones…" : "Cotizar envío" }}
      </button>
      <p v-if="busy" role="status" class="text-sm text-slate-600">
        Estamos consultando tus códigos postales.
      </p>
      <p v-if="message" role="alert" class="error">{{ message }}</p>
    </form>
  </section>

  <section v-if="result" class="mt-10" aria-live="polite">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
      <h2 class="text-2xl font-semibold text-slate-900">
        Tu cotización #{{ result.id }}
      </h2>
      <span v-if="result.distance_km != null" class="text-sm text-slate-500">
        {{ Number(result.distance_km).toFixed(1) }} km en línea recta · Zona
        {{ result.zone }}
      </span>
    </div>
    <p
      :class="
        result.status === 'quoted'
          ? 'text-slate-600'
          : 'rounded-xl bg-amber-50 p-4 text-amber-900'
      "
    >
      {{ result.message }}
    </p>
    <div
      v-if="result.options.length"
      class="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
    >
      <article
        v-for="(option, index) in result.options"
        :key="index"
        class="panel"
      >
        <h3 class="text-lg font-semibold text-slate-900">
          {{ option.carrier_name }}
        </h3>
        <p class="mt-4 text-3xl font-bold text-blue-800">
          {{ money(option.price_mxn) }}
        </p>
        <p class="mt-2 text-sm text-slate-600">{{ delivery(option) }}</p>
      </article>
    </div>
    <p v-if="result.options.length" class="mt-4 text-xs text-slate-500">
      La distancia geográfica no equivale a distancia por carretera. Tarifas
      sujetas a confirmación de cobertura.
    </p>
  </section>
</template>

<script setup lang="ts">
import { reactive, ref } from "vue";
import { delivery, money, type QuoteResult } from "../api";
import { http } from "../http";

const form = reactive({
  origin_postal_code: "",
  destination_postal_code: "",
  weight_kg: "",
  email: "",
});
const errors = ref<Record<string, string>>({});
const busy = ref(false);
const message = ref("");
const result = ref<QuoteResult | null>(null);

async function submit() {
  errors.value = {};
  message.value = "";
  result.value = null;
  form.origin_postal_code = form.origin_postal_code.trim();
  form.destination_postal_code = form.destination_postal_code.trim();
  form.email = form.email.trim();
  for (const field of [
    "origin_postal_code",
    "destination_postal_code",
  ] as const) {
    if (!/^[0-9]{5}$/.test(form[field]))
      errors.value[field] = "Escribe cinco dígitos.";
  }
  if (
    !/^[0-9]+(?:\.[0-9]{1,3})?$/.test(form.weight_kg) ||
    Number(form.weight_kg) <= 0
  )
    errors.value.weight_kg = "Usa un peso positivo con hasta tres decimales.";
  if (!/^[^\s@]+@[^\s@]+$/.test(form.email))
    errors.value.email = "Escribe un correo válido.";
  if (Object.keys(errors.value).length) return;
  busy.value = true;
  try {
    const { data } = await http.post<{
      quote?: QuoteResult;
      errors?: Record<string, string>;
      message?: string;
    }>("/quotes", { ...form }, {
      // Rails also returns useful messages and saved quotes with 422 or 503.
      validateStatus: () => true,
    });
    if (data.quote) result.value = data.quote;
    else {
      errors.value = data.errors || {};
      message.value =
        data.message ||
        (data.errors
          ? "Revisa los campos indicados."
          : "No pudimos cotizar. Intenta de nuevo.");
    }
  } catch {
    message.value =
      "No pudimos completar la conexión. Intenta de nuevo en unos momentos.";
  } finally {
    busy.value = false;
  }
}
</script>
