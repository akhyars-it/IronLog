<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import GlassBackButton from '../components/GlassBackButton.vue'
import { useActiveWorkoutStore, type ActiveExercise } from '../stores/activeWorkoutStore'
import { useAuthStore } from '../stores/authStore'
import { useExerciseStore } from '../stores/exerciseStore'
import { formatClock } from '../utils/dates'

const router = useRouter()
const auth = useAuthStore()
const active = useActiveWorkoutStore()
const exercises = useExerciseStore()
const message = ref('')

const restName = computed(
  () => active.workout?.exercises.find((item) => item.localId === active.workout?.restExerciseId)?.name ?? 'Rest',
)
const restWidth = computed(() => `${Math.min(100, Math.max(0, active.restProgress * 100))}%`)

function restDigits(totalSeconds: number): string {
  const seconds = Math.max(0, Math.floor(totalSeconds))
  const minutes = Math.floor(seconds / 60)
  const remain = seconds % 60
  return `${minutes}:${String(remain).padStart(2, '0')}`
}

onMounted(() => {
  if (auth.user) active.adopt(auth.user.id)
  if (!active.workout) void router.replace({ name: 'workout' })
})

function previousLabel(exercise: ActiveExercise, index: number): string {
  const previous = exercise.previous[index]
  if (!previous) return '—'
  if (exercise.exerciseType === 'duration') {
    return previous.durationSeconds != null ? `${previous.durationSeconds}s` : '—'
  }
  if (exercise.exerciseType === 'bodyweight_reps') return `${previous.reps} reps`
  return `${previous.weight} × ${previous.reps}`
}

async function addExercise() {
  message.value = ''
  const pending = exercises.armSelection()
  await router.push({ name: 'exercises', query: { select: '1' } })
  const picked = await pending
  if (!picked) return
  message.value = (await active.addExercise(picked)) ?? ''
}

async function replaceExercise(localId: string) {
  message.value = ''
  const pending = exercises.armSelection()
  await router.push({ name: 'exercises', query: { select: '1' } })
  const picked = await pending
  if (!picked) return
  message.value = (await active.replaceExercise(localId, picked)) ?? ''
}

function discard() {
  if (!window.confirm('Discard this workout?')) return
  active.clear()
  void router.replace({ name: 'workout' })
}

function finish() {
  if (active.stats.sets === 0) {
    message.value = 'Check at least one set before finishing.'
    return
  }
  void router.push({ name: 'save' })
}
</script>

