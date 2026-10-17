<script setup lang="ts">
import { Play } from 'lucide-vue-next'
import { onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useActiveWorkoutStore } from '../stores/activeWorkoutStore'
import { useAuthStore } from '../stores/authStore'
import { useRoutineStore, type RoutineDetail } from '../stores/routineStore'

const router = useRouter()
const auth = useAuthStore()
const routines = useRoutineStore()
const active = useActiveWorkoutStore()
const message = ref('')

onMounted(async () => {
  if (auth.user) active.adopt(auth.user.id)
  await routines.load()
})

function createRoutine() {
  routines.clearDraft()
  void router.push({ name: 'routine-new' })
}

async function launch(routine: RoutineDetail | null) {
  message.value = ''
  if (active.workout && !window.confirm('A workout is already in progress. Replace it?')) return
  const error = await active.begin(
    routine
      ? {
          routineId: routine.id,
          routineName: routine.title,
          items: routine.exercises.map((item) => ({ exercise: item.exercise, restSeconds: item.restSeconds })),
        }
      : { routineId: null, routineName: 'Empty Workout', items: [] },
  )
  if (error) {
    message.value = error
    return
  }
  await router.push({ name: 'live' })
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <div class="flex items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">Workout</h1>
        <p class="mt-1 text-sm text-zinc-400">Start a routine or an empty session.</p>
      </div>
      <button type="button" class="rounded-full bg-blue-600 px-3 py-1.5 text-xs font-semibold" @click="createRoutine">
        New
      </button>
    </div>

    <button
      v-if="active.workout"
      type="button"
      class="mt-5 w-full rounded-2xl border border-blue-500/40 bg-blue-500/10 px-4 py-3 text-left"
      @click="router.push({ name: 'live' })"
    >
      <p class="text-xs font-semibold tracking-[0.16em] text-blue-300">IN PROGRESS</p>
      <p class="mt-1 font-medium">{{ active.workout.routineName }}</p>
    </button>

    <button
      type="button"
      class="mt-4 w-full rounded-2xl border border-zinc-800 bg-zinc-900 px-4 py-3 text-sm font-semibold"
      @click="launch(null)"
    >
      Start Empty Workout
    </button>
    <p v-if="message || routines.error" class="mt-3 text-sm text-red-500">{{ message || routines.error }}</p>
    <p v-if="routines.loading" class="mt-6 text-sm text-zinc-500">Loading…</p>
    <p v-else-if="routines.routines.length === 0" class="mt-6 text-sm text-zinc-500">No routines yet.</p>

    <ul class="mt-4 flex flex-col gap-3">
      <li v-for="routine in routines.routines" :key="routine.id" class="rounded-2xl border border-zinc-800 bg-zinc-900/70">
        <div class="flex items-stretch">
          <RouterLink :to="{ name: 'routine', params: { id: routine.id } }" class="flex-1 px-4 py-3">
            <p class="font-medium">{{ routine.title }}</p>
            <p class="mt-1 text-xs text-zinc-400">{{ routine.exercises.length }} exercises</p>
          </RouterLink>
          <button
            type="button"
            class="grid w-14 place-items-center text-blue-400"
            :aria-label="`Start ${routine.title}`"
            @click="launch(routine)"
          >
            <Play :size="18" />
          </button>
        </div>
      </li>
    </ul>
  </section>
</template>
