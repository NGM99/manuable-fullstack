<template>
  <header class="border-b border-slate-200 bg-white">
    <nav
      class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-5 py-5"
    >
      <a href="/" class="text-xl font-extrabold tracking-wider text-blue-800"
        >MANUABLE</a
      >
      <a
        :href="admin ? '/' : '/admin'"
        class="text-sm font-medium text-slate-600 hover:text-blue-700"
      >
        {{ admin ? "Volver al cotizador" : "Acceso Comercial" }}
      </a>
    </nav>
  </header>
  <main class="mx-auto max-w-6xl px-5 py-10 sm:py-14">
    <AdminDashboard v-if="admin" />
    <QuoteForm v-else />
  </main>
</template>

<script setup lang="ts">
import QuoteForm from "./components/QuoteForm.vue";
import AdminDashboard from "./components/AdminDashboard.vue";
const admin = window.location.pathname.startsWith("/admin");
</script>
