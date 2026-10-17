import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const memory = new Map<string, string>()

function query() {
  const builder: Record<string, unknown> = {}
  const self = () => builder
  for (const method of ['select', 'eq', 'order', 'limit', 'update', 'insert']) builder[method] = self
  builder.upsert = () => Promise.resolve({ error: null })
  builder.maybeSingle = () => Promise.resolve({ data: null, error: null })
  builder.single = () => Promise.resolve({ data: null, error: null })
  builder.then = (resolve: (value: unknown) => unknown, reject?: (reason: unknown) => unknown) =>
    Promise.resolve({ data: null, error: null }).then(resolve, reject)
  return builder
}

const signInWithPassword = vi.fn()
const resetPasswordForEmail = vi.fn()
const verifyOtp = vi.fn()
const updateUser = vi.fn()
const signOut = vi.fn()
const rpc = vi.fn()

vi.mock('../../lib/supabase', () => ({
  supabase: {
    auth: {
      signInWithPassword: (...args: unknown[]) => signInWithPassword(...args),
      resetPasswordForEmail: (...args: unknown[]) => resetPasswordForEmail(...args),
      verifyOtp: (...args: unknown[]) => verifyOtp(...args),
      updateUser: (...args: unknown[]) => updateUser(...args),
      signOut: (...args: unknown[]) => signOut(...args),
      getSession: vi.fn(async () => ({ data: { session: null } })),
      onAuthStateChange: vi.fn(),
      resend: vi.fn(async () => ({ error: { code: 'over_email_send_rate_limit', message: 'email rate limit exceeded' } })),
      signUp: vi.fn(),
    },
    from: () => query(),
    rpc: (...args: unknown[]) => rpc(...args),
  },
}))

const user = {
  id: '11111111-1111-4111-8111-111111111111',
  email: 'lifter@example.com',
  app_metadata: {},
  user_metadata: {},
  aud: 'authenticated',
  created_at: '2026-01-01T00:00:00.000Z',
}

const session = {
  access_token: 'token',
  refresh_token: 'refresh',
  expires_in: 3600,
  expires_at: 9_999_999_999,
  token_type: 'bearer',
  user,
}

describe('authStore', () => {
  beforeEach(() => {
    memory.clear()
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => memory.get(key) ?? null,
      setItem: (key: string, value: string) => memory.set(key, value),
      removeItem: (key: string) => memory.delete(key),
      clear: () => memory.clear(),
    })
    signInWithPassword.mockReset()
    resetPasswordForEmail.mockReset()
    verifyOtp.mockReset()
    updateUser.mockReset()
    signOut.mockReset()
    rpc.mockReset()
    signOut.mockResolvedValue({ error: null })
    setActivePinia(createPinia())
  })

  it('signs in and stores the session', async () => {
    signInWithPassword.mockResolvedValue({ data: { session, user }, error: null })
    const { useAuthStore } = await import('../authStore')
    const auth = useAuthStore()
    await expect(auth.signIn('lifter@example.com', 'secret1')).resolves.toBeNull()
    expect(auth.user?.id).toBe(user.id)
  })

  it('sanitizes invalid credentials', async () => {
    signInWithPassword.mockResolvedValue({
      data: { session: null, user: null },
      error: { code: 'invalid_credentials', message: 'Invalid login credentials' },
    })
    const { useAuthStore } = await import('../authStore')
    const auth = useAuthStore()
    await expect(auth.signIn('lifter@example.com', 'nope')).resolves.toBe('Email or password is incorrect.')
  })

  it('requests a recovery code without a redirect URL', async () => {
    resetPasswordForEmail.mockResolvedValue({ error: null })
    const { useAuthStore } = await import('../authStore')
    const auth = useAuthStore()
    await expect(auth.requestPasswordReset('lifter@example.com')).resolves.toBeNull()
    expect(resetPasswordForEmail).toHaveBeenCalledTimes(1)
    expect(resetPasswordForEmail.mock.calls[0]).toEqual(['lifter@example.com'])
  })

  it('verifies a recovery OTP and sets the new password', async () => {
    verifyOtp.mockResolvedValue({ data: { session, user }, error: null })
    updateUser.mockResolvedValue({ data: { user }, error: null })
    const { useAuthStore } = await import('../authStore')
    const auth = useAuthStore()
    await expect(auth.completePasswordReset('lifter@example.com', '123456', 'new-secret')).resolves.toBeNull()
    expect(verifyOtp).toHaveBeenCalledWith({
      email: 'lifter@example.com',
      token: '123456',
      type: 'recovery',
    })
    expect(updateUser).toHaveBeenCalledWith({ password: 'new-secret' })
    expect(auth.session?.user.email).toBe('lifter@example.com')
  })

  it('verifies a signup OTP', async () => {
    verifyOtp.mockResolvedValue({ data: { session, user }, error: null })
    const { useAuthStore } = await import('../authStore')
    const auth = useAuthStore()
    const error = await auth.verifySignupCode('lifter@example.com', '654321', {
      username: 'lifter',
      fullName: 'Lifter',
      gender: 'other',
      birthDate: '1990-01-01',
      heightCm: 180,
      weightKg: 80,
      targetWeightKg: 78,
      bodyFatPercent: null,
      bio: null,
    })
    expect(error).toBeNull()
    expect(verifyOtp).toHaveBeenCalledWith({
      email: 'lifter@example.com',
      token: '654321',
      type: 'signup',
    })
  })

  it('deletes the account and clears the session', async () => {
    signInWithPassword.mockResolvedValue({ data: { session, user }, error: null })
    rpc.mockResolvedValue({ error: null })
    const { useAuthStore } = await import('../authStore')
    const auth = useAuthStore()
    await auth.signIn('lifter@example.com', 'secret1')
    memory.set('ironlog.activeWorkout.v1', '{}')
    await expect(auth.deleteAccount()).resolves.toBeNull()
    expect(rpc).toHaveBeenCalledWith('delete_own_account')
    expect(signOut).toHaveBeenCalled()
    expect(auth.session).toBeNull()
    expect(memory.has('ironlog.activeWorkout.v1')).toBe(false)
  })

  it('sanitizes a failed account deletion', async () => {
    rpc.mockResolvedValue({
      error: { code: '42501', message: 'permission denied for function delete_own_account' },
    })
    const { useAuthStore } = await import('../authStore')
    const auth = useAuthStore()
    await expect(auth.deleteAccount()).resolves.toBe('You do not have permission to do that.')
    expect(auth.session).toBeNull()
  })
})
