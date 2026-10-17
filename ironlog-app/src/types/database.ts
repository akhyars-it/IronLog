/** Rows match supabase/01_schema.sql. Exercise has one strength tag: category. */

export type Gender = 'male' | 'female' | 'other'

export type Equipment =
  | 'Dumbbell'
  | 'Barbell'
  | 'Machine'
  | 'Cable'
  | 'Bodyweight'
  | 'Kettlebell'

export type PrimaryMuscle = 'Chest' | 'Back' | 'Shoulders' | 'Legs' | 'Arms' | 'Core' | 'Cardio'

export type ExerciseCategory =
  | 'bench'
  | 'squat'
  | 'deadlift'
  | 'overhead_press'
  | 'row'
  | 'pull'
  | 'push'
  | 'other'

export type ExerciseType = 'reps_and_weight' | 'bodyweight_reps' | 'duration'

export type WorkoutStatus = 'completed'

export interface Profile {
  id: string
  email: string | null
  username: string
  full_name: string | null
  gender: Gender
  birth_date: string | null
  height: number | null
  current_weight: number | null
  target_weight: number | null
  current_body_fat: number | null
  bio: string | null
  avatar_url: string | null
  created_at: string
  updated_at: string
}

export interface Exercise {
  id: string
  user_id: string | null
  name: string
  equipment: Equipment
  primary_muscle: PrimaryMuscle
  category: ExerciseCategory
  exercise_type: ExerciseType
  image_url: string | null
  is_custom: boolean
  created_at: string
}

export interface Routine {
  id: string
  user_id: string
  title: string
  description: string | null
  created_at: string
}

export interface RoutineExercise {
  id: string
  routine_id: string
  exercise_id: string
  order_index: number
  rest_seconds: number
}

export interface Workout {
  id: string
  user_id: string
  routine_id: string | null
  routine_name: string
  start_time: string
  end_time: string
  duration_seconds: number
  total_volume: number
  total_sets: number
  records_broken: number
  notes: string | null
  status: WorkoutStatus
  created_at: string
}

export interface SetLog {
  id: string
  workout_id: string
  user_id: string
  exercise_id: string
  set_index: number
  weight: number
  reps: number
  duration_seconds: number | null
  exercise_notes: string | null
  is_pr: boolean
  created_at: string
}

export interface ProfileWrite {
  username: string
  fullName: string
  gender: Gender
  birthDate: string | null
  heightCm: number | null
  weightKg: number | null
  targetWeightKg: number | null
  bodyFatPercent: number | null
  bio: string | null
}
