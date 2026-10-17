import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './authStore'
import type {
  Equipment,
  Exercise,
  ExerciseCategory,
  ExerciseType,
  PrimaryMuscle,
} from '../types/database'
import { asNumber } from '../utils/coerce'
import { friendlyError } from '../utils/errorHandler'
import { calculateBrzycki1RM, calculateSetVolume } from '../utils/fitnessMath'

export const MUSCLES: PrimaryMuscle[] = [
  'Chest',
  'Back',
  'Shoulders',
  'Legs',
  'Arms',
  'Core',
  'Cardio',
]

export const EQUIPMENT: Equipment[] = [
  'Dumbbell',
  'Barbell',
  'Machine',
  'Cable',
  'Bodyweight',
  'Kettlebell',
]

export const CATEGORIES: { value: ExerciseCategory; label: string }[] = [
  { value: 'bench', label: 'Bench' },
  { value: 'squat', label: 'Squat' },
  { value: 'deadlift', label: 'Deadlift' },
  { value: 'overhead_press', label: 'Overhead press' },
  { value: 'row', label: 'Row' },
  { value: 'pull', label: 'Pull' },
  { value: 'push', label: 'Push' },
  { value: 'other', label: 'Other' },
]

export const EXERCISE_TYPES: { value: ExerciseType; label: string }[] = [
  { value: 'reps_and_weight', label: 'Reps & weight' },
  { value: 'bodyweight_reps', label: 'Bodyweight reps' },
  { value: 'duration', label: 'Duration' },
]

export interface ExerciseDraft {
  name: string
  equipment: Equipment
  primaryMuscle: PrimaryMuscle
  category: ExerciseCategory
  exerciseType: ExerciseType
}

export interface SessionPoint {
  label: string
  weight: number
}

export interface ExercisePerformance {
  heaviest: number
  bestBrzycki: number | null
  bestSessionVolume: number
  sessions: SessionPoint[]
}

let resolvePick: ((exercise: Exercise | null) => void) | null = null

export const useExerciseStore = defineStore('exercises', () => {
  const auth = useAuthStore()
  const exercises = ref<Exercise[]>([])
  const recentIds = ref<string[]>([])
  const loading = ref(false)
  const error = ref('')

  async function load() {
    const userId = auth.user?.id
    if (!userId) {
      exercises.value = []
      recentIds.value = []
      return
    }
    loading.value = true
    error.value = ''
    const [catalog, recent] = await Promise.all([
      supabase.from('exercises').select('*').order('name', { ascending: true }),
      supabase
        .from('set_logs')
        .select('exercise_id')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(50),
    ])
    loading.value = false
    if (catalog.error) {
      error.value = friendlyError(catalog.error)
      return
    }
    exercises.value = ((catalog.data ?? []) as Exercise[]).slice().sort((a, b) => a.name.localeCompare(b.name))
    const ids: string[] = []
    for (const row of (recent.data ?? []) as { exercise_id: string }[]) {
      if (!ids.includes(row.exercise_id)) ids.push(row.exercise_id)
    }
    recentIds.value = ids
  }

  function armSelection(): Promise<Exercise | null> {
    resolvePick?.(null)
    return new Promise((resolve) => {
      resolvePick = resolve
    })
  }

  function finishSelection(exercise: Exercise | null) {
    const resolve = resolvePick
    resolvePick = null
    resolve?.(exercise)
  }

  async function save(draft: ExerciseDraft, existing: Exercise | null): Promise<string | null> {
    const userId = auth.user?.id
    if (!userId) return 'You need to be signed in.'
    const name = draft.name.trim()
    if (!name) return 'Name is required.'
    const payload = {
      name,
      equipment: draft.equipment,
      primary_muscle: draft.primaryMuscle,
      category: draft.category,
      exercise_type: draft.exerciseType,
    }
    if (existing) {
      const { data, error: updateError } = await supabase
        .from('exercises')
        .update(payload)
        .eq('id', existing.id)
        .select('*')
        .single()
      if (updateError) return friendlyError(updateError)
      const next = data as Exercise
      exercises.value = exercises.value.map((item) => (item.id === next.id ? next : item))
      return null
    }
    const { data, error: insertError } = await supabase
      .from('exercises')
      .insert({ ...payload, user_id: userId, is_custom: true })
      .select('*')
      .single()
    if (insertError) return friendlyError(insertError)
    exercises.value = [...exercises.value, data as Exercise].sort((a, b) => a.name.localeCompare(b.name))
    return null
  }

  async function remove(exercise: Exercise): Promise<string | null> {
    const { error: deleteError } = await supabase.from('exercises').delete().eq('id', exercise.id)
    if (deleteError) {
      if (deleteError.code === '23503') {
        return 'This exercise is used in a workout and cannot be deleted.'
      }
      return friendlyError(deleteError)
    }
    exercises.value = exercises.value.filter((item) => item.id !== exercise.id)
    recentIds.value = recentIds.value.filter((id) => id !== exercise.id)
    return null
  }

  async function loadPerformance(exerciseId: string): Promise<ExercisePerformance> {
    const empty: ExercisePerformance = { heaviest: 0, bestBrzycki: null, bestSessionVolume: 0, sessions: [] }
    const userId = auth.user?.id
    if (!userId) return empty
    const { data, error: queryError } = await supabase
      .from('set_logs')
      .select('weight, reps, workout_id, created_at')
      .eq('user_id', userId)
      .eq('exercise_id', exerciseId)
      .order('created_at', { ascending: true })
    if (queryError || !data) return empty

    const sessions = new Map<string, { at: string; weight: number; volume: number }>()
    let heaviest = 0
    let bestBrzycki: number | null = null
    for (const row of data as { weight: unknown; reps: unknown; workout_id: string; created_at: string }[]) {
      const weight = asNumber(row.weight)
      const reps = asNumber(row.reps)
      if (weight > heaviest) heaviest = weight
      const brzycki = calculateBrzycki1RM(weight, reps)
      if (brzycki != null && (bestBrzycki == null || brzycki > bestBrzycki)) bestBrzycki = brzycki
      const current = sessions.get(row.workout_id) ?? { at: row.created_at, weight: 0, volume: 0 }
      current.volume += calculateSetVolume(weight, reps)
      if (weight > current.weight) current.weight = weight
      sessions.set(row.workout_id, current)
    }

    let bestSessionVolume = 0
    const points: SessionPoint[] = []
    for (const session of sessions.values()) {
      if (session.volume > bestSessionVolume) bestSessionVolume = session.volume
      const when = new Date(session.at)
      points.push({
        label: Number.isNaN(when.getTime())
          ? ''
          : when.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
        weight: session.weight,
      })
    }
    return { heaviest, bestBrzycki, bestSessionVolume, sessions: points }
  }

  function reset() {
    exercises.value = []
    recentIds.value = []
    loading.value = false
    error.value = ''
  }

  return {
    exercises,
    recentIds,
    loading,
    error,
    load,
    armSelection,
    finishSelection,
    save,
    remove,
    loadPerformance,
    reset,
  }
})
