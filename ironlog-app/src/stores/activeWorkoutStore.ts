import confetti from 'canvas-confetti'
import { impactHeavy } from '../lib/haptics'
import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './authStore'
import type { Exercise, ExerciseType, PrimaryMuscle } from '../types/database'
import { asNumber } from '../utils/coerce'
import { friendlyError } from '../utils/errorHandler'
import { calculateSetVolume } from '../utils/fitnessMath'

const STORAGE_KEY = 'ironlog.activeWorkout.v1'

export interface PreviousSet {
  weight: number
  reps: number
  durationSeconds: number | null
}

export interface ActiveSet {
  id: string
  weight: string
  reps: string
  durationSeconds: string
  done: boolean
}

export interface ActiveExercise {
  localId: string
  exerciseId: string
  name: string
  exerciseType: ExerciseType
  primaryMuscle: PrimaryMuscle
  restSeconds: number
  notes: string
  sets: ActiveSet[]
  previous: PreviousSet[]
  baseMax: number
  maxWeight: number
}

export interface ActiveSession {
  userId: string
  routineId: string | null
  routineName: string
  startTime: string
  summaryNotes: string
  exercises: ActiveExercise[]
  restEndsAt: number | null
  restMax: number
  restExerciseId: string | null
}

export interface StartExercise {
  exercise: Exercise
  restSeconds: number
}

function emptySet(seed?: ActiveSet): ActiveSet {
  return {
    id: crypto.randomUUID(),
    weight: seed?.weight ?? '',
    reps: seed?.reps ?? '',
    durationSeconds: seed?.durationSeconds ?? '',
    done: false,
  }
}

function readSession(): ActiveSession | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as ActiveSession
    if (!parsed || typeof parsed.startTime !== 'string' || !Array.isArray(parsed.exercises)) return null
    if (parsed.restEndsAt != null && parsed.restEndsAt <= Date.now()) {
      parsed.restEndsAt = null
      parsed.restExerciseId = null
    }
    return parsed
  } catch {
    return null
  }
}

function celebrate() {
  void impactHeavy()
  void confetti({
    particleCount: 90,
    spread: 70,
    origin: { y: 0.65 },
    colors: ['#3b82f6', '#fb923c', '#ffffff'],
  })
}

