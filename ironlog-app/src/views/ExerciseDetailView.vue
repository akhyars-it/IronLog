<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { Line } from 'vue-chartjs'
import { useRoute } from 'vue-router'
import ExerciseFormModal from '../components/ExerciseFormModal.vue'
import GlassBackButton from '../components/GlassBackButton.vue'
import { lineOptions } from '../lib/charts'
import { useExerciseStore, type ExercisePerformance } from '../stores/exerciseStore'

const route = useRoute()
const store = useExerciseStore()
const performance = ref<ExercisePerformance | null>(null)
const formOpen = ref(false)
const loading = ref(true)

const exercise = computed(() => store.exercises.find((item) => item.id === String(route.params.id)) ?? null)

const chartData = computed(() => ({
  labels: performance.value?.sessions.map((point) => point.label) ?? [],
  datasets: [
    {
      data: performance.value?.sessions.map((point) => point.weight) ?? [],
      borderColor: '#3b82f6',
      backgroundColor: 'rgba(59, 130, 246, 0.15)',
      tension: 0.25,
      fill: true,
      pointRadius: 3,
    },
  ],
}))

async function load() {
  loading.value = true
  if (store.exercises.length === 0) await store.load()
  performance.value = await store.loadPerformance(String(route.params.id))
  loading.value = false
}

onMounted(load)
watch(() => route.params.id, load)

function formatKg(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '—'
  return `${value.toLocaleString(undefined, { maximumFractionDigits: 1 })} kg`
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <GlassBackButton to="/exercises" label="Back to exercises" />
    <div class="mt-3 flex items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">{{ exercise?.name ?? 'Exercise' }}</h1>
        <p v-if="exercise" class="mt-1 text-sm text-zinc-400">
          {{ exercise.primary_muscle }} · {{ exercise.equipment }}
        </p>
      </div>
      <button
        v-if="exercise?.is_custom"
        type="button"
        class="text-sm text-blue-300"
        @click="formOpen = true"
      >
        Edit
      </button>
    </div>

    <p v-if="loading" class="mt-6 text-sm text-zinc-500">Loading history…</p>
    <template v-else-if="performance">
      <div class="mt-5 grid grid-cols-3 gap-2">
        <article class="rounded-2xl border border-zinc-800 bg-zinc-900/70 p-3">
          <p class="text-[10px] font-semibold tracking-wide text-zinc-500">HEAVIEST</p>
          <p class="mt-1 text-sm font-semibold">{{ formatKg(performance.heaviest) }}</p>
        </article>
        <article class="rounded-2xl border border-zinc-800 bg-zinc-900/70 p-3">
          <p class="text-[10px] font-semibold tracking-wide text-zinc-500">BRZYCKI</p>
          <p class="mt-1 text-sm font-semibold">{{ formatKg(performance.bestBrzycki) }}</p>
        </article>
        <article class="rounded-2xl border border-zinc-800 bg-zinc-900/70 p-3">
          <p class="text-[10px] font-semibold tracking-wide text-zinc-500">BEST VOLUME</p>
          <p class="mt-1 text-sm font-semibold">{{ formatKg(performance.bestSessionVolume) }}</p>
        </article>
      </div>

      <div class="mt-5 rounded-2xl border border-zinc-800 bg-zinc-900/40 p-3">
        <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500">SESSION WEIGHT</p>
        <div v-if="performance.sessions.length" class="mt-3 h-48">
          <Line :data="chartData" :options="lineOptions()" />
        </div>
        <p v-else class="mt-3 text-sm text-zinc-500">No sets logged for this exercise yet.</p>
      </div>
    </template>

    <ExerciseFormModal
      v-if="formOpen && exercise"
      :exercise="exercise"
      @close="formOpen = false"
      @saved="store.load()"
    />
  </section>
</template>
