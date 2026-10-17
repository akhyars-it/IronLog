<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Line } from 'vue-chartjs'
import { useRoute, useRouter } from 'vue-router'
import GlassBackButton from '../components/GlassBackButton.vue'
import { lineOptions } from '../lib/charts'
import { useActiveWorkoutStore } from '../stores/activeWorkoutStore'
import { useRoutineStore, type VolumePoint } from '../stores/routineStore'

const route = useRoute()
const router = useRouter()
const routines = useRoutineStore()
const active = useActiveWorkoutStore()
const points = ref<VolumePoint[]>([])
const message = ref('')

const routine = computed(() => routines.routines.find((item) => item.id === String(route.params.id)) ?? null)

const chartData = computed(() => ({
  labels: points.value.map((point) => point.label),
  datasets: [
    {
      data: points.value.map((point) => point.volume),
      borderColor: '#fb923c',
      backgroundColor: 'rgba(251, 146, 60, 0.15)',
      tension: 0.25,
      fill: true,
      pointRadius: 3,
    },
  ],
}))

onMounted(async () => {
  if (routines.routines.length === 0) await routines.load()
  points.value = await routines.volumeHistory(String(route.params.id))
})

function edit() {
  routines.clearDraft()
  void router.push({ name: 'routine-edit', params: { id: String(route.params.id) } })
}

async function start() {
  const current = routine.value
  if (!current) return
  if (active.workout && !window.confirm('A workout is already in progress. Replace it?')) return
  message.value =
    (await active.begin({
      routineId: current.id,
      routineName: current.title,
      items: current.exercises.map((item) => ({ exercise: item.exercise, restSeconds: item.restSeconds })),
    })) ?? ''
  if (!message.value) await router.push({ name: 'live' })
}

async function remove() {
  const current = routine.value
  if (!current || !window.confirm(`Delete ${current.title}?`)) return
  const error = await routines.remove(current.id)
  if (error) {
    message.value = error
    return
  }
  await router.replace({ name: 'workout' })
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <GlassBackButton to="/workout" label="Back to workouts" />
    <div class="mt-3 flex items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">{{ routine?.title ?? 'Routine' }}</h1>
        <p v-if="routine?.description" class="mt-1 text-sm text-zinc-400">{{ routine.description }}</p>
      </div>
      <button type="button" class="text-sm text-blue-300" @click="edit">Edit</button>
    </div>

    <button type="button" class="mt-5 w-full rounded-2xl bg-blue-600 py-3 text-sm font-semibold" @click="start">
      START WORKOUT
    </button>
    <p v-if="message" class="mt-3 text-sm text-red-500">{{ message }}</p>

    <div class="mt-5 rounded-2xl border border-zinc-800 bg-zinc-900/40 p-3">
      <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500">LAST 10 SESSIONS</p>
      <div v-if="points.length" class="mt-3 h-44">
        <Line :data="chartData" :options="lineOptions()" />
      </div>
      <p v-else class="mt-3 text-sm text-zinc-500">No saved sessions for this routine yet.</p>
    </div>

    <ol class="mt-5 flex flex-col gap-2">
      <li
        v-for="(item, index) in routine?.exercises ?? []"
        :key="item.id"
        class="rounded-2xl border border-zinc-800 px-4 py-3"
      >
        <p class="text-sm font-medium">{{ index + 1 }}. {{ item.exercise.name }}</p>
        <p class="mt-1 text-xs text-zinc-400">{{ item.exercise.primary_muscle }} · {{ item.restSeconds }}s rest</p>
      </li>
    </ol>

    <button type="button" class="mt-6 text-sm text-red-500 hover:text-red-400" @click="remove">Delete routine</button>
  </section>
</template>
