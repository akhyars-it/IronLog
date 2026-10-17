/**
 * Domain math from the legacy IronLog blueprint, with the known bugs removed.
 * Units are centimetres, kilograms, and percent body fat.
 */

export interface LoggedSet {
  weight: number
  reps: number
  isDone: boolean
}

export type BmiCategory = 'UNDERWEIGHT' | 'HEALTHY' | 'OVERWEIGHT' | 'OBESE'

export interface BmiResult {
  bmi: number
  category: BmiCategory
}

export type GoalDirection = 'bulk' | 'cut' | 'maintain'

export interface GoalProgress {
  direction: GoalDirection
  kilogramsLeft: number
  /**
   * How close current weight is to the target, from 0 to 1.
   * min(current, target) / max(current, target), so a cut does not fill the
   * bar just because current is already above target.
   */
  progress: number
}

export interface NavyBodyFatInput {
  gender: string
  heightCm: number
  waistCm: number
  neckCm: number
  hipCm?: number | null
}

export interface WeekStreakResult {
  weekStreak: number
  /** Null when there is no training history. Zero when the latest session is today. */
  restDays: number | null
}

const DAY_MS = 86_400_000

function finiteOrZero(value: number): number {
  return Number.isFinite(value) ? value : 0
}

export function calculateSetVolume(weight: number, reps: number): number {
  return finiteOrZero(weight) * finiteOrZero(reps)
}

export function calculateWorkoutVolume(sets: readonly LoggedSet[]): number {
  return sets.reduce((total, set) => {
    if (!set.isDone) return total
    return total + calculateSetVolume(set.weight, set.reps)
  }, 0)
}

/** Epley estimate used on the personal-records list. */
export function calculateEpley1RM(weight: number, reps: number): number | null {
  if (!Number.isFinite(weight) || !Number.isFinite(reps)) return null
  if (reps <= 1) return weight
  return weight * (1 + reps / 30)
}

/**
 * Brzycki estimate used on exercise details.
 * Reps at or above 37 make the denominator zero or negative, so those sets are skipped.
 */
export function calculateBrzycki1RM(weight: number, reps: number): number | null {
  if (!Number.isFinite(weight) || !Number.isFinite(reps) || reps <= 0 || reps >= 37) return null
  return weight * (36 / (37 - reps))
}

export function calculateBMI(weightKg: number, heightCm: number): BmiResult | null {
  if (!(weightKg > 0) || !(heightCm > 0)) return null
  const heightM = heightCm / 100
  const bmi = weightKg / (heightM * heightM)
  return { bmi, category: bmiCategory(bmi) }
}

function bmiCategory(bmi: number): BmiCategory {
  if (bmi < 18.5) return 'UNDERWEIGHT'
  if (bmi < 25) return 'HEALTHY'
  if (bmi < 30) return 'OVERWEIGHT'
  return 'OBESE'
}

export function calculateFFMI(
  weightKg: number,
  heightCm: number,
  bodyFatPercent: number,
): number | null {
  if (!(weightKg > 0) || !(heightCm > 0) || !(bodyFatPercent > 0)) return null
  const heightM = heightCm / 100
  const leanMass = weightKg * (1 - bodyFatPercent / 100)
  return leanMass / (heightM * heightM)
}

/**
 * U.S. Navy tape estimate. Gender is matched case-insensitively.
 * Male uses waist and neck. Female also requires hips.
 * The result is rounded to one decimal, then clamped to 3.0–50.0.
 */
export function calculateUSNavyBodyFat(input: NavyBodyFatInput): number | null {
  const gender = input.gender.trim().toLowerCase()
  const { heightCm, waistCm, neckCm } = input
  const hipCm = input.hipCm

  if (!(heightCm > 0) || !(waistCm > neckCm)) return null
  if (!(waistCm + (hipCm ?? 0) > neckCm)) return null

  let raw: number
  if (gender === 'male') {
    const denominator =
      1.0324 - 0.19077 * Math.log10(waistCm - neckCm) + 0.15456 * Math.log10(heightCm)
    if (!(denominator > 0)) return null
    raw = 495 / denominator - 450
  } else if (gender === 'female') {
    if (hipCm == null || !(hipCm > 0) || !(waistCm + hipCm > neckCm)) return null
    const denominator =
      1.29579 -
      0.35004 * Math.log10(waistCm + hipCm - neckCm) +
      0.221 * Math.log10(heightCm)
    if (!(denominator > 0)) return null
    raw = 495 / denominator - 450
  } else {
    return null
  }

  const rounded = Math.round(raw * 10) / 10
  return Math.min(50, Math.max(3, rounded))
}

export function calculateGoalProgress(
  currentWeightKg: number,
  targetWeightKg: number,
): GoalProgress | null {
  if (!(currentWeightKg > 0) || !(targetWeightKg > 0)) return null
  const direction: GoalDirection =
    targetWeightKg > currentWeightKg ? 'bulk' : targetWeightKg < currentWeightKg ? 'cut' : 'maintain'
  return {
    direction,
    kilogramsLeft: Math.abs(targetWeightKg - currentWeightKg),
    progress: Math.min(currentWeightKg, targetWeightKg) / Math.max(currentWeightKg, targetWeightKg),
  }
}

/**
 * Monday–Sunday streak walking backward from the current week.
 * An empty current week is a streak of 0 even if older weeks were complete.
 * Dates are compared as local calendar days. Future dates are ignored.
 */
export function calculateWeekStreakAndRestDays(
  workoutDates: readonly Date[],
  today: Date = new Date(),
): WeekStreakResult {
  const todayNumber = dayNumber(today)
  const trainedDays = [
    ...new Set(
      workoutDates
        .filter((date) => !Number.isNaN(date.getTime()))
        .map(dayNumber)
        .filter((day) => day <= todayNumber),
    ),
  ].sort((a, b) => a - b)

  if (trainedDays.length === 0) {
    return { weekStreak: 0, restDays: null }
  }

  const latest = trainedDays[trainedDays.length - 1] ?? todayNumber
  const trained = new Set(trainedDays)
  let weekStreak = 0
  let weekStart = mondayNumber(today)

  while (weekContains(trained, weekStart)) {
    weekStreak += 1
    weekStart -= 7 * DAY_MS
  }

  return {
    weekStreak,
    restDays: Math.round((todayNumber - latest) / DAY_MS),
  }
}

function dayNumber(date: Date): number {
  return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
}

function mondayNumber(date: Date): number {
  const day = new Date(dayNumber(date))
  const weekday = day.getUTCDay()
  const daysSinceMonday = weekday === 0 ? 6 : weekday - 1
  return dayNumber(date) - daysSinceMonday * DAY_MS
}

function weekContains(days: ReadonlySet<number>, monday: number): boolean {
  for (let offset = 0; offset < 7; offset += 1) {
    if (days.has(monday + offset * DAY_MS)) return true
  }
  return false
}
