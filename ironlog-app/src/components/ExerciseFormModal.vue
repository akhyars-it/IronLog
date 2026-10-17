<script setup lang="ts">
import { reactive, ref } from 'vue'
import { CATEGORIES, EQUIPMENT, EXERCISE_TYPES, MUSCLES, useExerciseStore } from '../stores/exerciseStore'
import type { Exercise } from '../types/database'

const props = defineProps<{ exercise: Exercise | null }>()
const emit = defineEmits<{ close: []; saved: [] }>()
const store = useExerciseStore()
const saving = ref(false)
const errorMessage = ref('')

const form = reactive({
  name: props.exercise?.name ?? '',
  equipment: props.exercise?.equipment ?? 'Barbell',
  primaryMuscle: props.exercise?.primary_muscle ?? 'Chest',
  category: props.exercise?.category ?? 'other',
  exerciseType: props.exercise?.exercise_type ?? 'reps_and_weight',
})

async function submit() {
  saving.value = true
  errorMessage.value = ''
  const error = await store.save(form, props.exercise)
  saving.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  emit('saved')
  emit('close')
}
</script>

<template>
  <div class="fixed inset-0 z-40 flex items-end justify-center bg-black/70 p-4" @click.self="emit('close')">
    <form class="w-full max-w-md rounded-3xl border border-zinc-800 bg-zinc-950 p-5" @submit.prevent="submit">
      <h2 class="text-lg font-semibold">{{ exercise ? 'Edit exercise' : 'New exercise' }}</h2>
      <label class="mt-4 flex flex-col gap-1.5 text-sm">
        Name
        <input v-model="form.name" class="field" required />
      </label>
      <label class="mt-3 flex flex-col gap-1.5 text-sm">
        Muscle
        <select v-model="form.primaryMuscle" class="field">
          <option v-for="muscle in MUSCLES" :key="muscle" :value="muscle">{{ muscle }}</option>
        </select>
      </label>
      <label class="mt-3 flex flex-col gap-1.5 text-sm">
        Equipment
        <select v-model="form.equipment" class="field">
          <option v-for="item in EQUIPMENT" :key="item" :value="item">{{ item }}</option>
        </select>
      </label>
      <label class="mt-3 flex flex-col gap-1.5 text-sm">
        Category
        <select v-model="form.category" class="field">
          <option v-for="item in CATEGORIES" :key="item.value" :value="item.value">{{ item.label }}</option>
        </select>
      </label>
      <label class="mt-3 flex flex-col gap-1.5 text-sm">
        Tracking
        <select v-model="form.exerciseType" class="field">
          <option v-for="item in EXERCISE_TYPES" :key="item.value" :value="item.value">{{ item.label }}</option>
        </select>
      </label>
      <p v-if="errorMessage" class="mt-3 text-sm text-red-500">{{ errorMessage }}</p>
      <div class="mt-5 flex gap-2">
        <button type="button" class="flex-1 rounded-xl border border-zinc-700 py-3 text-sm" @click="emit('close')">
          Cancel
        </button>
        <button type="submit" class="flex-1 rounded-xl bg-blue-600 py-3 text-sm font-semibold" :disabled="saving">
          {{ saving ? 'Saving…' : 'Save' }}
        </button>
      </div>
    </form>
  </div>
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
