export interface AppError {
  message?: string
  code?: string | null
}

const FALLBACK = 'Something went wrong. Try again.'

function text(error: AppError): string {
  return (error.message ?? '').trim()
}

function looksTechnical(message: string): boolean {
  const lower = message.toLowerCase()
  return (
    lower.includes('postgrest') ||
    lower.includes('pgrst') ||
    lower.includes('duplicate key') ||
    lower.includes('violates') ||
    lower.includes('syntax error') ||
    lower.includes('relation ') ||
    lower.includes('column ') ||
    lower.includes('schema ') ||
    lower.includes('sqlstate') ||
    /\b[0-9a-f]{8}-[0-9a-f]{4}-/.test(lower)
  )
}

/** Maps Supabase and Postgres failures to copy that is safe to show in the UI. */
export function friendlyError(error: AppError | null | undefined, fallback = FALLBACK): string {
  if (!error) return fallback
  const code = (error.code ?? '').trim()
  const raw = text(error)
  const lower = raw.toLowerCase()

  if (
    code === '23505' &&
    (lower.includes('username') || lower.includes('profiles_username'))
  ) {
    return 'Username already taken'
  }
  if (code === '23505') return 'That value is already in use.'
  if (code === '23503') return 'That record is still linked to other data.'
  if (code === '23502') return 'A required field is missing.'
  if (code === '42501' || lower.includes('row-level security') || lower.includes('permission denied')) {
    return 'You do not have permission to do that.'
  }

  if (code === 'invalid_credentials' || lower.includes('invalid login credentials')) {
    return 'Email or password is incorrect.'
  }
  if (
    code === 'over_email_send_rate_limit' ||
    lower.includes('over_email_send_rate_limit') ||
    lower.includes('email rate limit')
  ) {
    return 'Too many emails were sent. Wait a minute and try again.'
  }
  if (
    code === 'user_already_exists' ||
    lower.includes('already registered') ||
    lower.includes('already been registered') ||
    lower.includes('user already exists')
  ) {
    return 'An account with this email already exists. Log in instead.'
  }
  if (lower.includes('username') && (lower.includes('unique') || lower.includes('duplicate') || lower.includes('taken'))) {
    return 'Username already taken'
  }
  if (
    code === 'otp_expired' ||
    lower.includes('token has expired') ||
    lower.includes('otp has expired') ||
    (lower.includes('token') && lower.includes('invalid'))
  ) {
    return 'That code is invalid or expired. Request a new one.'
  }
  if (
    lower.includes('failed to fetch') ||
    lower.includes('network request failed') ||
    lower.includes('networkerror') ||
    lower.includes('fetch failed') ||
    lower.includes('load failed') ||
    lower.includes('network error') ||
    code === 'network_error'
  ) {
    return 'Network problem. Check your connection and try again.'
  }
  if (lower.includes('jwt') || lower === 'not authenticated') {
    return 'Your session expired. Sign in again.'
  }

  if (!raw || looksTechnical(raw)) return fallback
  return raw
}
