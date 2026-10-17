import { describe, expect, it } from 'vitest'
import {
  calculateBMI,
  calculateBrzycki1RM,
  calculateEpley1RM,
  calculateFFMI,
  calculateGoalProgress,
  calculateSetVolume,
  calculateUSNavyBodyFat,
  calculateWeekStreakAndRestDays,
  calculateWorkoutVolume,
} from '../fitnessMath'

describe('volume', () => {
  it('multiplies weight by reps and treats non-finite numbers as zero', () => {
    expect(calculateSetVolume(100, 5)).toBe(500)
    expect(calculateSetVolume(Number.NaN, 5)).toBe(0)
    expect(calculateSetVolume(80, Number.POSITIVE_INFINITY)).toBe(0)
  })

  it('sums only checked sets', () => {
    expect(
      calculateWorkoutVolume([
        { weight: 100, reps: 5, isDone: true },
        { weight: 80, reps: 8, isDone: false },
        { weight: 60, reps: 10, isDone: true },
      ]),
    ).toBe(1100)
  })
})

describe('one-rep max', () => {
  it('uses Epley and returns the weight itself at one rep or fewer', () => {
    expect(calculateEpley1RM(100, 1)).toBe(100)
    expect(calculateEpley1RM(100, 0)).toBe(100)
    expect(calculateEpley1RM(90, 5)).toBeCloseTo(90 * (1 + 5 / 30))
    expect(calculateEpley1RM(Number.NaN, 5)).toBeNull()
  })

  it('uses Brzycki and skips reps at or above 37', () => {
    expect(calculateBrzycki1RM(100, 5)).toBeCloseTo(100 * (36 / 32))
    expect(calculateBrzycki1RM(100, 36)).toBe(3600)
    expect(calculateBrzycki1RM(100, 37)).toBeNull()
    expect(calculateBrzycki1RM(100, 40)).toBeNull()
    expect(calculateBrzycki1RM(100, 0)).toBeNull()
  })
})

describe('body metrics', () => {
  it('labels BMI with the legacy cutoffs', () => {
    expect(calculateBMI(70, 175)?.category).toBe('HEALTHY')
    expect(calculateBMI(50, 175)?.category).toBe('UNDERWEIGHT')
    expect(calculateBMI(80, 175)?.category).toBe('OVERWEIGHT')
    expect(calculateBMI(100, 175)?.category).toBe('OBESE')
    expect(calculateBMI(70, 0)).toBeNull()

    const healthy = calculateBMI(70, 175)
    expect(healthy?.bmi).toBeCloseTo(70 / 1.75 ** 2)
    expect(calculateBMI(76.5625, 175)?.category).toBe('OVERWEIGHT')
  })

  it('requires body fat before FFMI', () => {
    expect(calculateFFMI(80, 180, 0)).toBeNull()
    expect(calculateFFMI(80, 180, 20)).toBeCloseTo(64 / 1.8 ** 2)
  })

  it('estimates Navy body fat for either gender capitalization and clamps the result', () => {
    const male = calculateUSNavyBodyFat({
      gender: 'Male',
      heightCm: 180,
      waistCm: 90,
      neckCm: 38,
    })
    const sameMale = calculateUSNavyBodyFat({
      gender: 'MALE',
      heightCm: 180,
      waistCm: 90,
      neckCm: 38,
    })
    expect(male).toBe(sameMale)
    expect(male).toBeGreaterThan(3)
    expect(male).toBeLessThan(50)

    const female = calculateUSNavyBodyFat({
      gender: ' female ',
      heightCm: 165,
      waistCm: 75,
      neckCm: 32,
      hipCm: 95,
    })
    expect(female).not.toBe(male)
    expect(female).toBeGreaterThan(3)

    expect(
      calculateUSNavyBodyFat({ gender: 'male', heightCm: 180, waistCm: 38, neckCm: 38 }),
    ).toBeNull()
    expect(
      calculateUSNavyBodyFat({ gender: 'female', heightCm: 165, waistCm: 75, neckCm: 32 }),
    ).toBeNull()
    expect(
      calculateUSNavyBodyFat({
        gender: 'female',
        heightCm: 165,
        waistCm: 40,
        neckCm: 39,
        hipCm: 0,
      }),
    ).toBeNull()
    expect(
      calculateUSNavyBodyFat({ gender: 'other', heightCm: 180, waistCm: 90, neckCm: 38 }),
    ).toBeNull()
    expect(
      calculateUSNavyBodyFat({ gender: 'male', heightCm: 150, waistCm: 200, neckCm: 30 }),
    ).toBe(50)
    expect(
      calculateUSNavyBodyFat({ gender: 'male', heightCm: 190, waistCm: 40, neckCm: 39 }),
    ).toBe(3)
  })
})

describe('goal progress', () => {
  it('treats a cut and a bulk as the same distance from the goal', () => {
    const bulk = calculateGoalProgress(70, 80)
    const cut = calculateGoalProgress(80, 70)
    expect(bulk).toEqual({ direction: 'bulk', kilogramsLeft: 10, progress: 70 / 80 })
    expect(cut).toEqual({ direction: 'cut', kilogramsLeft: 10, progress: 70 / 80 })
    expect(calculateGoalProgress(75, 75)).toEqual({
      direction: 'maintain',
      kilogramsLeft: 0,
      progress: 1,
    })
    expect(calculateGoalProgress(0, 70)).toBeNull()
  })
})

describe('calendar streak', () => {
  const today = new Date(2026, 9, 17)

  it('distinguishes never trained from trained today', () => {
    expect(calculateWeekStreakAndRestDays([], today)).toEqual({ weekStreak: 0, restDays: null })
    expect(calculateWeekStreakAndRestDays([new Date(2026, 9, 17)], today)).toEqual({
      weekStreak: 1,
      restDays: 0,
    })
  })

  it('counts consecutive Monday weeks and stops when the current week is empty', () => {
    expect(
      calculateWeekStreakAndRestDays([new Date(2026, 9, 12), new Date(2026, 9, 6)], today),
    ).toEqual({ weekStreak: 2, restDays: 5 })

    expect(calculateWeekStreakAndRestDays([new Date(2026, 9, 11)], today)).toEqual({
      weekStreak: 0,
      restDays: 6,
    })

    expect(
      calculateWeekStreakAndRestDays(
        [new Date(2026, 8, 28), new Date(2026, 9, 5), new Date(2026, 9, 12)],
        today,
      ).weekStreak,
    ).toBe(3)

    expect(
      calculateWeekStreakAndRestDays([new Date(2026, 8, 28), new Date(2026, 9, 12)], today)
        .weekStreak,
    ).toBe(1)
  })

  it('ignores a future session when nothing else has been logged', () => {
    expect(calculateWeekStreakAndRestDays([new Date(2026, 9, 20)], today)).toEqual({
      weekStreak: 0,
      restDays: null,
    })
  })
})
