import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from './authStore'
import type { ExerciseCategory, ExerciseType, PrimaryMuscle, Workout } from '../types/database'
import type { HistorySet, HistoryWorkout, PersonalRecord, WorkoutSummary } from '../types/history'
import { asNumber, firstOf } from '../utils/coerce'
import { friendlyError } from '../utils/errorHandler'
import { calculateEpley1RM } from '../utils/fitnessMath'

export interface MuscleSet {
  startTime: string
  muscle: PrimaryMuscle
}

export interface BenchSnapshot {
  ratio: number
  weight: number
  source: 'recent' | 'all-time'
}

const workoutColumns = `
  id, user_id, routine_id, routine_name, start_time, end_time, duration_seconds,
  total_volume, total_sets, records_broken, notes, status, created_at
`

const setColumns = `
  id, exercise_id, set_index, weight, reps, duration_seconds, exercise_notes, is_pr, created_at,
  exercises ( name, primary_muscle, category, exercise_type )
`

interface RawExercise {
  name: string
  primary_muscle: PrimaryMuscle
  category: ExerciseCategory
  exercise_type: ExerciseType
}

interface RawSet {
  id: string
  exercise_id: string
  set_index: number
  weight: unknown
  reps: unknown
  duration_seconds: number | null
  exercise_notes: string | null
  is_pr: boolean | null
  created_at: string
  exercises: RawExercise | RawExercise[] | null
}

interface RawWorkout {
  id: string
  user_id: string
  routine_id: string | null
  routine_name: string
  start_time: string
  end_time: string
  duration_seconds: unknown
  total_volume: unknown
  total_sets: unknown
  records_broken: unknown
  notes: string | null
  status: Workout['status']
  created_at: string
  set_logs?: RawSet[] | null
}

function mapSet(row: RawSet): HistorySet {
  const exercise = firstOf(row.exercises)
  return {
    id: row.id,
    exercise_id: row.exercise_id,
    set_index: row.set_index,
    weight: asNumber(row.weight),
    reps: asNumber(row.reps),
    duration_seconds: row.duration_seconds,
    exercise_notes: row.exercise_notes,
    is_pr: row.is_pr === true,
    created_at: row.created_at,
    name: exercise?.name ?? 'Exercise',
    primary_muscle: exercise?.primary_muscle ?? 'Core',
    category: exercise?.category ?? 'other',
    exercise_type: exercise?.exercise_type ?? 'reps_and_weight',
  }
}

function mapWorkout(row: RawWorkout): HistoryWorkout {
  return {
    ...row,
    total_volume: asNumber(row.total_volume),
    total_sets: asNumber(row.total_sets),
    records_broken: asNumber(row.records_broken),
    duration_seconds: asNumber(row.duration_seconds),
    sets: (row.set_logs ?? []).map(mapSet),
  }
}

function mapSummary(row: RawWorkout): WorkoutSummary {
  return {
    id: row.id,
    routine_name: row.routine_name,
    start_time: row.start_time,
    end_time: row.end_time,
    duration_seconds: asNumber(row.duration_seconds),
    total_volume: asNumber(row.total_volume),
    total_sets: asNumber(row.total_sets),
    records_broken: asNumber(row.records_broken),
  }
}

