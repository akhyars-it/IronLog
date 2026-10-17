import { describe, expect, it } from 'vitest'
import { friendlyError } from '../errorHandler'

describe('friendlyError', () => {
  it('maps unique username violations', () => {
    expect(
      friendlyError({
        code: '23505',
        message: 'duplicate key value violates unique constraint "profiles_username_key"',
      }),
    ).toBe('Username already taken')
  })

  it('maps other unique violations without the raw constraint text', () => {
    expect(friendlyError({ code: '23505', message: 'duplicate key value violates unique constraint "workouts_pkey"' })).toBe(
      'That value is already in use.',
    )
  })

  it('maps invalid credentials', () => {
    expect(friendlyError({ code: 'invalid_credentials', message: 'Invalid login credentials' })).toBe(
      'Email or password is incorrect.',
    )
  })

  it('maps email send rate limits', () => {
    expect(friendlyError({ code: 'over_email_send_rate_limit', message: 'email rate limit exceeded' })).toBe(
      'Too many emails were sent. Wait a minute and try again.',
    )
  })

  it('maps network failures', () => {
    expect(friendlyError({ message: 'TypeError: Failed to fetch' })).toBe(
      'Network problem. Check your connection and try again.',
    )
  })

  it('maps row-level security denials', () => {
    expect(
      friendlyError({
        code: '42501',
        message: 'new row violates row-level security policy for table "profiles"',
      }),
    ).toBe('You do not have permission to do that.')
  })

  it('hides leftover PostgREST text', () => {
    expect(friendlyError({ message: 'PGRST116: JSON object requested, multiple (or no) rows returned' })).toBe(
      'Something went wrong. Try again.',
    )
  })

  it('keeps a short human message that is not a database error', () => {
    expect(friendlyError({ message: 'Email not confirmed' })).toBe('Email not confirmed')
  })
})
