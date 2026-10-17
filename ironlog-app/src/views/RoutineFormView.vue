<script setup lang="ts">
import { onMounted, ref } from 'vue'
import GlassBackButton from '../components/GlassBackButton.vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import { useExerciseStore } from '../stores/exerciseStore'
import { useRoutineStore } from '../stores/routineStore'

const route = useRoute()
const router = useRouter()
const routines = useRoutineStore()
const exercises = useExerciseStore()
const saving = ref(false)
const errorMessage = ref('')

const routineId = route.params.id ? String(route.params.id) : null

onMounted(() => {
  void routines.ensureDraft(routineId)
})

onBeforeRouteLeave((to) => {
  if (to.name === 'exercises' && to.query.select === '1') return true
  routines.clearDraft()
  return true
})

async function addExercise() {
  const pending = exercises.armSelection()
  await router.push({ name: 'exercises', query: { select: '1' } })
  const picked = await pending
  if (picked) routines.addDraftExercise(picked)
}

async function save() {
  saving.value = true
  errorMessage.value = ''
  const error = await routines.saveDraft()
  saving.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  await router.replace({ name: 'workout' })
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <GlassBackButton to="/workout" label="Back to workouts" />
    <h1 class="text-2xl font-semibold tracking-tight">{{ routineId ? 'Edit routine' : 'New routine' }}</h1>
    <form v-if="routines.draft" class="mt-5 flex flex-col gap-4" @submit.prevent="save">
      <label class="flex flex-col gap-1.5 text-sm">
        Title
        <input v-model="routines.draft.title" class="field" />
      </label>
      <label class="flex flex-col gap-1.5 text-sm">
        Description
        <textarea v-model="routines.draft.description" rows="2" class="field" />
      </label>

      <ol class="flex flex-col gap-2">
        <li
          v-for="(item, index) in routines.draft.exercises"
          :key="item.exerciseId"
          class="rounded-2xl border border-zinc-800 px-4 py-3"
        >
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-sm font-medium">{{ index + 1 }}. {{ item.name }}</p>
              <p class="mt-1 text-xs text-zinc-400">{{ item.primaryMuscle }}</p>
            </div>
            <button type="button" class="text-xs text-red-500 hover:text-red-400" @click="routines.removeDraftExercise(index)">Remove</button>
          </div>
          <div class="mt-3 flex items-center gap-2 text-xs">
            <span class="text-zinc-400">Rest</span>
            <input v-model.number="item.restSeconds" type="number" min="0" max="999" class="field w-20 py-1.5" />
            <span class="text-zinc-500">sec</span>
            <button type="button" class="ml-auto text-zinc-300" @click="routines.moveDraftExercise(index, -1)">Up</button>
            <button type="button" class="text-zinc-300" @click="routines.moveDraftExercise(index, 1)">Down</button>
          </div>
        </li>
      </ol>

      <button type="button" class="rounded-2xl border border-dashed border-zinc-700 py-3 text-sm" @click="addExercise">
        Add exercise
      </button>
      <p v-if="errorMessage" class="text-sm text-red-500">{{ errorMessage }}</p>
      <button type="submit" class="rounded-2xl bg-blue-600 py-3 text-sm font-semibold" :disabled="saving">
        {{ saving ? 'Saving…' : 'Save routine' }}
      </button>
    </form>
    <p v-else class="mt-6 text-sm text-zinc-500">Loading…</p>
  </section>
</template>

<style scoped>
.field {
  width: 100%;
  border-radius: 0.75rem;
  border: 1px solid #27272a;
  background: #18181b;
  padding: 0.7rem 0.75rem;
  outline: none;
}
.field:focus {
  border-color: #3b82f6;
}
</style>