export const useHistoryStore = defineStore('history', () => {
  const auth = useAuthStore()
  const recent = ref<HistoryWorkout[]>([])
  const catalog = ref<WorkoutSummary[]>([])
  const benchRatio = ref<BenchSnapshot | null>(null)
  const records = ref<PersonalRecord[]>([])
  const muscleSets = ref<MuscleSet[]>([])
  const loading = ref(false)
  const error = ref('')

  async function loadRecent() {
    const userId = auth.user?.id
    if (!userId) {
      recent.value = []
      benchRatio.value = null
      return
    }
    loading.value = true
    error.value = ''
    const since = new Date()
    since.setDate(since.getDate() - 96)
    const { data, error: queryError } = await supabase
      .from('workouts')
      .select(`${workoutColumns}, set_logs (${setColumns})`)
      .eq('user_id', userId)
      .gte('start_time', since.toISOString())
      .order('start_time', { ascending: false })
    loading.value = false
    if (queryError) {
      error.value = friendlyError(queryError)
      return
    }
    recent.value = ((data ?? []) as unknown as RawWorkout[]).map(mapWorkout)
    benchRatio.value = await loadBenchRatio(userId, auth.profile?.current_weight ?? null)
  }

  async function heaviestBench(userId: string, workoutId?: string): Promise<number> {
    let query = supabase
      .from('set_logs')
      .select('weight, exercises!inner(category)')
      .eq('user_id', userId)
      .eq('exercises.category', 'bench')
      .order('weight', { ascending: false })
      .limit(1)
    if (workoutId) query = query.eq('workout_id', workoutId)
    const { data } = await query.maybeSingle()
    return asNumber((data as { weight?: unknown } | null)?.weight)
  }

  async function loadBenchRatio(userId: string, bodyWeight: number | null): Promise<BenchSnapshot | null> {
    if (!(bodyWeight && bodyWeight > 0)) return null
    const recent = await supabase
      .from('set_logs')
      .select('workout_id, exercises!inner(category), workouts!inner(start_time)')
      .eq('user_id', userId)
      .eq('exercises.category', 'bench')
      .order('start_time', { referencedTable: 'workouts', ascending: false })
      .limit(1)
      .maybeSingle()
    const workoutId = (recent.data as { workout_id?: string } | null)?.workout_id
    const recentWeight = workoutId ? await heaviestBench(userId, workoutId) : 0
    if (recentWeight > 0) return { ratio: recentWeight / bodyWeight, weight: recentWeight, source: 'recent' }
    const allTime = await heaviestBench(userId)
    if (!(allTime > 0)) return null
    return { ratio: allTime / bodyWeight, weight: allTime, source: 'all-time' }
  }

  async function loadWorkout(id: string): Promise<HistoryWorkout | null> {
    const userId = auth.user?.id
    if (!userId) return null
    const { data, error: queryError } = await supabase
      .from('workouts')
      .select(`${workoutColumns}, set_logs (${setColumns})`)
      .eq('id', id)
      .eq('user_id', userId)
      .maybeSingle()
    if (queryError || !data) {
      error.value = queryError ? friendlyError(queryError) : 'Workout not found.'
      return null
    }
    return mapWorkout(data as unknown as RawWorkout)
  }

  async function updateTimes(id: string, start: Date, end: Date): Promise<string | null> {
    const userId = auth.user?.id
    if (!userId) return 'You need to be signed in.'
    let finish = end
    if (finish.getTime() <= start.getTime()) finish = new Date(finish.getTime() + 86_400_000)
    const duration = Math.round((finish.getTime() - start.getTime()) / 1000)
    const { error: updateError } = await supabase
      .from('workouts')
      .update({
        start_time: start.toISOString(),
        end_time: finish.toISOString(),
        duration_seconds: duration,
      })
      .eq('id', id)
      .eq('user_id', userId)
    if (updateError) return friendlyError(updateError)
    await loadRecent()
    return null
  }

  async function removeWorkout(id: string): Promise<string | null> {
    const userId = auth.user?.id
    if (!userId) return 'You need to be signed in.'
    const { error: deleteError } = await supabase.from('workouts').delete().eq('id', id).eq('user_id', userId)
    if (deleteError) return friendlyError(deleteError)
    recent.value = recent.value.filter((item) => item.id !== id)
    catalog.value = catalog.value.filter((item) => item.id !== id)
    return null
  }

  async function loadCatalog() {
    const userId = auth.user?.id
    if (!userId) {
      catalog.value = []
      return
    }
    loading.value = true
    error.value = ''
    const { data, error: queryError } = await supabase
      .from('workouts')
      .select('id, routine_name, start_time, end_time, duration_seconds, total_volume, total_sets, records_broken')
      .eq('user_id', userId)
      .order('start_time', { ascending: false })
    loading.value = false
    if (queryError) {
      error.value = friendlyError(queryError)
      return
    }
    catalog.value = ((data ?? []) as unknown as RawWorkout[]).map(mapSummary)
  }

  async function loadMuscleSets() {
    const userId = auth.user?.id
    if (!userId) {
      muscleSets.value = []
      return
    }
    const since = new Date()
    since.setDate(since.getDate() - 90)
    const { data, error: queryError } = await supabase
      .from('set_logs')
      .select('exercises!inner(primary_muscle), workouts!inner(start_time)')
      .eq('user_id', userId)
      .gte('workouts.start_time', since.toISOString())
    if (queryError) {
      error.value = friendlyError(queryError)
      return
    }
    muscleSets.value = ((data ?? []) as {
      exercises: { primary_muscle: PrimaryMuscle } | { primary_muscle: PrimaryMuscle }[]
      workouts: { start_time: string } | { start_time: string }[]
    }[]).flatMap((row) => {
      const exercise = firstOf(row.exercises)
      const workout = firstOf(row.workouts)
      if (!exercise || !workout) return []
      return [{ startTime: workout.start_time, muscle: exercise.primary_muscle }]
    })
  }

  async function loadRecords() {
    const userId = auth.user?.id
    if (!userId) {
      records.value = []
      return
    }
    loading.value = true
    error.value = ''
    const { data, error: queryError } = await supabase
      .from('set_logs')
      .select('exercise_id, weight, reps, created_at, exercises ( name, primary_muscle )')
      .eq('user_id', userId)
      .order('created_at', { ascending: true })
    loading.value = false
    if (queryError) {
      error.value = friendlyError(queryError)
      return
    }

    const groups = new Map<string, PersonalRecord>()
    for (const row of (data ?? []) as {
      exercise_id: string
      weight: unknown
      reps: unknown
      created_at: string
      exercises: { name: string; primary_muscle: PrimaryMuscle } | { name: string; primary_muscle: PrimaryMuscle }[] | null
    }[]) {
      const weight = asNumber(row.weight)
      const reps = asNumber(row.reps)
      if (!(weight > 0) && !(reps > 0)) continue
      const exercise = firstOf(row.exercises)
      let record = groups.get(row.exercise_id)
      if (!record) {
        record = {
          exerciseId: row.exercise_id,
          name: exercise?.name ?? 'Exercise',
          muscle: exercise?.primary_muscle ?? 'Core',
          weight: 0,
          reps: 0,
          epley: null,
          points: [],
        }
        groups.set(row.exercise_id, record)
      }
      record.points.push({ at: row.created_at, weight, reps })
      const better = weight > record.weight || (weight === record.weight && reps > record.reps)
      if (better) {
        record.weight = weight
        record.reps = reps
        record.epley = calculateEpley1RM(weight, reps)
      }
    }
    records.value = [...groups.values()].sort((a, b) => a.name.localeCompare(b.name))
  }

  function reset() {
    recent.value = []
    catalog.value = []
    benchRatio.value = null
    records.value = []
    muscleSets.value = []
    loading.value = false
    error.value = ''
  }

  return {
    recent,
    catalog,
    benchRatio,
    records,
    muscleSets,
    loading,
    error,
    loadRecent,
    loadWorkout,
    updateTimes,
    removeWorkout,
    loadCatalog,
    loadMuscleSets,
    loadRecords,
    reset,
  }
})
