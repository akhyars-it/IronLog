<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ExerciseFormModal from '../components/ExerciseFormModal.vue'
import { EQUIPMENT, MUSCLES, useExerciseStore } from '../stores/exerciseStore'
import type { Equipment, Exercise, PrimaryMuscle } from '../types/database'

const route = useRoute()
const router = useRouter()
const store = useExerciseStore()
const selecting = route.query.select === '1'
const search = ref('')
const muscle = ref<PrimaryMuscle | ''>('')
const equipment = ref<Equipment | ''>('')
const formExercise = ref<Exercise | null>(null)
const formOpen = ref(false)
const actionError = ref('')

onMounted(() => {
  void store.load()
})

onUnmounted(() => {
  if (selecting) store.finishSelection(null)
})

function matches(exercise: Exercise): boolean {
  const query = search.value.trim().toLowerCase()
  if (query && !exercise.name.toLowerCase().includes(query)) return false
  if (muscle.value && exercise.primary_muscle !== muscle.value) return false
  if (equipment.value && exercise.equipment !== equipment.value) return false
  return true
}

const recent = computed(() =>
  store.recentIds
    .map((id) => store.exercises.find((exercise) => exercise.id === id))
    .filter((exercise): exercise is Exercise => exercise != null)
    .filter(matches),
)
const custom = computed(() => store.exercises.filter((exercise) => exercise.is_custom && matches(exercise)))
const library = computed(() => store.exercises.filter((exercise) => !exercise.is_custom && matches(exercise)))

function openCreate() {
  formExercise.value = null
  formOpen.value = true
}

function openEdit(exercise: Exercise) {
  formExercise.value = exercise
  formOpen.value = true
}

async function choose(exercise: Exercise) {
  if (selecting) {
    store.finishSelection(exercise)
    await router.back()
    return
  }
  await router.push({ name: 'exercise', params: { id: exercise.id } })
}

async function remove(exercise: Exercise) {
  if (!window.confirm(`Delete ${exercise.name}?`)) return
  actionError.value = (await store.remove(exercise)) ?? ''
}

async function cancelSelection() {
  store.finishSelection(null)
  await router.back()
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <div class="flex items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">{{ selecting ? 'Add exercise' : 'Exercises' }}</h1>
        <p class="mt-1 text-sm text-zinc-400">
          {{ selecting ? 'Tap an exercise to add it.' : 'Search the catalog or add your own.' }}
        </p>
      </div>
      <button v-if="selecting" type="button" class="text-sm text-zinc-400" @click="cancelSelection">Cancel</button>
      <button v-else type="button" class="rounded-full bg-blue-600 px-3 py-1.5 text-xs font-semibold" @click="openCreate">
        New
      </button>
    </div>

    <input v-model="search" class="field mt-5" placeholder="Search" />
    <div class="mt-3 grid grid-cols-2 gap-2">
      <select v-model="muscle" class="field">
        <option value="">All muscles</option>
        <option v-for="item in MUSCLES" :key="item" :value="item">{{ item }}</option>
      </select>
      <select v-model="equipment" class="field">
        <option value="">All equipment</option>
        <option v-for="item in EQUIPMENT" :key="item" :value="item">{{ item }}</option>
      </select>
    </div>
    <p v-if="store.error || actionError" class="mt-3 text-sm text-red-500">{{ actionError || store.error }}</p>
    <p v-if="store.loading" class="mt-6 text-sm text-zinc-500">Loading…</p>

    <template v-else>
      <section v-if="recent.length" class="mt-6">
        <h2 class="text-xs font-semibold tracking-[0.16em] text-zinc-500">RECENT</h2>
        <ul class="mt-2 flex flex-col gap-2">
          <li v-for="exercise in recent" :key="`recent-${exercise.id}`" class="rounded-2xl border border-zinc-800 bg-zinc-900/70">
            <button type="button" class="w-full px-4 py-3 text-left" @click="choose(exercise)">
              <p class="font-medium">{{ exercise.name }}</p>
              <p class="mt-1 text-xs text-zinc-400">{{ exercise.primary_muscle }} · {{ exercise.equipment }}</p>
            </button>
          </li>
        </ul>
      </section>

      <section v-if="custom.length" class="mt-6">
        <h2 class="text-xs font-semibold tracking-[0.16em] text-zinc-500">YOUR EXERCISES</h2>
        <ul class="mt-2 flex flex-col gap-2">
          <li v-for="exercise in custom" :key="exercise.id" class="rounded-2xl border border-zinc-800 bg-zinc-900/70">
            <button type="button" class="w-full px-4 py-3 text-left" @click="choose(exercise)">
              <p class="font-medium">{{ exercise.name }}</p>
              <p class="mt-1 text-xs text-zinc-400">{{ exercise.primary_muscle }} · {{ exercise.equipment }}</p>
            </button>
            <div class="flex gap-3 px-4 pb-3 text-xs">
              <button type="button" class="text-blue-300" @click="openEdit(exercise)">Edit</button>
              <button type="button" class="text-red-500 hover:text-red-400" @click="remove(exercise)">Delete</button>
            </div>
          </li>
        </ul>
      </section>

      <section class="mt-6">
        <h2 class="text-xs font-semibold tracking-[0.16em] text-zinc-500">ALL</h2>
        <p v-if="library.length === 0" class="mt-3 text-sm text-zinc-500">No exercises match.</p>
        <ul class="mt-2 flex flex-col gap-2">
          <li v-for="exercise in library" :key="exercise.id" class="rounded-2xl border border-zinc-800 bg-zinc-900/70">
            <button type="button" class="w-full px-4 py-3 text-left" @click="choose(exercise)">
              <p class="font-medium">{{ exercise.name }}</p>
              <p class="mt-1 text-xs text-zinc-400">{{ exercise.primary_muscle }} · {{ exercise.equipment }}</p>
            </button>
          </li>
        </ul>
      </section>
    </template>

    <ExerciseFormModal v-if="formOpen" :exercise="formExercise" @close="formOpen = false" @saved="store.load()" />
  </section>
</template>

<style scoped>
.field {
  width: 100%;
  border-radius: 0.75rem;
  border: 1px solid #27272a;
  background: #18181b;
  padding: 0.7rem 0.75rem;
  font-size: 0.875rem;
  outline: none;
}
.field:focus {
  border-color: #3b82f6;
}
</style>
