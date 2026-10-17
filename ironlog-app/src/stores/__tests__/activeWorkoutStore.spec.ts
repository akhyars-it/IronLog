import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { Exercise } from '../../types/database'

const celebrate = vi.fn()

vi.mock('canvas-confetti', () => ({ default: (...args: unknown[]) => celebrate(...args) }))
vi.mock('../../lib/haptics', () => ({ impactHeavy: vi.fn() }))

const rpc = vi.fn()

function query() {
  const builder: Record<string, unknown> = {}
  const self = () => builder
  for (const method of ['select', 'eq', 'order', 'limit', 'update', 'insert']) builder[method] = self
  builder.upsert = () => Promise.resolve({ error: null })
  builder.maybeSingle = () => Promise.resolve({ data: null, error: null })
  builder.single = () => Promise.resolve({ data: null, error: null })
  builder.then = (resolve: (value: unknown) => unknown, reject?: (reason: unknown) => unknown) =>
    Promise.resolve({ data: [], error: null }).then(resolve, reject)
  return builder
}

vi.mock('../../lib/supabase', () => ({
  supabase: {
    auth: {
      signInWithPassword: vi.fn(async () => ({
        data: {
          session: {
            access_token: 'token',
            refresh_token: 'refresh',
            expires_in: 3600,
            expires_at: 9_999_999_999,
            token_type: 'bearer',
            user: {
              id: '11111111-1111-4111-8111-111111111111',
              email: 'lifter@example.com',
              app_metadata: {},
              user_metadata: {},
              aud: 'authenticated',
              created_at: '2026-01-01T00:00:00.000Z',
            },
          },
        },
        error: null,
      })),
      getSession: vi.fn(async () => ({ data: { session: null } })),
      onAuthStateChange: vi.fn(),
      signOut: vi.fn(),
    },
    from: () => query(),
    rpc: (...args: unknown[]) => rpc(...args),
  },
}))

const bench: Exercise = {
  id: '10000000-0000-4000-8000-000000000001',
  user_id: null,
  name: 'Bench Press',
  equipment: 'Barbell',
  primary_muscle: 'Chest',
  category: 'push',
  exercise_type: 'reps_and_weight',
  image_url: null,
  is_custom: false,
  created_at: '2026-01-01T00:00:00.000Z',
}

describe('activeWorkoutStore', () => {
  beforeEach(() => {
    const memory = new Map<string, string>()
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => memory.get(key) ?? null,
      setItem: (key: string, value: string) => memory.set(key, value),
      removeItem: (key: string) => memory.delete(key),
      clear: () => memory.clear(),
    })
    celebrate.mockClear()
    rpc.mockReset()
    rpc.mockResolvedValue({ error: null })
    setActivePinia(createPinia())
  })

  async function start() {
    const { useAuthStore } = await import('../authStore')
    const { useActiveWorkoutStore } = await import('../activeWorkoutStore')
    const auth = useAuthStore()
    const workout = useActiveWorkoutStore()
    await auth.signIn('lifter@example.com', 'secret1')
    const error = await workout.begin({
      routineId: 'routine-1',
      routineName: 'Push',
      items: [{ exercise: bench, restSeconds: 180 }],
    })
    expect(error).toBeNull()
    return workout
  }

  it('counts volume from checked sets only', async () => {
    const workout = await start()
    const exercise = workout.workout?.exercises[0]
    const set = exercise?.sets[0]
    if (!exercise || !set) throw new Error('missing set')
    set.weight = '100'
    set.reps = '5'
    workout.toggleSet(exercise.localId, set.id)
    workout.addSet(exercise.localId)
    expect(workout.stats).toEqual({ sets: 1, volume: 500 })
  })

  it('detects a heavier set as a PR and raises the in-memory max', async () => {
    const workout = await start()
    const exercise = workout.workout?.exercises[0]
    const set = exercise?.sets[0]
    if (!exercise || !set) throw new Error('missing set')
    set.weight = '100'
    set.reps = '5'
    workout.toggleSet(exercise.localId, set.id)
    expect(exercise.maxWeight).toBe(100)
    expect(celebrate).toHaveBeenCalledTimes(1)

    workout.addSet(exercise.localId)
    const lighter = exercise.sets[1]
    if (!lighter) throw new Error('missing second set')
    lighter.weight = '90'
    lighter.reps = '5'
    workout.toggleSet(exercise.localId, lighter.id)
    expect(exercise.maxWeight).toBe(100)
    expect(celebrate).toHaveBeenCalledTimes(1)
  })

  it('keeps the rest timer inside 0 to 999 seconds and clamps progress to 1', async () => {
    const workout = await start()
    const exercise = workout.workout?.exercises[0]
    const set = exercise?.sets[0]
    if (!exercise || !set) throw new Error('missing set')
    set.weight = '60'
    set.reps = '8'
    workout.toggleSet(exercise.localId, set.id)
    expect(workout.restRemaining).toBeGreaterThan(0)
    expect(workout.restRemaining).toBeLessThanOrEqual(180)
    expect(workout.restProgress).toBeGreaterThan(0)
    expect(workout.restProgress).toBeLessThanOrEqual(1)

    workout.adjustRest(5000)
    expect(workout.restRemaining).toBe(999)
    expect(workout.restProgress).toBe(1)

    workout.adjustRest(-999)
    expect(workout.restRemaining).toBe(0)
    expect(workout.workout?.restEndsAt).toBeNull()
  })

  it('sends only checked sets in the atomic save payload', async () => {
    const workout = await start()
    const exercise = workout.workout?.exercises[0]
    const set = exercise?.sets[0]
    if (!exercise || !set) throw new Error('missing set')
    set.weight = '100'
    set.reps = '5'
    workout.toggleSet(exercise.localId, set.id)
    workout.addSet(exercise.localId)
    const unchecked = exercise.sets[1]
    if (!unchecked) throw new Error('missing unchecked set')
    unchecked.weight = '80'
    unchecked.reps = '5'

    await expect(workout.save()).resolves.toBeNull()
    const payload = rpc.mock.calls[0]?.[1] as { p_sets: { exercise_id: string; set_index: number; weight: number; reps: number }[] }
    expect(rpc.mock.calls[0]?.[0]).toBe('save_completed_workout')
    expect(payload.p_sets).toEqual([
      {
        exercise_id: bench.id,
        set_index: 1,
        weight: 100,
        reps: 5,
        duration_seconds: null,
        exercise_notes: null,
      },
    ])
    expect(workout.workout).toBeNull()
  })

  it('sanitizes a failed save', async () => {
    rpc.mockResolvedValue({
      error: { code: '23505', message: 'duplicate key value violates unique constraint "set_logs_pkey"' },
    })
    const workout = await start()
    const exercise = workout.workout?.exercises[0]
    const set = exercise?.sets[0]
    if (!exercise || !set) throw new Error('missing set')
    set.weight = '40'
    set.reps = '10'
    workout.toggleSet(exercise.localId, set.id)
    await expect(workout.save()).resolves.toBe('That value is already in use.')
  })
})
