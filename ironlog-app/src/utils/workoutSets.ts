import type { ExerciseType, PrimaryMuscle } from '../types/database'
import type { HistorySet } from '../types/history'

export const MUSCLE_COLORS: Record<PrimaryMuscle, string> = {
  Chest: '#3b82f6',
  Back: '#fb923c',
  Shoulders: '#a78bfa',
  Arms: '#f87171',
  Legs: '#4ade80',
  Core: '#facc15',
  Cardio: '#f472b6',
}

export const MUSCLE_ORDER: PrimaryMuscle[] = [
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Legs',
  'Core',
  'Cardio',
]

export interface ExerciseGroup {
  exerciseId: string
  name: string
  muscle: PrimaryMuscle
  exerciseType: ExerciseType
  notes: string | null
  sets: HistorySet[]
}

export function groupWorkoutSets(sets: readonly HistorySet[]): ExerciseGroup[] {
  const groups: ExerciseGroup[] = []
  const ordered = [...sets].sort((a, b) => a.set_index - b.set_index)
  for (const set of ordered) {
    let group = groups.find((item) => item.exerciseId === set.exercise_id)
    if (!group) {
      group = {
        exerciseId: set.exercise_id,
        name: set.name,
        muscle: set.primary_muscle,
        exerciseType: set.exercise_type,
        notes: set.exercise_notes,
        sets: [],
      }
      groups.push(group)
    }
    group.sets.push(set)
  }
  return groups
}

export function muscleSplit(sets: readonly HistorySet[]): { muscle: PrimaryMuscle; count: number; percent: number }[] {
  const counts = new Map<PrimaryMuscle, number>()
  for (const set of sets) {
    counts.set(set.primary_muscle, (counts.get(set.primary_muscle) ?? 0) + 1)
  }
  const total = sets.length
  return MUSCLE_ORDER.filter((muscle) => (counts.get(muscle) ?? 0) > 0).map((muscle) => {
    const count = counts.get(muscle) ?? 0
    return { muscle, count, percent: total > 0 ? (count / total) * 100 : 0 }
  })
}

/** Highest weight × reps in the workout for that exercise. Duration breaks ties only when load is zero. */
export function topSetIds(sets: readonly HistorySet[]): Set<string> {
  const winners = new Set<string>()
  for (const group of groupWorkoutSets(sets)) {
    let best = 0
    for (const set of group.sets) {
      const load = set.weight * set.reps
      const score = load > 0 ? load : (set.duration_seconds ?? 0)
      if (score > best) best = score
    }
    if (!(best > 0)) continue
    for (const set of group.sets) {
      const load = set.weight * set.reps
      const score = load > 0 ? load : (set.duration_seconds ?? 0)
      if (score === best) winners.add(set.id)
    }
  }
  return winners
}

export function formatSet(set: Pick<HistorySet, 'weight' | 'reps' | 'duration_seconds' | 'exercise_type'>): string {
  if (set.exercise_type === 'duration') return `${set.duration_seconds ?? 0}s`
  if (set.exercise_type === 'bodyweight_reps') return `${set.reps} reps`
  return `${set.weight} kg × ${set.reps}`
}
