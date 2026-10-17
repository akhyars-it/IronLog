import { supabase } from '../lib/supabase'
import { friendlyError } from './errorHandler'

const PUSH_TITLE = 'Demo Push'
const PULL_TITLE = 'Demo Pull'

interface CatalogExercise {
  id: string
  name: string
  exercise_type: 'reps_and_weight' | 'bodyweight_reps' | 'duration'
}

interface PlannedSet {
  weight: number
  reps: number
  duration: number | null
}

interface PlannedExercise {
  name: string
  sets: PlannedSet[]
}

const pushPlan: PlannedExercise[][] = [
  [
    { name: 'Barbell Bench Press', sets: sets([60, 70, 75], [8, 6, 4]) },
    { name: 'Barbell Overhead Press', sets: sets([30, 35, 35], [8, 6, 5]) },
    { name: 'Push-Up', sets: body([10, 12, 12]) },
  ],
  [
    { name: 'Barbell Bench Press', sets: sets([65, 75, 80], [8, 5, 3]) },
    { name: 'Barbell Overhead Press', sets: sets([32.5, 35, 37.5], [8, 6, 5]) },
    { name: 'Push-Up', sets: body([12, 12, 15]) },
  ],
  [
    { name: 'Barbell Bench Press', sets: sets([70, 80, 85], [8, 5, 3]) },
    { name: 'Barbell Overhead Press', sets: sets([35, 40, 40], [8, 6, 5]) },
    { name: 'Push-Up', sets: body([15, 15, 18]) },
  ],
]

const pullPlan: PlannedExercise[][] = [
  [
    { name: 'Conventional Deadlift', sets: sets([80, 100, 110], [5, 3, 2]) },
    { name: 'Barbell Bent-Over Row', sets: sets([40, 45, 45], [8, 8, 6]) },
    { name: 'Pull-Up', sets: body([5, 5, 4]) },
    { name: 'Plank', sets: hold([40, 45, 45]) },
  ],
  [
    { name: 'Conventional Deadlift', sets: sets([90, 110, 120], [5, 3, 2]) },
    { name: 'Barbell Bent-Over Row', sets: sets([45, 50, 50], [8, 8, 6]) },
    { name: 'Pull-Up', sets: body([6, 6, 5]) },
    { name: 'Plank', sets: hold([45, 50, 50]) },
  ],
  [
    { name: 'Conventional Deadlift', sets: sets([100, 120, 130], [5, 3, 1]) },
    { name: 'Barbell Bent-Over Row', sets: sets([50, 55, 55], [8, 8, 6]) },
    { name: 'Pull-Up', sets: body([6, 8, 6]) },
    { name: 'Plank', sets: hold([50, 60, 60]) },
  ],
]

function sets(weights: number[], reps: number[]): PlannedSet[] {
  return weights.map((weight, index) => ({ weight, reps: reps[index] ?? 5, duration: null }))
}

function body(reps: number[]): PlannedSet[] {
  return reps.map((count) => ({ weight: 0, reps: count, duration: null }))
}

function hold(seconds: number[]): PlannedSet[] {
  return seconds.map((duration) => ({ weight: 0, reps: 0, duration }))
}

function atDaysAgo(daysAgo: number): { start: Date; end: Date } {
  const start = new Date()
  start.setDate(start.getDate() - daysAgo)
  start.setHours(18, 0, 0, 0)
  return { start, end: new Date(start.getTime() + 50 * 60 * 1000) }
}

