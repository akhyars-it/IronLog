<script setup lang="ts">
import type { ChartData } from 'chart.js'
import { computed, onMounted, ref } from 'vue'
import { Line } from 'vue-chartjs'
import GlassBackButton from '../components/GlassBackButton.vue'
import { lineOptions } from '../lib/charts'
import { useHistoryStore } from '../stores/historyStore'

const glass =
  'rounded-3xl border border-white/12 bg-zinc-900/45 shadow-[0_8px_32px_rgba(0,0,0,0.45)] ring-1 ring-inset ring-white/5 backdrop-blur-2xl saturate-150'

const history = useHistoryStore()
const openId = ref<string | null>(null)

onMounted(() => {
  void history.loadRecords()
})

const openRecord = computed(() => history.records.find((record) => record.exerciseId === openId.value) ?? null)

const chartData = computed<ChartData<'line'>>(() => ({
  labels: (openRecord.value?.points ?? []).map((point) => {
    const when = new Date(point.at)
    return Number.isNaN(when.getTime()) ? '' : when.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  }),
  datasets: [
    {
      data: (openRecord.value?.points ?? []).map((point) => point.weight),
      borderColor: '#3b82f6',
      backgroundColor: 'rgba(59, 130, 246, 0.15)',
      tension: 0.25,
      fill: true,
      pointRadius: 2,
    },
  ],
}))

function toggle(id: string) {
  openId.value = openId.value === id ? null : id
}

function formatEpley(value: number | null): string {
  if (value == null) return '—'
  return `${value.toLocaleString(undefined, { maximumFractionDigits: 1 })} kg`
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <GlassBackButton to="/stats" label="Back to stats" />
    <h1 class="mt-3 text-2xl font-semibold tracking-tight">Personal records</h1>
    <p class="mt-1 text-sm text-zinc-400">Best weight for each exercise, then reps. 1RM uses Epley.</p>
    <p v-if="history.loading" class="mt-6 text-sm text-zinc-500">Loading…</p>
    <p v-else-if="history.records.length === 0" class="mt-6 text-sm text-zinc-500">No loaded sets yet.</p>
    <ul class="mt-5 flex flex-col gap-2">
      <li v-for="record in history.records" :key="record.exerciseId" :class="glass">
        <button type="button" class="w-full px-4 py-3 text-left" @click="toggle(record.exerciseId)">
          <p class="font-medium">{{ record.name }}</p>
          <p class="mt-1 text-xs text-zinc-400">
            {{ record.muscle }} · {{ record.weight }} kg × {{ record.reps }} · Epley {{ formatEpley(record.epley) }}
          </p>
        </button>
        <div v-if="openId === record.exerciseId" class="h-40 px-3 pb-3">
          <Line :data="chartData" :options="lineOptions()" />
        </div>
      </li>
    </ul>
  </section>
</template>
