import { startOfDay, startOfWeekMonday } from './dates'

export interface WeekPoint {
  startTime: string
  totalVolume: number
  totalSets: number
}

export interface WeekBucket {
  label: string
  value: number
}

/** Calendar weeks (Monday) inside a trailing window. Zero weeks stay at 0. */
export function buildWeekSeries(
  rows: readonly WeekPoint[],
  days: number,
  metric: 'volume' | 'sets',
  today = new Date(),
): WeekBucket[] {
  const end = startOfDay(today)
  const windowStart = new Date(end)
  windowStart.setDate(windowStart.getDate() - (days - 1))
  const lastMonday = startOfWeekMonday(end)
  const buckets: { label: string; value: number; start: number }[] = []

  for (
    let cursor = startOfWeekMonday(windowStart);
    cursor.getTime() <= lastMonday.getTime();
    cursor = addDays(cursor, 7)
  ) {
    buckets.push({
      label: cursor.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
      value: 0,
      start: cursor.getTime(),
    })
  }

  const windowEnd = new Date(end)
  windowEnd.setHours(23, 59, 59, 999)

  for (const row of rows) {
    const date = new Date(row.startTime)
    if (Number.isNaN(date.getTime()) || date < windowStart || date > windowEnd) continue
    const monday = startOfWeekMonday(date).getTime()
    const bucket = buckets.find((item) => item.start === monday)
    if (!bucket) continue
    bucket.value += metric === 'volume' ? row.totalVolume : row.totalSets
  }

  return buckets.map(({ label, value }) => ({ label, value }))
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date)
  next.setDate(next.getDate() + days)
  return next
}
