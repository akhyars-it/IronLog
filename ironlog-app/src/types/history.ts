import type { ExerciseCategory, ExerciseType, PrimaryMuscle, Workout } from './database'

export interface HistorySet {
  id: string
  exercise_id: string
  set_index: number
  weight: number
  reps: number
  duration_seconds: number | null
  exercise_notes: string | null
  is_pr: boolean
  created_at: string
  name: string
  primary_muscle: PrimaryMuscle
  category: ExerciseCategory
  exercise_type: ExerciseType
}

export interface HistoryWorkout extends Workout {
  sets: HistorySet[]
}

export interface WorkoutSummary {
  id: string
  routine_name: string
  start_time: string
  end_time: string
  duration_seconds: number
  total_volume: number
  total_sets: number
  records_broken: number
}

export interface PrPoint {
  at: string
  weight: number
  reps: number
}

export interface PersonalRecord {
  exerciseId: string
  name: string
  muscle: PrimaryMuscle
  weight: number
  reps: number
  epley: number | null
  points: PrPoint[]
}
