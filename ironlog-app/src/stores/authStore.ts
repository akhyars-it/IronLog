import type { Session } from '@supabase/supabase-js'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { supabase } from '../lib/supabase'
import type { Profile, ProfileWrite } from '../types/database'
import { friendlyError } from '../utils/errorHandler'

export type RegisterOutcome =
  | { ok: true; needsVerification: boolean }
  | { ok: false; message: string }

function profileRow(userId: string, email: string | null, input: ProfileWrite) {
  return {
    id: userId,
    email,
    username: input.username.trim().toLowerCase(),
    full_name: input.fullName.trim() || null,
    gender: input.gender,
    birth_date: input.birthDate,
    height: input.heightCm,
    current_weight: input.weightKg,
    target_weight: input.targetWeightKg,
    current_body_fat: input.bodyFatPercent,
    bio: input.bio?.trim() || null,
  }
}

export const useAuthStore = defineStore('auth', () => {
  const session = ref<Session | null>(null)
  const profile = ref<Profile | null>(null)
  const initialized = ref(false)
  let initializeTask: Promise<void> | null = null

  const user = computed(() => session.value?.user ?? null)

  async function refreshProfile() {
    const userId = user.value?.id
    if (!userId) {
      profile.value = null
      return
    }

    const { data, error } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle()
    if (error) {
      profile.value = null
      return
    }
    profile.value = (data as Profile | null) ?? null
  }

  async function initialize() {
    if (initialized.value) return
    if (!initializeTask) {
      initializeTask = (async () => {
        const { data } = await supabase.auth.getSession()
        session.value = data.session
        if (session.value) await refreshProfile()

        supabase.auth.onAuthStateChange((_event, next) => {
          session.value = next
          if (next) {
            void refreshProfile()
          } else {
            profile.value = null
          }
        })
        initialized.value = true
      })()
    }
    await initializeTask
  }

  async function signIn(email: string, password: string): Promise<string | null> {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    })
    if (error) return friendlyError(error)
    session.value = data.session
    await refreshProfile()
    return null
  }

  async function requestPasswordReset(email: string): Promise<string | null> {
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim())
    return error ? friendlyError(error) : null
  }

  async function completePasswordReset(email: string, token: string, newPassword: string): Promise<string | null> {
    const code = token.trim()
    const address = email.trim()
    if (!/^\d{6}$/.test(code)) return 'Enter the 6-digit code'
    if (newPassword.length < 6) return 'Use a password with at least 6 characters'

    const alreadySignedIn = session.value?.user.email?.toLowerCase() === address.toLowerCase()
    if (!alreadySignedIn) {
      const verified = await supabase.auth.verifyOtp({
        email: address,
        token: code,
        type: 'recovery',
      })
      if (verified.error) return friendlyError(verified.error)
      if (!verified.data.session) return 'That code did not start a session. Request a new one.'
      session.value = verified.data.session
    }

    const updated = await supabase.auth.updateUser({ password: newPassword })
    if (updated.error) return friendlyError(updated.error)
    if (updated.data.user && session.value) {
      session.value = { ...session.value, user: updated.data.user }
    }
    await refreshProfile()
    return null
  }

  async function deleteAccount(): Promise<string | null> {
    const { error } = await supabase.rpc('delete_own_account')
    if (error) return friendlyError(error, 'Could not delete your account. Try again.')
    try {
      localStorage.removeItem('ironlog.activeWorkout.v1')
    } catch {
      /* The workout key is also cleared when the active session store resets. */
    }
    await signOut()
    return null
  }

  async function signOut() {
    try {
      await supabase.auth.signOut()
    } finally {
      session.value = null
      profile.value = null
    }
  }

  async function upsertProfile(input: ProfileWrite): Promise<string | null> {
    const current = user.value
    if (!current) return 'You need to be signed in.'
    if (!input.username.trim()) return 'Username is required'

    const { error } = await supabase
      .from('profiles')
      .upsert(profileRow(current.id, current.email ?? null, input))
    if (error) return friendlyError(error)
    await refreshProfile()
    return null
  }

  async function usernameTaken(username: string): Promise<boolean> {
    const name = username.trim().toLowerCase()
    if (!name) return false
    const { data, error } = await supabase.from('profiles').select('id').eq('username', name).maybeSingle()
    if (error || !data) return false
    return true
  }

  async function register(input: ProfileWrite & { email: string; password: string }): Promise<RegisterOutcome> {
    if (!input.username.trim()) return { ok: false, message: 'Username is required' }

    if (session.value) {
      const saved = await upsertProfile(input)
      return saved ? { ok: false, message: saved } : { ok: true, needsVerification: false }
    }

    if (await usernameTaken(input.username)) return { ok: false, message: 'Username already taken' }

    const email = input.email.trim()
    const username = input.username.trim().toLowerCase()
    const { data, error } = await supabase.auth.signUp({
      email,
      password: input.password,
      options: {
        data: {
          username,
          full_name: input.fullName.trim(),
          gender: input.gender,
          birth_date: input.birthDate,
          height: input.heightCm,
          current_weight: input.weightKg,
          target_weight: input.targetWeightKg,
          current_body_fat: input.bodyFatPercent,
        },
      },
    })
    if (error) return { ok: false, message: friendlyError(error) }

    const identities = data.user?.identities
    if (data.user && identities && identities.length === 0) {
      return { ok: false, message: 'An account with this email already exists. Log in instead.' }
    }

    if (data.user && !data.session) return { ok: true, needsVerification: true }

    if (!data.session) {
      return { ok: false, message: 'Account created, but there is no session yet. Enter the email code to continue.' }
    }

    session.value = data.session
    const saved = await upsertProfile(input)
    return saved ? { ok: false, message: saved } : { ok: true, needsVerification: false }
  }

  async function verifySignupCode(
    email: string,
    token: string,
    input: ProfileWrite,
  ): Promise<string | null> {
    const code = token.trim()
    if (!/^\d{6}$/.test(code)) return 'Enter the 6-digit code'
    const { data, error } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: code,
      type: 'signup',
    })
    if (error) return friendlyError(error)
    if (!data.session) return 'That code did not start a session. Request a new one.'
    session.value = data.session
    await refreshProfile()
    return upsertProfile(input)
  }

  async function resendSignupCode(email: string): Promise<string | null> {
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: email.trim(),
    })
    return error ? friendlyError(error) : null
  }

  async function updateBodyFat(percent: number): Promise<string | null> {
    const userId = user.value?.id
    if (!userId) return 'You need to be signed in.'
    const { error } = await supabase.from('profiles').update({ current_body_fat: percent }).eq('id', userId)
    if (error) return friendlyError(error)
    await refreshProfile()
    return null
  }

  async function updateAvatarUrl(avatarUrl: string): Promise<string | null> {
    const userId = user.value?.id
    if (!userId) return 'You need to be signed in.'
    const { error } = await supabase.from('profiles').update({ avatar_url: avatarUrl }).eq('id', userId)
    if (error) return friendlyError(error)
    await refreshProfile()
    return null
  }

  return {
    session,
    profile,
    user,
    initialized,
    initialize,
    refreshProfile,
    signIn,
    requestPasswordReset,
    completePasswordReset,
    deleteAccount,
    signOut,
    upsertProfile,
    register,
    verifySignupCode,
    resendSignupCode,
    updateBodyFat,
    updateAvatarUrl,
  }
})
