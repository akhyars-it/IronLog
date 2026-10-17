<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import GlassBackButton from '../components/GlassBackButton.vue'
import { useHistoryStore } from '../stores/historyStore'
import type { HistoryWorkout } from '../types/history'
import { formatWhen } from '../utils/dates'
import { MUSCLE_COLORS, formatSet, groupWorkoutSets, muscleSplit, topSetIds } from '../utils/workoutSets'

const route = useRoute()
const history = useHistoryStore()
const workout = ref<HistoryWorkout | null>(null)
const loading = ref(true)

onMounted(async () => {
  workout.value = await history.loadWorkout(String(route.params.id))
  loading.value = false
})

const groups = computed(() => (workout.value ? groupWorkoutSets(workout.value.sets) : []))
const split = computed(() => (workout.value ? muscleSplit(workout.value.sets) : []))
const tops = computed(() => (workout.value ? topSetIds(workout.value.sets) : new Set<string>()))
const records = computed(() => workout.value?.records_broken ?? 0)
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <GlassBackButton to="/" label="Back to dashboard" />
    <p v-if="loading" class="mt-6 text-sm text-zinc-500">Loading…</p>
    <p v-else-if="!workout" class="mt-6 text-sm text-zinc-500">{{ history.error || 'Workout not found.' }}</p>
    <template v-else>
      <h1 class="mt-3 text-2xl font-semibold tracking-tight">{{ workout.routine_name }}</h1>
      <p class="mt-1 text-sm text-zinc-400">
        {{ formatWhen(workout.start_time) }} · {{ Math.round(workout.duration_seconds / 60) }} min ·
        {{ Math.round(workout.total_volume) }} kg
      </p>
      <p class="mt-3 text-sm">
        <span class="font-semibold">{{ records }}</span>
        <span class="text-zinc-400"> {{ records === 1 ? 'record' : 'records' }} broken</span>
      </p>
      <p v-if="workout.notes" class="mt-2 text-sm text-zinc-300">{{ workout.notes }}</p>

      <div v-if="split.length" class="mt-5">
        <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500">MUSCLE SPLIT</p>
        <div class="mt-2 flex h-2 overflow-hidden rounded-full bg-zinc-800">
          <div
            v-for="part in split"
            :key="part.muscle"
            class="h-full"
            :style="{ width: `${part.percent}%`, backgroundColor: MUSCLE_COLORS[part.muscle] }"
          ></div>
        </div>
        <ul class="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-zinc-400">
          <li v-for="part in split" :key="`${part.muscle}-label`">
            {{ part.muscle }} {{ Math.round(part.percent) }}%
          </li>
        </ul>
      </div>

      <article v-for="group in groups" :key="group.exerciseId" class="mt-5">
        <h2 class="font-medium">{{ group.name }}</h2>
        <p class="text-xs text-zinc-500">{{ group.muscle }}</p>
        <ul class="mt-2 flex flex-col gap-1.5">
          <li
            v-for="set in group.sets"
            :key="set.id"
            class="flex items-center justify-between rounded-xl border border-zinc-800 px-3 py-2 text-sm"
          >
            <span>{{ formatSet(set) }}</span>
            <span class="flex gap-1">
              <span v-if="set.is_pr" class="rounded-full bg-blue-600 px-2 py-0.5 text-[10px] font-semibold">PR</span>
              <span
                v-if="tops.has(set.id)"
                class="rounded-full bg-orange-500 px-2 py-0.5 text-[10px] font-semibold text-zinc-950"
              >
                TOP SET
              </span>
            </span>
          </li>
        </ul>
        <p v-if="group.notes" class="mt-1 text-xs text-zinc-400">{{ group.notes }}</p>
      </article>
    </template>
  </section>
</template>
