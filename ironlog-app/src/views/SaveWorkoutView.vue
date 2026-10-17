<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import GlassBackButton from '../components/GlassBackButton.vue'
import { useActiveWorkoutStore } from '../stores/activeWorkoutStore'
import { formatClock, formatWhen } from '../utils/dates'

const router = useRouter()
const active = useActiveWorkoutStore()
const saving = ref(false)
const errorMessage = ref('')

onMounted(() => {
  if (!active.workout) void router.replace({ name: 'workout' })
})

async function save() {
  if (active.stats.sets === 0) {
    errorMessage.value = 'Check at least one set before finishing.'
    return
  }
  saving.value = true
  errorMessage.value = ''
  const error = await active.save()
  saving.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  await router.replace({ name: 'dashboard', query: { saved: '1' } })
}
</script>

<template>
  <section v-if="active.workout" class="px-5 pt-6 pb-10">
    <GlassBackButton label="Back to workout" />
    <h1 class="mt-4 text-2xl font-semibold tracking-tight">Save workout</h1>
    <p class="mt-1 text-sm text-zinc-400">{{ active.workout.routineName }}</p>

    <dl class="mt-5 grid grid-cols-2 gap-2 text-sm">
      <div class="rounded-2xl border border-zinc-800 p-3">
        <dt class="text-xs text-zinc-500">Duration</dt>
        <dd class="mt-1 font-mono">{{ formatClock(active.elapsedSeconds) }}</dd>
      </div>
      <div class="rounded-2xl border border-zinc-800 p-3">
        <dt class="text-xs text-zinc-500">Started</dt>
        <dd class="mt-1">{{ formatWhen(active.workout.startTime) }}</dd>
      </div>
      <div class="rounded-2xl border border-zinc-800 p-3">
        <dt class="text-xs text-zinc-500">Sets</dt>
        <dd class="mt-1">{{ active.stats.sets }}</dd>
      </div>
      <div class="rounded-2xl border border-zinc-800 p-3">
        <dt class="text-xs text-zinc-500">Volume</dt>
        <dd class="mt-1">{{ active.stats.volume.toLocaleString(undefined, { maximumFractionDigits: 0 }) }} kg</dd>
      </div>
    </dl>

    <label class="mt-5 flex flex-col gap-1.5 text-sm">
      Notes
      <textarea v-model="active.workout.summaryNotes" rows="3" class="field" placeholder="How did it feel?" />
    </label>
    <p v-if="errorMessage" class="mt-3 text-sm text-red-500">{{ errorMessage }}</p>
    <button
      type="button"
      class="mt-5 w-full rounded-2xl bg-blue-600 py-3 text-sm font-semibold disabled:opacity-50"
      :disabled="saving || active.stats.sets === 0"
      @click="save"
    >
      {{ saving ? 'Saving…' : 'Save workout' }}
    </button>
  </section>
</template>

<style scoped>
.field {
  width: 100%;
  border-radius: 0.75rem;
  border: 1px solid #27272a;
  background: #18181b;
  padding: 0.75rem;
  outline: none;
}
.field:focus {
  border-color: #3b82f6;
}
</style>
