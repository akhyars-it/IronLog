import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './authStore'
import type { Exercise, ExerciseCategory, ExerciseType, PrimaryMuscle } from '../types/database'
import { asNumber, firstOf } from '../utils/coerce'
import { friendlyError } from '../utils/errorHandler'

export interface RoutineExerciseItem {
  id: string
  exerciseId: string
  orderIndex: number
  restSeconds: number
  exercise: Exercise
}

export interface RoutineDetail {
  id: string
  title: string
  description: string | null
  exercises: RoutineExerciseItem[]
}

export interface RoutineDraftExercise {
  exerciseId: string
  name: string
  primaryMuscle: PrimaryMuscle
  exerciseType: ExerciseType
  category: ExerciseCategory
  restSeconds: number
}

export interface RoutineDraft {
  routineId: string | null
  title: string
  description: string
  exercises: RoutineDraftExercise[]
}

export interface VolumePoint {
  label: string
  volume: number
}

interface RoutineExerciseRow {
  id: string
  exercise_id: string
  order_index: number
  rest_seconds: number
  exercises: Exercise | Exercise[] | null
}

interface RoutineRow {
  id: string
  title: string
  description: string | null
  routine_exercises: RoutineExerciseRow[] | null
}

function mapRoutine(row: RoutineRow): RoutineDetail {
  const exercises = (row.routine_exercises ?? [])
    .map((item) => {
      const exercise = firstOf(item.exercises)
      if (!exercise) return null
      return {
        id: item.id,
        exerciseId: item.exercise_id,
        orderIndex: item.order_index,
        restSeconds: item.rest_seconds ?? 180,
        exercise,
      }
    })
    .filter((item): item is RoutineExerciseItem => item != null)
    .sort((a, b) => a.orderIndex - b.orderIndex)
  return { id: row.id, title: row.title, description: row.description, exercises }
}

const routineSelect = `
  id, title, description,
  routine_exercises (
    id, exercise_id, order_index, rest_seconds,
    exercises (*)
  )
`

export const useRoutineStore = defineStore('routines', () => {
  const auth = useAuthStore()
  const routines = ref<RoutineDetail[]>([])
  const draft = ref<RoutineDraft | null>(null)
  const loading = ref(false)
  const error = ref('')

  function clearDraft() {
    draft.value = null
  }

  function blankDraft(): RoutineDraft {
    return { routineId: null, title: '', description: '', exercises: [] }
  }

  async function load() {
    const userId = auth.user?.id
    if (!userId) {
      routines.value = []
      return
    }
    loading.value = true
    error.value = ''
    const { data, error: queryError } = await supabase
      .from('routines')
      .select(routineSelect)
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    loading.value = false
    if (queryError) {
      error.value = friendlyError(queryError)
      return
    }
    routines.value = ((data ?? []) as unknown as RoutineRow[]).map(mapRoutine)
  }

  async function ensureDraft(routineId: string | null) {
    if (draft.value && draft.value.routineId === routineId) return
    if (!routineId) {
      draft.value = blankDraft()
      return
    }
    const userId = auth.user?.id
    if (!userId) return
    const { data, error: queryError } = await supabase
      .from('routines')
      .select(routineSelect)
      .eq('id', routineId)
      .eq('user_id', userId)
      .maybeSingle()
    if (queryError || !data) {
      error.value = queryError ? friendlyError(queryError) : 'Routine not found.'
      draft.value = blankDraft()
      return
    }
    const routine = mapRoutine(data as unknown as RoutineRow)
    draft.value = {
      routineId: routine.id,
      title: routine.title,
      description: routine.description ?? '',
      exercises: routine.exercises.map((item) => ({
        exerciseId: item.exercise.id,
        name: item.exercise.name,
        primaryMuscle: item.exercise.primary_muscle,
        exerciseType: item.exercise.exercise_type,
        category: item.exercise.category,
        restSeconds: item.restSeconds,
      })),
    }
  }

  function addDraftExercise(exercise: Exercise) {
    if (!draft.value) draft.value = blankDraft()
    if (draft.value.exercises.some((item) => item.exerciseId === exercise.id)) return
    draft.value.exercises.push({
      exerciseId: exercise.id,
      name: exercise.name,
      primaryMuscle: exercise.primary_muscle,
      exerciseType: exercise.exercise_type,
      category: exercise.category,
      restSeconds: 180,
    })
  }

  function moveDraftExercise(index: number, delta: number) {
    const current = draft.value
    if (!current) return
    const next = index + delta
    if (next < 0 || next >= current.exercises.length) return
    const [item] = current.exercises.splice(index, 1)
    if (!item) return
    current.exercises.splice(next, 0, item)
  }

  function removeDraftExercise(index: number) {
    draft.value?.exercises.splice(index, 1)
  }

  async function saveDraft(): Promise<string | null> {
    const userId = auth.user?.id
    const current = draft.value
    if (!userId || !current) return 'You need to be signed in.'
    const title = current.title.trim()
    if (!title) return 'Title is required.'
    if (current.exercises.length === 0) return 'Add at least one exercise.'

    let routineId = current.routineId
    if (routineId) {
      const { error: updateError } = await supabase
        .from('routines')
        .update({ title, description: current.description.trim() || null })
        .eq('id', routineId)
        .eq('user_id', userId)
      if (updateError) return friendlyError(updateError)
      const { error: deleteError } = await supabase.from('routine_exercises').delete().eq('routine_id', routineId)
      if (deleteError) return friendlyError(deleteError)
    } else {
      const { data, error: insertError } = await supabase
        .from('routines')
        .insert({ user_id: userId, title, description: current.description.trim() || null })
        .select('id')
        .single()
      if (insertError) return friendlyError(insertError)
      routineId = (data as { id: string }).id
    }

    const rows = current.exercises.map((item, index) => ({
      routine_id: routineId,
      exercise_id: item.exerciseId,
      order_index: index,
      rest_seconds: Math.min(999, Math.max(0, Math.round(item.restSeconds) || 0)),
    }))
    const { error: childError } = await supabase.from('routine_exercises').insert(rows)
    if (childError) return friendlyError(childError)
    draft.value = null
    await load()
    return null
  }

  async function remove(routineId: string): Promise<string | null> {
    const { error: deleteError } = await supabase.from('routines').delete().eq('id', routineId)
    if (deleteError) return friendlyError(deleteError)
    routines.value = routines.value.filter((item) => item.id !== routineId)
    return null
  }

  async function volumeHistory(routineId: string): Promise<VolumePoint[]> {
    const userId = auth.user?.id
    if (!userId) return []
    const { data, error: queryError } = await supabase
      .from('workouts')
      .select('total_volume, start_time')
      .eq('user_id', userId)
      .eq('routine_id', routineId)
      .order('start_time', { ascending: false })
      .limit(10)
    if (queryError || !data) return []
    return (data as { total_volume: unknown; start_time: string }[])
      .slice()
      .reverse()
      .map((row) => {
        const when = new Date(row.start_time)
        return {
          label: Number.isNaN(when.getTime())
            ? ''
            : when.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
          volume: asNumber(row.total_volume),
        }
      })
  }

  function reset() {
    routines.value = []
    draft.value = null
    loading.value = false
    error.value = ''
  }

  return {
    routines,
    draft,
    loading,
    error,
    load,
    clearDraft,
    ensureDraft,
    addDraftExercise,
    moveDraftExercise,
    removeDraftExercise,
    saveDraft,
    remove,
    volumeHistory,
    reset,
  }
})
