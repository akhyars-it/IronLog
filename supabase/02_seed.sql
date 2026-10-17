-- IronLog global exercise catalog
-- Run after supabase/01_schema.sql, as postgres or service_role.
-- Authenticated users cannot insert is_custom = false rows; RLS reserves
-- that for roles that bypass row level security.
--
-- 44 shared exercises. user_id is null and is_custom is false.
-- Every primary_muscle, equipment value, and category used by the app is
-- present. Barbell Bench Press and the other category = 'bench' rows are
-- what the bench-to-bodyweight ratio matches on.
--
-- Safe to re-run: existing ids are left untouched.

insert into public.exercises (
  id,
  user_id,
  name,
  equipment,
  primary_muscle,
  category,
  exercise_type,
  is_custom
)
values
  -- Chest
  ('10000000-0000-4000-8000-000000000001', null, 'Barbell Bench Press', 'Barbell', 'Chest', 'bench', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000002', null, 'Incline Barbell Bench Press', 'Barbell', 'Chest', 'bench', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000003', null, 'Dumbbell Bench Press', 'Dumbbell', 'Chest', 'bench', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000004', null, 'Incline Dumbbell Fly', 'Dumbbell', 'Chest', 'push', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000005', null, 'Machine Chest Press', 'Machine', 'Chest', 'bench', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000006', null, 'Cable Crossover', 'Cable', 'Chest', 'push', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000007', null, 'Push-Up', 'Bodyweight', 'Chest', 'push', 'bodyweight_reps', false),
  ('10000000-0000-4000-8000-000000000008', null, 'Kettlebell Floor Press', 'Kettlebell', 'Chest', 'bench', 'reps_and_weight', false),

  -- Back
  ('10000000-0000-4000-8000-000000000009', null, 'Conventional Deadlift', 'Barbell', 'Back', 'deadlift', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000010', null, 'Romanian Deadlift', 'Barbell', 'Back', 'deadlift', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000011', null, 'Barbell Bent-Over Row', 'Barbell', 'Back', 'row', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000012', null, 'One-Arm Dumbbell Row', 'Dumbbell', 'Back', 'row', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000013', null, 'Lat Pulldown', 'Machine', 'Back', 'pull', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000014', null, 'Seated Cable Row', 'Cable', 'Back', 'row', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000015', null, 'Pull-Up', 'Bodyweight', 'Back', 'pull', 'bodyweight_reps', false),
  ('10000000-0000-4000-8000-000000000016', null, 'Kettlebell Swing', 'Kettlebell', 'Back', 'other', 'reps_and_weight', false),

  -- Shoulders
  ('10000000-0000-4000-8000-000000000017', null, 'Barbell Overhead Press', 'Barbell', 'Shoulders', 'overhead_press', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000018', null, 'Dumbbell Shoulder Press', 'Dumbbell', 'Shoulders', 'overhead_press', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000019', null, 'Machine Shoulder Press', 'Machine', 'Shoulders', 'overhead_press', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-00000000001a', null, 'Cable Lateral Raise', 'Cable', 'Shoulders', 'push', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-00000000001b', null, 'Pike Push-Up', 'Bodyweight', 'Shoulders', 'overhead_press', 'bodyweight_reps', false),
  ('10000000-0000-4000-8000-00000000001c', null, 'Kettlebell Halo', 'Kettlebell', 'Shoulders', 'other', 'reps_and_weight', false),

  -- Legs
  ('10000000-0000-4000-8000-00000000001d', null, 'Barbell Back Squat', 'Barbell', 'Legs', 'squat', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-00000000001e', null, 'Barbell Front Squat', 'Barbell', 'Legs', 'squat', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-00000000001f', null, 'Dumbbell Goblet Squat', 'Dumbbell', 'Legs', 'squat', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000020', null, 'Leg Press', 'Machine', 'Legs', 'squat', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000021', null, 'Cable Pull-Through', 'Cable', 'Legs', 'other', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000022', null, 'Bodyweight Squat', 'Bodyweight', 'Legs', 'squat', 'bodyweight_reps', false),
  ('10000000-0000-4000-8000-000000000023', null, 'Kettlebell Goblet Squat', 'Kettlebell', 'Legs', 'squat', 'reps_and_weight', false),

  -- Arms
  ('10000000-0000-4000-8000-000000000024', null, 'Barbell Curl', 'Barbell', 'Arms', 'pull', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000025', null, 'Dumbbell Hammer Curl', 'Dumbbell', 'Arms', 'pull', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000026', null, 'Triceps Pushdown', 'Cable', 'Arms', 'push', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000027', null, 'Machine Preacher Curl', 'Machine', 'Arms', 'pull', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-000000000028', null, 'Bench Dip', 'Bodyweight', 'Arms', 'push', 'bodyweight_reps', false),
  ('10000000-0000-4000-8000-000000000029', null, 'Kettlebell Curl', 'Kettlebell', 'Arms', 'pull', 'reps_and_weight', false),

  -- Core
  ('10000000-0000-4000-8000-00000000002a', null, 'Plank', 'Bodyweight', 'Core', 'other', 'duration', false),
  ('10000000-0000-4000-8000-00000000002b', null, 'Cable Crunch', 'Cable', 'Core', 'other', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-00000000002c', null, 'Hanging Knee Raise', 'Bodyweight', 'Core', 'other', 'bodyweight_reps', false),
  ('10000000-0000-4000-8000-00000000002d', null, 'Dumbbell Russian Twist', 'Dumbbell', 'Core', 'other', 'reps_and_weight', false),
  ('10000000-0000-4000-8000-00000000002e', null, 'Kettlebell Windmill', 'Kettlebell', 'Core', 'other', 'reps_and_weight', false),

  -- Cardio
  ('10000000-0000-4000-8000-00000000002f', null, 'Running', 'Bodyweight', 'Cardio', 'other', 'duration', false),
  ('10000000-0000-4000-8000-000000000030', null, 'Rowing Machine', 'Machine', 'Cardio', 'other', 'duration', false),
  ('10000000-0000-4000-8000-000000000031', null, 'Jump Rope', 'Bodyweight', 'Cardio', 'other', 'duration', false),
  ('10000000-0000-4000-8000-000000000032', null, 'Dumbbell Thruster', 'Dumbbell', 'Cardio', 'other', 'reps_and_weight', false)
on conflict (id) do nothing;