<template>
  <section v-if="active.workout" class="px-5 pt-6 pb-28">
    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-2">
        <GlassBackButton class="!mb-0" to="/workout" label="Back to workouts" />
        <button type="button" class="text-sm text-red-500 hover:text-red-400" @click="discard">Discard</button>
      </div>
      <p class="font-mono text-sm text-blue-300">{{ formatClock(active.elapsedSeconds) }}</p>
      <button type="button" class="text-sm font-semibold text-blue-300" @click="finish">Finish</button>
    </div>
    <h1 class="mt-4 text-2xl font-semibold tracking-tight">{{ active.workout.routineName }}</h1>
    <p class="mt-1 text-sm text-zinc-400">
      {{ active.stats.sets }} sets · {{ active.stats.volume.toLocaleString(undefined, { maximumFractionDigits: 0 }) }} kg
    </p>
    <p v-if="message" class="mt-3 text-sm text-red-500">{{ message }}</p>

    <article
      v-for="exercise in active.workout.exercises"
      :key="exercise.localId"
      class="mt-4 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-4"
    >
      <div class="flex items-start justify-between gap-3">
        <div>
          <h2 class="font-medium">{{ exercise.name }}</h2>
          <p class="mt-1 text-xs text-zinc-500">{{ exercise.primaryMuscle }}</p>
        </div>
        <div class="flex gap-3 text-xs">
          <button type="button" class="text-blue-300" @click="replaceExercise(exercise.localId)">Replace</button>
          <button type="button" class="text-red-500 hover:text-red-400" @click="active.removeExercise(exercise.localId)">Remove</button>
        </div>
      </div>

      <div class="mt-3 flex items-center gap-2 text-xs text-zinc-400">
        <span>Rest {{ exercise.restSeconds }}s</span>
        <button type="button" class="rounded-full border border-zinc-700 px-2 py-1" @click="active.adjustExerciseRest(exercise.localId, -15)">
          -15s
        </button>
        <button type="button" class="rounded-full border border-zinc-700 px-2 py-1" @click="active.adjustExerciseRest(exercise.localId, 15)">
          +15s
        </button>
      </div>

      <div class="mt-3 grid grid-cols-[1.4rem_1fr_1fr_2rem] gap-2 text-[10px] font-semibold tracking-wide text-zinc-500">
        <span>SET</span>
        <span>PREVIOUS</span>
        <span>{{ exercise.exerciseType === 'duration' ? 'SECONDS' : exercise.exerciseType === 'bodyweight_reps' ? 'REPS' : 'KG / REPS' }}</span>
        <span></span>
      </div>

      <div v-for="(set, index) in exercise.sets" :key="set.id" class="mt-2 grid grid-cols-[1.4rem_1fr_1fr_2rem] items-center gap-2">
        <span class="text-sm text-zinc-400">{{ index + 1 }}</span>
        <span class="text-xs text-zinc-500">{{ previousLabel(exercise, index) }}</span>
        <div class="flex gap-1">
          <input
            v-if="exercise.exerciseType === 'reps_and_weight'"
            v-model="set.weight"
            :disabled="set.done"
            inputmode="decimal"
            class="set-input"
            placeholder="kg"
          />
          <input
            v-if="exercise.exerciseType !== 'duration'"
            v-model="set.reps"
            :disabled="set.done"
            inputmode="numeric"
            class="set-input"
            placeholder="reps"
          />
          <input
            v-else
            v-model="set.durationSeconds"
            :disabled="set.done"
            inputmode="numeric"
            class="set-input"
            placeholder="sec"
          />
        </div>
        <button
          type="button"
          class="grid h-8 w-8 place-items-center rounded-lg border text-sm"
          :class="set.done ? 'border-blue-500 bg-blue-600' : 'border-zinc-700'"
          :aria-label="set.done ? 'Uncheck set' : 'Check set'"
          @click="active.toggleSet(exercise.localId, set.id)"
        >
          {{ set.done ? '✓' : '' }}
        </button>
      </div>

      <label class="mt-3 flex flex-col gap-1 text-xs text-zinc-400">
        Notes
        <input v-model="exercise.notes" class="set-input" placeholder="Optional" />
      </label>
      <div class="mt-3 flex gap-3 text-xs">
        <button type="button" class="text-blue-300" @click="active.addSet(exercise.localId)">Add set</button>
        <button
          v-if="exercise.sets.length"
          type="button"
          class="text-red-500 hover:text-red-400"
          @click="active.removeSet(exercise.localId, exercise.sets[exercise.sets.length - 1]?.id ?? '')"
        >
          Remove last
        </button>
      </div>
    </article>

    <button type="button" class="mt-4 w-full rounded-2xl border border-dashed border-zinc-700 py-3 text-sm" @click="addExercise">
      Add exercise
    </button>

    <div v-if="active.restRemaining > 0" class="pointer-events-none fixed inset-x-0 bottom-[calc(1.5rem+env(safe-area-inset-bottom))] z-40 flex justify-center px-4">
      <div
        class="pointer-events-auto w-full max-w-sm rounded-3xl border border-white/15 bg-zinc-900/35 px-4 py-4 shadow-[0_8px_32px_rgba(0,0,0,0.5)] backdrop-blur-2xl saturate-150"
      >
        <p class="truncate text-center text-[11px] font-medium tracking-wide text-zinc-300">{{ restName }}</p>
        <p class="mt-1 text-center font-mono text-4xl font-semibold tracking-tight text-white">
          {{ restDigits(active.restRemaining) }}
        </p>
        <div class="mt-3 h-1.5 overflow-hidden rounded-full bg-white/10">
          <div
            class="h-full max-w-full rounded-full bg-blue-400 shadow-[0_0_14px_rgba(96,165,250,0.95)]"
            :style="{ width: restWidth }"
          ></div>
        </div>
        <div class="mt-4 grid grid-cols-3 gap-2 text-sm">
          <button type="button" class="rounded-full border border-white/15 bg-white/5 py-2 backdrop-blur" @click="active.adjustRest(-15)">
            -15s
          </button>
          <button type="button" class="rounded-full border border-white/15 bg-white/5 py-2 backdrop-blur" @click="active.adjustRest(15)">
            +15s
          </button>
          <button type="button" class="rounded-full border border-blue-400/30 bg-blue-500/15 py-2 font-semibold text-blue-300" @click="active.skipRest()">
            Skip
          </button>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.set-input {
  width: 100%;
  min-width: 0;
  border-radius: 0.6rem;
  border: 1px solid #27272a;
  background: #09090b;
  padding: 0.4rem 0.5rem;
  font-size: 0.875rem;
  outline: none;
}
.set-input:disabled {
  opacity: 0.55;
}
.set-input:focus {
  border-color: #3b82f6;
}
</style>
