export function asNumber(value: unknown): number {
  const parsed = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(parsed) ? parsed : 0
}

export function firstOf<T>(value: T | readonly T[] | null | undefined): T | null {
  if (Array.isArray(value)) {
    const first = value[0] as T | undefined
    return first ?? null
  }
  if (value == null) return null
  return value as T
}
