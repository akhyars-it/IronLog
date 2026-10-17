<script setup lang="ts">
import { Eye, EyeOff } from 'lucide-vue-next'
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/authStore'

const auth = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const showPassword = ref(false)
const submitting = ref(false)
const errorMessage = ref('')

const resetOpen = ref(false)
const resetStep = ref<1 | 2>(1)
const resetEmail = ref('')
const resetCode = ref('')
const resetPassword = ref('')
const resetError = ref('')
const resetting = ref(false)

async function login() {
  errorMessage.value = ''
  if (!email.value.trim() || !password.value) {
    errorMessage.value = 'Please fill in all fields'
    return
  }
  submitting.value = true
  const error = await auth.signIn(email.value, password.value)
  submitting.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  await router.replace({ name: 'dashboard' })
}

function openReset() {
  resetEmail.value = email.value
  resetCode.value = ''
  resetPassword.value = ''
  resetError.value = ''
  resetStep.value = 1
  resetOpen.value = true
}

async function sendReset() {
  resetError.value = ''
  if (!resetEmail.value.trim()) {
    resetError.value = 'Enter email first'
    return
  }
  resetting.value = true
  const error = await auth.requestPasswordReset(resetEmail.value)
  resetting.value = false
  if (error) {
    resetError.value = error
    return
  }
  resetStep.value = 2
}

async function finishReset() {
  resetError.value = ''
  resetting.value = true
  const error = await auth.completePasswordReset(resetEmail.value, resetCode.value, resetPassword.value)
  resetting.value = false
  if (error) {
    resetError.value = error
    return
  }
  resetOpen.value = false
  await router.replace({ name: 'dashboard' })
}
</script>

<template>
  <div class="mx-auto flex min-h-dvh w-full max-w-md flex-col bg-zinc-950 px-6 pt-[calc(4rem+env(safe-area-inset-top))] pb-[calc(4rem+env(safe-area-inset-bottom))] text-zinc-100">
    <p class="text-xs font-semibold tracking-[0.2em] text-blue-400">IRONLOG</p>
    <h1 class="mt-3 text-3xl font-semibold tracking-tight">Log the work.</h1>
    <p class="mt-2 text-sm text-zinc-400">Sign in to pick up your training.</p>

    <form class="mt-10 flex flex-col gap-4" @submit.prevent="login">
      <label class="flex flex-col gap-1.5 text-sm">
        Email
        <input
          v-model="email"
          type="email"
          autocomplete="email"
          class="rounded-xl border border-zinc-800 bg-zinc-900 px-3 py-3 outline-none focus:border-blue-500"
        />
      </label>
      <label class="flex flex-col gap-1.5 text-sm">
        Password
        <span class="relative">
          <input
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="current-password"
            class="w-full rounded-xl border border-zinc-800 bg-zinc-900 px-3 py-3 pr-12 outline-none focus:border-blue-500"
          />
          <button
            type="button"
            class="absolute top-1/2 right-3 -translate-y-1/2 text-zinc-400"
            :aria-label="showPassword ? 'Hide password' : 'Show password'"
            @click="showPassword = !showPassword"
          >
            <EyeOff v-if="showPassword" :size="18" />
            <Eye v-else :size="18" />
          </button>
        </span>
      </label>

      <p v-if="errorMessage" class="text-sm text-red-500">{{ errorMessage }}</p>

      <button
        type="submit"
        class="mt-2 rounded-xl bg-blue-500 py-3 font-semibold text-white disabled:opacity-60"
        :disabled="submitting"
      >
        {{ submitting ? 'Signing in…' : 'Log in' }}
      </button>
    </form>

    <button type="button" class="mt-4 text-sm text-zinc-400" @click="openReset">Forgot password?</button>
    <RouterLink class="mt-6 text-sm font-medium text-blue-400" :to="{ name: 'register' }">
      Don't have an account? Create one
    </RouterLink>
    <RouterLink class="mt-4 text-sm text-zinc-500" :to="{ name: 'privacy' }">Privacy policy</RouterLink>

    <div
      v-if="resetOpen"
      class="fixed inset-0 z-30 grid place-items-end bg-black/70 sm:place-items-center"
      @click.self="resetOpen = false"
    >
      <form
        class="w-full max-w-md rounded-t-3xl border border-white/15 bg-zinc-900/45 p-6 shadow-[0_8px_32px_rgba(0,0,0,0.45)] ring-1 ring-inset ring-white/5 backdrop-blur-2xl saturate-150 sm:rounded-3xl"
        role="dialog"
        aria-modal="true"
        aria-labelledby="reset-title"
        @submit.prevent="resetStep === 1 ? sendReset() : finishReset()"
      >
        <h2 id="reset-title" class="text-lg font-semibold">Reset password</h2>
        <p v-if="resetStep === 1" class="mt-1 text-sm text-zinc-400">
          We'll email a 6-digit recovery code. Enter it here with your new password.
        </p>
        <p v-else class="mt-1 text-sm text-zinc-400">
          Enter the code sent to {{ resetEmail.trim() }} and choose a new password.
        </p>
        <label v-if="resetStep === 1" class="mt-4 flex flex-col gap-1.5 text-sm">
          Email
          <input
            v-model="resetEmail"
            type="email"
            autocomplete="email"
            class="rounded-xl border border-zinc-700 bg-zinc-950 px-3 py-3 outline-none focus:border-blue-500"
          />
        </label>
        <template v-else>
          <label class="mt-4 flex flex-col gap-1.5 text-sm">
            Recovery code
            <input
              v-model="resetCode"
              inputmode="numeric"
              autocomplete="one-time-code"
              maxlength="6"
              class="rounded-xl border border-zinc-700 bg-zinc-950 px-3 py-3 text-center font-mono text-2xl tracking-[0.4em] outline-none focus:border-blue-500"
              placeholder="000000"
            />
          </label>
          <label class="mt-4 flex flex-col gap-1.5 text-sm">
            New password
            <input
              v-model="resetPassword"
              type="password"
              autocomplete="new-password"
              class="rounded-xl border border-zinc-700 bg-zinc-950 px-3 py-3 outline-none focus:border-blue-500"
            />
          </label>
        </template>
        <p v-if="resetError" class="mt-3 text-sm text-red-500">{{ resetError }}</p>
        <div class="mt-5 flex gap-3">
          <button type="button" class="flex-1 rounded-xl py-3 text-zinc-300" @click="resetOpen = false">
            Close
          </button>
          <button
            type="submit"
            class="flex-1 rounded-xl bg-blue-500 py-3 font-semibold text-white disabled:opacity-60"
            :disabled="resetting"
          >
            {{ resetting ? 'Working…' : resetStep === 1 ? 'Send code' : 'Update password' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