export async function seedDemoData(): Promise<{ ok: boolean; message: string }> {
  const { data: userData, error: userError } = await supabase.auth.getUser()
  const userId = userData.user?.id
  if (userError || !userId) return { ok: false, message: userError ? friendlyError(userError) : 'Log in before seeding demo data.' }

  const existing = await supabase
    .from('workouts')
    .select('id')
    .eq('user_id', userId)
    .in('routine_name', [PUSH_TITLE, PULL_TITLE])
    .limit(1)
  if (existing.error) return { ok: false, message: friendlyError(existing.error) }
  if ((existing.data ?? []).length > 0) {
    return { ok: false, message: 'Demo workouts are already in your history. Delete Demo Push and Demo Pull sessions to seed again.' }
  }

  const names = [...new Set([...pushPlan, ...pullPlan].flat().map((item) => item.name))]
  const catalog = await supabase.from('exercises').select('id, name, exercise_type').in('name', names).eq('is_custom', false)
  if (catalog.error) return { ok: false, message: friendlyError(catalog.error) }
  const byName = new Map<string, CatalogExercise>()
  for (const row of (catalog.data ?? []) as CatalogExercise[]) byName.set(row.name, row)
  const missing = names.filter((name) => !byName.has(name))
  if (missing.length > 0) {
    return {
      ok: false,
      message: `Missing catalog exercises (${missing.join(', ')}). Run supabase/02_seed.sql, then try again.`,
    }
  }

  const push = await ensureRoutine(userId, PUSH_TITLE, 'Seeded push session', pushPlan[0] ?? [], byName)
  if (!push.ok) return push
  const pull = await ensureRoutine(userId, PULL_TITLE, 'Seeded pull session', pullPlan[0] ?? [], byName)
  if (!pull.ok) return pull
  const pushId = push.id
  const pullId = pull.id

  const schedule: { daysAgo: number; routineId: string; name: string; plan: PlannedExercise[] }[] = [
    { daysAgo: 13, routineId: pushId, name: PUSH_TITLE, plan: pushPlan[0] ?? [] },
    { daysAgo: 11, routineId: pullId, name: PULL_TITLE, plan: pullPlan[0] ?? [] },
    { daysAgo: 8, routineId: pushId, name: PUSH_TITLE, plan: pushPlan[1] ?? [] },
    { daysAgo: 6, routineId: pullId, name: PULL_TITLE, plan: pullPlan[1] ?? [] },
    { daysAgo: 3, routineId: pushId, name: PUSH_TITLE, plan: pushPlan[2] ?? [] },
    { daysAgo: 1, routineId: pullId, name: PULL_TITLE, plan: pullPlan[2] ?? [] },
  ]

  for (const session of schedule) {
    const saved = await saveSession(session.routineId, session.name, session.daysAgo, session.plan, byName)
    if (saved) return { ok: false, message: saved }
  }

  return { ok: true, message: 'Added Demo Push, Demo Pull, and 6 workouts over the last two weeks.' }
}

async function ensureRoutine(
  userId: string,
  title: string,
  description: string,
  plan: PlannedExercise[],
  byName: Map<string, CatalogExercise>,
): Promise<{ ok: true; id: string } | { ok: false; message: string }> {
  const found = await supabase.from('routines').select('id').eq('user_id', userId).eq('title', title).maybeSingle()
  if (found.error) return { ok: false, message: friendlyError(found.error) }
  const existingId = (found.data as { id: string } | null)?.id
  if (existingId) return { ok: true, id: existingId }

  const created = await supabase
    .from('routines')
    .insert({ user_id: userId, title, description })
    .select('id')
    .single()
  if (created.error) return { ok: false, message: friendlyError(created.error) }
  const routineId = (created.data as { id: string }).id
  const rows = plan.map((item, index) => ({
    routine_id: routineId,
    exercise_id: byName.get(item.name)?.id,
    order_index: index,
    rest_seconds: 180,
  }))
  const children = await supabase.from('routine_exercises').insert(rows)
  if (children.error) return { ok: false, message: friendlyError(children.error) }
  return { ok: true, id: routineId }
}

async function saveSession(
  routineId: string,
  routineName: string,
  daysAgo: number,
  plan: PlannedExercise[],
  byName: Map<string, CatalogExercise>,
): Promise<string | null> {
  const { start, end } = atDaysAgo(daysAgo)
  const payload = plan.flatMap((item) => {
    const exercise = byName.get(item.name)
    if (!exercise) return []
    return item.sets.map((set, index) => ({
      exercise_id: exercise.id,
      set_index: index + 1,
      weight: exercise.exercise_type === 'reps_and_weight' ? set.weight : 0,
      reps: exercise.exercise_type === 'duration' ? 0 : set.reps,
      duration_seconds: exercise.exercise_type === 'duration' ? set.duration : null,
      exercise_notes: null,
    }))
  })
  const { error } = await supabase.rpc('save_completed_workout', {
    p_routine_id: routineId,
    p_routine_name: routineName,
    p_start_time: start.toISOString(),
    p_end_time: end.toISOString(),
    p_duration_seconds: 50 * 60,
    p_notes: 'Seeded demo session',
    p_sets: payload,
  })
  return error ? friendlyError(error) : null
}
