<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import MuscleBodyMap from '../components/MuscleBodyMap.vue'
import { useHistoryStore } from '../stores/historyStore'
import type { PrimaryMuscle } from '../types/database'
import { dateKey, startOfDay } from '../utils/dates'
import { MUSCLE_COLORS, MUSCLE_ORDER } from '../utils/workoutSets'

const glass =
  'rounded-3xl border border-white/12 bg-zinc-900/45 shadow-[0_8px_32px_rgba(0,0,0,0.45)] ring-1 ring-inset ring-white/5 backdrop-blur-2xl saturate-150'

const history = useHistoryStore()
const selectedKey = ref(dateKey(new Date()))
const mapMode = ref<'day' | 30 | 90>('day')
const pickedMuscle = ref<{ id: string; label: string; group: PrimaryMuscle } | null>(null)

function emptyCounts(): Record<PrimaryMuscle, number> {
  return Object.fromEntries(MUSCLE_ORDER.map((muscle) => [muscle, 0])) as Record<PrimaryMuscle, number>
}

onMounted(() => {
  void history.loadCatalog()
  void history.loadMuscleSets()
})

const days = computed(() => {
  const result: { key: string; label: string; count: number; muscles: Record<PrimaryMuscle, number> }[] = []
  for (let offset = 6; offset >= 0; offset -= 1) {
    const day = new Date()
    day.setDate(day.getDate() - offset)
    const key = dateKey(day)
    const muscles = Object.fromEntries(MUSCLE_ORDER.map((muscle) => [muscle, 0])) as Record<PrimaryMuscle, number>
    let count = 0
    for (const set of history.muscleSets) {
      if (dateKey(new Date(set.startTime)) !== key) continue
      count += 1
      muscles[set.muscle] += 1
    }
    result.push({
      key,
      label: day.toLocaleDateString(undefined, { weekday: 'narrow' }),
      count,
      muscles,
    })
  }
  return result
})

const selected = computed(() => days.value.find((day) => day.key === selectedKey.value) ?? days.value[days.value.length - 1])

const mapCounts = computed(() => {
  if (mapMode.value === 'day') return selected.value?.muscles ?? emptyCounts()
  const since = startOfDay(new Date())
  since.setDate(since.getDate() - (mapMode.value - 1))
  const counts = emptyCounts()
  for (const set of history.muscleSets) {
    if (new Date(set.startTime) >= since) counts[set.muscle] += 1
  }
  return counts
})

const pickedCount = computed(() => (pickedMuscle.value ? mapCounts.value[pickedMuscle.value.group] : 0))

const totals = computed(() => {
  const workouts = history.catalog.length
  const seconds = history.catalog.reduce((sum, workout) => sum + workout.duration_seconds, 0)
  const volume = history.catalog.reduce((sum, workout) => sum + workout.total_volume, 0)
  const sets = history.catalog.reduce((sum, workout) => sum + workout.total_sets, 0)
  return { workouts, hours: seconds / 3600, volume, sets }
})
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <div class="flex items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">Stats</h1>
        <p class="mt-1 text-sm text-zinc-400">Sets, muscles, and lifetime totals.</p>
      </div>
      <RouterLink to="/stats/records" class="text-sm text-blue-300">PRs</RouterLink>
    </div>

    <div class="mt-5 p-3" :class="glass">
      <div class="grid grid-cols-7 gap-1">
        <button
          v-for="day in days"
          :key="day.key"
          type="button"
          class="rounded-2xl border px-1 py-2 text-center"
          :class="day.key === selectedKey ? 'border-blue-400/40 bg-blue-500/20 text-blue-300' : 'border-white/10 bg-white/5'"
          @click="selectedKey = day.key; mapMode = 'day'; pickedMuscle = null"
        >
          <span class="block text-[10px] text-zinc-500">{{ day.label }}</span>
          <span class="mt-1 block text-sm font-semibold">{{ day.count }}</span>
        </button>
      </div>
      <div v-if="selected" class="mt-3 flex flex-wrap gap-2">
        <span
          v-for="muscle in MUSCLE_ORDER"
          :key="muscle"
          class="rounded-full border px-2 py-1 text-[11px]"
          :class="selected.muscles[muscle] > 0 ? 'border-transparent text-zinc-950' : 'border-white/10 text-zinc-500'"
          :style="selected.muscles[muscle] > 0 ? { backgroundColor: MUSCLE_COLORS[muscle] } : undefined"
        >
          {{ muscle }} {{ selected.muscles[muscle] || '' }}
        </span>
      </div>
    </div>

    <div class="mt-5 p-4" :class="glass">
      <div class="flex items-center justify-between gap-2">
        <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500">BODY MAP</p>
        <div class="flex gap-2 text-xs">
          <button type="button" :class="mapMode === 'day' ? 'text-blue-300' : 'text-zinc-500'" @click="mapMode = 'day'">Day</button>
          <button type="button" :class="mapMode === 30 ? 'text-blue-300' : 'text-zinc-500'" @click="mapMode = 30">30d</button>
          <button type="button" :class="mapMode === 90 ? 'text-blue-300' : 'text-zinc-500'" @click="mapMode = 90">90d</button>
        </div>
      </div>
      <MuscleBodyMap class="mt-2" :counts="mapCounts" :selected="pickedMuscle?.id ?? null" @select="pickedMuscle = $event" />
      <p v-if="pickedMuscle" class="mt-2 text-center text-sm">
        <span class="font-semibold">{{ pickedMuscle.label }}</span>
        <span class="text-zinc-400"> · {{ pickedMuscle.group }} · {{ pickedCount }} {{ pickedCount === 1 ? 'set' : 'sets' }}</span>
      </p>
      <p v-else class="mt-2 text-center text-xs text-zinc-500">Tap a muscle to see its set count.</p>
    </div>

    <div class="mt-5 grid grid-cols-2 gap-2 text-sm">
      <article class="p-4" :class="glass">
        <p class="text-xs text-zinc-500">Workouts</p>
        <p class="mt-1 text-lg font-semibold">{{ totals.workouts }}</p>
      </article>
      <article class="p-4" :class="glass">
        <p class="text-xs text-zinc-500">Hours</p>
        <p class="mt-1 text-lg font-semibold">{{ totals.hours.toFixed(1) }}</p>
      </article>
      <article class="p-4" :class="glass">
        <p class="text-xs text-zinc-500">Volume</p>
        <p class="mt-1 text-lg font-semibold">{{ Math.round(totals.volume).toLocaleString() }} kg</p>
      </article>
      <article class="p-4" :class="glass">
        <p class="text-xs text-zinc-500">Sets</p>
        <p class="mt-1 text-lg font-semibold">{{ totals.sets }}</p>
      </article>
    </div>
  </section>
</template>