async function loadHistory(userId: string, exerciseId: string): Promise<{ previous: PreviousSet[]; maxWeight: number }> {
  const latest = await supabase
    .from('set_logs')
    .select('workout_id')
    .eq('user_id', userId)
    .eq('exercise_id', exerciseId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  let previous: PreviousSet[] = []
  const workoutId = (latest.data as { workout_id?: string } | null)?.workout_id
  if (workoutId) {
    const sets = await supabase
      .from('set_logs')
      .select('weight, reps, duration_seconds, set_index')
      .eq('user_id', userId)
      .eq('exercise_id', exerciseId)
      .eq('workout_id', workoutId)
      .order('set_index', { ascending: true })
    previous = ((sets.data ?? []) as { weight: unknown; reps: unknown; duration_seconds: number | null }[]).map((row) => ({
      weight: asNumber(row.weight),
      reps: asNumber(row.reps),
      durationSeconds: row.duration_seconds,
    }))
  }

  const maxRow = await supabase
    .from('set_logs')
    .select('weight')
    .eq('user_id', userId)
    .eq('exercise_id', exerciseId)
    .order('weight', { ascending: false })
    .limit(1)
    .maybeSingle()

  return { previous, maxWeight: asNumber((maxRow.data as { weight?: unknown } | null)?.weight) }
}

function setsFromPrevious(previous: PreviousSet[], exerciseType: ExerciseType): ActiveSet[] {
  if (previous.length === 0) return [emptySet()]
  return previous.map((set) =>
    emptySet({
      id: '',
      weight: exerciseType === 'reps_and_weight' ? String(set.weight) : '',
      reps: exerciseType === 'duration' ? '' : String(set.reps),
      durationSeconds: exerciseType === 'duration' && set.durationSeconds != null ? String(set.durationSeconds) : '',
      done: false,
    }),
  )
}

export const useActiveWorkoutStore = defineStore('activeWorkout', () => {
  const auth = useAuthStore()
  const workout = ref<ActiveSession | null>(readSession())
  const now = ref(Date.now())

  watch(
    workout,
    (value) => {
      if (value) localStorage.setItem(STORAGE_KEY, JSON.stringify(value))
      else localStorage.removeItem(STORAGE_KEY)
    },
    { deep: true },
  )

  if (typeof window !== 'undefined') {
    window.setInterval(() => {
      now.value = Date.now()
      const session = workout.value
      if (session?.restEndsAt && session.restEndsAt <= Date.now()) {
        session.restEndsAt = null
        session.restExerciseId = null
        void impactHeavy()
      }
    }, 1000)
  }

  const elapsedSeconds = computed(() => {
    const session = workout.value
    if (!session) return 0
    now.value
    const start = Date.parse(session.startTime)
    if (Number.isNaN(start)) return 0
    return Math.max(0, Math.floor((Date.now() - start) / 1000))
  })

  const restRemaining = computed(() => {
    const session = workout.value
    now.value
    if (!session?.restEndsAt) return 0
    return Math.min(999, Math.max(0, Math.ceil((session.restEndsAt - Date.now()) / 1000)))
  })

  const restProgress = computed(() => {
    const session = workout.value
    if (!session?.restMax || restRemaining.value <= 0) return 0
    return Math.min(1, restRemaining.value / session.restMax)
  })

  const stats = computed(() => {
    let sets = 0
    let volume = 0
    for (const exercise of workout.value?.exercises ?? []) {
      for (const set of exercise.sets) {
        if (!set.done) continue
        sets += 1
        const weight = Number(set.weight)
        const reps = Number(set.reps)
        volume += calculateSetVolume(Number.isFinite(weight) ? weight : 0, Number.isFinite(reps) ? reps : 0)
      }
    }
    return { sets, volume }
  })

  function adopt(userId: string) {
    if (workout.value && workout.value.userId !== userId) workout.value = null
  }

  function clear() {
    workout.value = null
  }

  async function hydrateExercise(userId: string, exercise: Exercise, restSeconds: number): Promise<ActiveExercise> {
    const history = await loadHistory(userId, exercise.id)
    return {
      localId: crypto.randomUUID(),
      exerciseId: exercise.id,
      name: exercise.name,
      exerciseType: exercise.exercise_type,
      primaryMuscle: exercise.primary_muscle,
      restSeconds: Math.min(999, Math.max(0, Math.round(restSeconds) || 180)),
      notes: '',
      sets: setsFromPrevious(history.previous, exercise.exercise_type),
      previous: history.previous,
      baseMax: history.maxWeight,
      maxWeight: history.maxWeight,
    }
  }

  async function begin(input: {
    routineId: string | null
    routineName: string
    items: StartExercise[]
  }): Promise<string | null> {
    const userId = auth.user?.id
    if (!userId) return 'You need to be signed in.'
    const exercises = await Promise.all(
      input.items.map((item) => hydrateExercise(userId, item.exercise, item.restSeconds || 180)),
    )
    workout.value = {
      userId,
      routineId: input.routineId,
      routineName: input.routineName,
      startTime: new Date().toISOString(),
      summaryNotes: '',
      exercises,
      restEndsAt: null,
      restMax: 0,
      restExerciseId: null,
    }
    return null
  }

  async function addExercise(exercise: Exercise): Promise<string | null> {
    const session = workout.value
    const userId = auth.user?.id
    if (!session || !userId) return 'Start a workout first.'
    if (session.exercises.some((item) => item.exerciseId === exercise.id)) return 'That exercise is already in this workout.'
    session.exercises.push(await hydrateExercise(userId, exercise, 180))
    return null
  }

  async function replaceExercise(localId: string, exercise: Exercise): Promise<string | null> {
    const session = workout.value
    const userId = auth.user?.id
    if (!session || !userId) return 'Start a workout first.'
    const index = session.exercises.findIndex((item) => item.localId === localId)
    if (index < 0) return null
    if (session.exercises.some((item) => item.exerciseId === exercise.id && item.localId !== localId)) {
      return 'That exercise is already in this workout.'
    }
    const rest = session.exercises[index]?.restSeconds ?? 180
    const next = await hydrateExercise(userId, exercise, rest)
    session.exercises.splice(index, 1, next)
    if (session.restExerciseId === localId) {
      session.restEndsAt = null
      session.restExerciseId = null
    }
    return null
  }

  function removeExercise(localId: string) {
    const session = workout.value
    if (!session) return
    session.exercises = session.exercises.filter((item) => item.localId !== localId)
    if (session.restExerciseId === localId) {
      session.restEndsAt = null
      session.restExerciseId = null
    }
  }

  function addSet(localId: string) {
    const exercise = workout.value?.exercises.find((item) => item.localId === localId)
    if (!exercise) return
    const last = exercise.sets[exercise.sets.length - 1]
    exercise.sets.push(emptySet(last))
  }

  function removeSet(localId: string, setId: string) {
    const exercise = workout.value?.exercises.find((item) => item.localId === localId)
    if (!exercise) return
    exercise.sets = exercise.sets.filter((set) => set.id !== setId)
    recomputeMax(exercise)
  }

  function recomputeMax(exercise: ActiveExercise) {
    let max = exercise.baseMax
    for (const set of exercise.sets) {
      if (!set.done) continue
      const weight = Number(set.weight)
      if (Number.isFinite(weight) && weight > max) max = weight
    }
    exercise.maxWeight = max
  }

  function startRest(exercise: ActiveExercise) {
    const session = workout.value
    if (!session) return
    const seconds = Math.min(999, Math.max(0, Math.round(exercise.restSeconds)))
    if (seconds <= 0) {
      session.restEndsAt = null
      session.restMax = 0
      session.restExerciseId = null
      return
    }
    session.restMax = seconds
    session.restEndsAt = Date.now() + seconds * 1000
    session.restExerciseId = exercise.localId
  }

  function toggleSet(localId: string, setId: string) {
    const exercise = workout.value?.exercises.find((item) => item.localId === localId)
    const set = exercise?.sets.find((item) => item.id === setId)
    if (!exercise || !set) return
    set.done = !set.done
    if (set.done) {
      const weight = Number(set.weight)
      const safe = Number.isFinite(weight) ? weight : 0
      if (safe > exercise.maxWeight) {
        exercise.maxWeight = safe
        celebrate()
      }
      startRest(exercise)
      return
    }
    recomputeMax(exercise)
    if (workout.value?.restExerciseId === localId) {
      workout.value.restEndsAt = null
      workout.value.restExerciseId = null
    }
  }

  function adjustExerciseRest(localId: string, delta: number) {
    const exercise = workout.value?.exercises.find((item) => item.localId === localId)
    if (!exercise) return
    exercise.restSeconds = Math.min(999, Math.max(0, exercise.restSeconds + delta))
  }

  function adjustRest(delta: number) {
    const session = workout.value
    if (!session?.restEndsAt) return
    const remaining = Math.max(0, Math.ceil((session.restEndsAt - Date.now()) / 1000))
    const next = Math.min(999, Math.max(0, remaining + delta))
    if (next === 0) {
      session.restEndsAt = null
      session.restExerciseId = null
      return
    }
    session.restEndsAt = Date.now() + next * 1000
  }

  function skipRest() {
    const session = workout.value
    if (!session) return
    session.restEndsAt = null
    session.restExerciseId = null
  }

  async function save(): Promise<string | null> {
    const session = workout.value
    if (!session) return 'No workout to save.'
    const payload = session.exercises.flatMap((exercise) =>
      exercise.sets.flatMap((set, index) => {
        if (!set.done) return []
        const weight = exercise.exerciseType === 'reps_and_weight' ? Number(set.weight) || 0 : 0
        const reps = exercise.exerciseType === 'duration' ? 0 : Math.round(Number(set.reps) || 0)
        const duration =
          exercise.exerciseType === 'duration' ? Math.round(Number(set.durationSeconds) || 0) : null
        return [
          {
            exercise_id: exercise.exerciseId,
            set_index: index + 1,
            weight: Number.isFinite(weight) && weight > 0 ? weight : 0,
            reps: Number.isFinite(reps) && reps > 0 ? reps : 0,
            duration_seconds: duration,
            exercise_notes: exercise.notes.trim() || null,
          },
        ]
      }),
    )
    if (payload.length === 0) return 'Check at least one set before finishing.'
    const start = new Date(session.startTime)
    const end = new Date()
    if (end < start) end.setTime(start.getTime())
    const { error } = await supabase.rpc('save_completed_workout', {
      p_routine_id: session.routineId,
      p_routine_name: session.routineName,
      p_start_time: start.toISOString(),
      p_end_time: end.toISOString(),
      p_duration_seconds: Math.max(0, Math.round((end.getTime() - start.getTime()) / 1000)),
      p_notes: session.summaryNotes.trim() || null,
      p_sets: payload,
    })
    if (error) return friendlyError(error)
    workout.value = null
    return null
  }

  return {
    workout,
    elapsedSeconds,
    restRemaining,
    restProgress,
    stats,
    adopt,
    clear,
    begin,
    addExercise,
    replaceExercise,
    removeExercise,
    addSet,
    removeSet,
    toggleSet,
    adjustExerciseRest,
    adjustRest,
    skipRest,
    save,
  }
})
