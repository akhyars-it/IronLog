<script setup lang="ts">
import { Flame, Moon, Trophy } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useHistoryStore } from '../stores/historyStore'
import { dateKey, startOfWeekMonday } from '../utils/dates'
import { calculateWeekStreakAndRestDays } from '../utils/fitnessMath'

const history = useHistoryStore()
const cursor = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1))
const selectedKey = ref(dateKey(new Date()))

onMounted(() => {
  void history.loadCatalog()
})

const monthLabel = computed(() => cursor.value.toLocaleDateString(undefined, { month: 'long', year: 'numeric' }))

const cells = computed(() => {
  const year = cursor.value.getFullYear()
  const month = cursor.value.getMonth()
  const first = new Date(year, month, 1)
  const pad = (first.getDay() + 6) % 7
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const slots: { key: string | null; day: number | null }[] = []
  for (let index = 0; index < pad; index += 1) slots.push({ key: null, day: null })
  for (let day = 1; day <= daysInMonth; day += 1) {
    slots.push({ key: dateKey(new Date(year, month, day)), day })
  }
  return slots
})

const marked = computed(() => {
  const keys = new Set<string>()
  for (const workout of history.catalog) keys.add(dateKey(new Date(workout.start_time)))
  return keys
})

const selectedWorkouts = computed(() =>
  history.catalog.filter((workout) => dateKey(new Date(workout.start_time)) === selectedKey.value),
)

const streak = computed(() =>
  calculateWeekStreakAndRestDays(history.catalog.map((workout) => new Date(workout.start_time))),
)

const weekStart = computed(() => startOfWeekMonday(new Date()))

const canGoForward = computed(() => {
  const now = new Date()
  return cursor.value.getFullYear() < now.getFullYear() || cursor.value.getMonth() < now.getMonth()
})

function shift(delta: number) {
  const next = new Date(cursor.value)
  next.setMonth(next.getMonth() + delta)
  if (delta > 0 && !canGoForward.value) return
  cursor.value = next
}

const todayKey = dateKey(new Date())

function isWeekend(key: string): boolean {
  const day = new Date(`${key}T12:00:00`).getDay()
  return day === 0 || day === 6
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <h1 class="text-center text-sm font-bold tracking-[0.18em]">CALENDAR</h1>
    <div class="mt-5 grid grid-cols-2 gap-3">
      <article class="rounded-[20px] border border-white/10 bg-gradient-to-br from-orange-500/30 via-amber-400/10 to-white/5 p-4 text-center shadow-[0_0_28px_rgba(251,146,60,0.18)] backdrop-blur-xl">
        <Flame class="mx-auto text-orange-400 drop-shadow-[0_0_10px_rgba(251,146,60,0.85)]" :size="28" />
        <p class="mt-2 text-lg font-bold">{{ streak.weekStreak }} weeks</p>
        <p class="text-[10px] font-bold tracking-wide text-white/60">WEEK STREAK</p>
        <p class="mt-2 flex items-center justify-center gap-1 text-[11px] text-amber-200">
          <Trophy :size="14" class="text-amber-300" />
          Monday {{ weekStart.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) }}
        </p>
      </article>
      <article class="rounded-[20px] border border-white/10 bg-gradient-to-br from-blue-500/30 via-cyan-400/10 to-white/5 p-4 text-center shadow-[0_0_28px_rgba(59,130,246,0.18)] backdrop-blur-xl">
        <Moon class="mx-auto text-blue-300 drop-shadow-[0_0_10px_rgba(96,165,250,0.85)]" :size="28" />
        <p class="mt-2 text-lg font-bold">{{ streak.restDays == null ? '—' : streak.restDays }}</p>
        <p class="text-[10px] font-bold tracking-wide text-white/60">REST DAYS</p>
      </article>
    </div>

    <div class="mt-6 rounded-[20px] border border-white/10 bg-white/5 p-3 backdrop-blur-xl">
      <div class="flex items-center justify-between px-1">
        <button type="button" class="grid h-8 w-8 place-items-center rounded-full text-lg" aria-label="Previous month" @click="shift(-1)">‹</button>
        <p class="text-[17px] font-bold">{{ monthLabel }}</p>
        <button type="button" class="grid h-8 w-8 place-items-center rounded-full text-lg disabled:opacity-30" aria-label="Next month" :disabled="!canGoForward" @click="shift(1)">›</button>
      </div>
      <div class="mt-3 grid grid-cols-7 gap-1 text-center text-[10px] font-bold text-white/40">
        <span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span class="text-white/60">S</span><span class="text-white/60">S</span>
      </div>
      <div class="mt-1 grid grid-cols-7 gap-1">
        <button
          v-for="(cell, index) in cells"
          :key="cell.key ?? `pad-${index}`"
          type="button"
          class="relative flex h-11 flex-col items-center justify-center rounded-full text-sm"
          :class="[
            cell.key ? '' : 'pointer-events-none',
            cell.key && isWeekend(cell.key) ? 'text-white/70' : 'text-white',
            cell.key === selectedKey ? 'bg-blue-500 shadow-[0_0_16px_rgba(59,130,246,0.65)] ring-2 ring-blue-300' : '',
            cell.key === todayKey && cell.key !== selectedKey ? 'bg-white/10' : '',
          ]"
          :disabled="!cell.key"
          @click="cell.key && (selectedKey = cell.key)"
        >
          <span>{{ cell.day }}</span>
          <span
            class="absolute bottom-1 h-1.5 w-1.5 rounded-full"
            :class="cell.key && marked.has(cell.key) ? 'bg-green-400 shadow-[0_0_8px_rgba(74,222,128,0.95)]' : 'bg-transparent'"
          ></span>
        </button>
      </div>
    </div>

    <div class="mt-4 flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-4 py-2.5 text-xs text-white/60 backdrop-blur-xl">
      <span class="h-2.5 w-2.5 rounded-full bg-green-400 shadow-[0_0_8px_rgba(74,222,128,0.95)]"></span>
      Workout day
    </div>

    <h2 class="mt-6 text-sm font-semibold">{{ selectedKey }}</h2>
    <p v-if="selectedWorkouts.length === 0" class="mt-2 text-sm text-zinc-500">No workouts this day.</p>
    <ul class="mt-2 flex flex-col gap-2">
      <li v-for="workout in selectedWorkouts" :key="workout.id">
        <RouterLink
          :to="{ name: 'workout-detail', params: { id: workout.id } }"
          class="block rounded-2xl border border-white/10 bg-white/5 px-4 py-3 backdrop-blur-xl"
        >
          <p class="font-medium">{{ workout.routine_name }}</p>
          <p class="mt-1 text-xs text-zinc-400">
            {{ new Date(workout.start_time).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' }) }} ·
            {{ workout.total_sets }} sets
          </p>
        </RouterLink>
      </li>
    </ul>
  </section>
</template>
