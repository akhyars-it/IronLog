<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/authStore'
import type { Gender, ProfileWrite } from '../types/database'

const auth = useAuthStore()
const router = useRouter()

const step = ref(0)
const submitting = ref(false)
const errorMessage = ref('')

const email = ref('')
const password = ref('')
const username = ref('')
const fullName = ref('')
const gender = ref<Gender>('male')
const birthDate = ref('')
const height = ref('')
const weight = ref('')
const bodyFat = ref('')
const targetWeight = ref('')

const acceptedPrivacy = ref(false)
const otp = ref('')
const cooldown = ref(0)
let cooldownTimer: number | null = null

const genders: Gender[] = ['male', 'female', 'other']
const today = new Date().toISOString().slice(0, 10)

const titles = ['Account', 'About you', 'Body', 'Verify']
const progress = computed(() => ((step.value + 1) / titles.length) * 100)

onUnmounted(() => {
  if (cooldownTimer != null) window.clearInterval(cooldownTimer)
})

function startCooldown() {
  cooldown.value = 60
  if (cooldownTimer != null) window.clearInterval(cooldownTimer)
  cooldownTimer = window.setInterval(() => {
    cooldown.value -= 1
    if (cooldown.value <= 0 && cooldownTimer != null) {
      window.clearInterval(cooldownTimer)
      cooldownTimer = null
    }
  }, 1000)
}

function profileInput(): ProfileWrite | null {
  const heightCm = positiveNumber(height.value)
  const weightKg = positiveNumber(weight.value)
  const targetWeightKg = positiveNumber(targetWeight.value)
  if (heightCm == null || weightKg == null || targetWeightKg == null) return null
  return {
    username: username.value,
    fullName: fullName.value,
    gender: gender.value,
    birthDate: birthDate.value,
    heightCm,
    weightKg,
    targetWeightKg,
    bodyFatPercent: bodyFat.value.trim() ? Number(bodyFat.value) : null,
    bio: null,
  }
}

function positiveNumber(value: string): number | null {
  if (!value.trim()) return null
  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed <= 0) return null
  return parsed
}

function validateStep(): string | null {
  if (step.value === 0) {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value.trim())) return 'Enter a valid email'
    if (password.value.length < 6) return 'Password must be at least 6 characters'
    if (!username.value.trim()) return 'Username is required'
    return null
  }
  if (step.value === 1) {
    if (!fullName.value.trim()) return 'Full name is required'
    if (!birthDate.value) return 'Birth date is required'
    if (birthDate.value > today) return 'Birth date cannot be in the future'
    return null
  }
  if (!positiveNumber(height.value)) return 'Enter your height in centimetres'
  if (!positiveNumber(weight.value)) return 'Enter your weight in kilograms'
  if (!positiveNumber(targetWeight.value)) return 'Enter a target weight in kilograms'
  if (bodyFat.value.trim()) {
    const fat = Number(bodyFat.value)
    if (!Number.isFinite(fat) || fat < 0 || fat > 100) return 'Body fat must be between 0 and 100'
  }
  if (!acceptedPrivacy.value) return 'Agree to the privacy policy before continuing'
  return null
}

function next() {
  errorMessage.value = ''
  const problem = validateStep()
  if (problem) {
    errorMessage.value = problem
    return
  }
  if (step.value < 2) step.value += 1
  else void finish()
}

async function finish() {
  const input = profileInput()
  if (!input) return

  submitting.value = true
  const result = await auth.register({
    email: email.value,
    password: password.value,
    ...input,
  })
  submitting.value = false
  if (!result.ok) {
    errorMessage.value = result.message
    return
  }
  if (result.needsVerification) {
    step.value = 3
    otp.value = ''
    startCooldown()
    return
  }
  await router.replace({ name: 'dashboard' })
}

async function verify() {
  errorMessage.value = ''
  const input = profileInput()
  if (!input) return
  if (!/^\d{6}$/.test(otp.value.trim())) {
    errorMessage.value = 'Enter the 6-digit code'
    return
  }
  submitting.value = true
  const error = await auth.verifySignupCode(email.value, otp.value, input)
  submitting.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  await router.replace({ name: 'dashboard' })
}

async function resend() {
  if (cooldown.value > 0 || submitting.value) return
  errorMessage.value = ''
  submitting.value = true
  const error = await auth.resendSignupCode(email.value)
  submitting.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  startCooldown()
}
</script>

<template>
  <div class="mx-auto flex min-h-dvh w-full max-w-md flex-col bg-zinc-950 pt-[env(safe-area-inset-top)] pb-[env(safe-area-inset-bottom)] text-zinc-100">
    <header class="px-6 pt-6">
      <div class="flex items-center justify-between text-sm">
        <RouterLink class="text-zinc-400" :to="{ name: 'login' }">Back</RouterLink>
        <span class="text-zinc-500">{{ titles[step] }} · {{ step + 1 }}/4</span>
      </div>
      <div class="mt-4 h-1 overflow-hidden rounded-full bg-zinc-800">
        <div class="h-full bg-blue-500" :style="{ width: `${progress}%` }" />
      </div>
      <h1 class="mt-6 text-2xl font-semibold tracking-tight">
        {{ step === 3 ? 'Verify your email' : 'Create your account' }}
      </h1>
    </header>

    <form v-if="step === 3" class="flex flex-1 flex-col px-6 pt-8" @submit.prevent="verify">
      <div class="rounded-3xl border border-white/15 bg-zinc-900/45 p-6 shadow-[0_8px_32px_rgba(0,0,0,0.45)] ring-1 ring-inset ring-white/5 backdrop-blur-2xl saturate-150">
        <p class="text-sm leading-relaxed text-zinc-300">
          We sent a 6-digit verification code to
          <span class="font-medium text-white">{{ email.trim() }}</span>
        </p>
        <label class="mt-5 flex flex-col gap-1.5 text-sm">
          Verification code
          <input
            v-model="otp"
            inputmode="numeric"
            autocomplete="one-time-code"
            maxlength="6"
            class="field text-center font-mono text-3xl tracking-[0.4em]"
            placeholder="000000"
          />
        </label>
        <p v-if="errorMessage" class="mt-4 text-sm text-red-500">{{ errorMessage }}</p>
        <button
          type="submit"
          class="mt-5 w-full rounded-xl bg-blue-500 py-3 font-semibold text-white disabled:opacity-60"
          :disabled="submitting"
        >
          {{ submitting ? 'Verifying…' : 'Verify & Continue' }}
        </button>
        <button
          type="button"
          class="mt-3 w-full py-2 text-sm text-zinc-300 disabled:text-zinc-600"
          :disabled="cooldown > 0 || submitting"
          @click="resend"
        >
          {{ cooldown > 0 ? `Resend code in ${cooldown}s` : 'Resend code' }}
        </button>
      </div>
    </form>

    <form v-else class="flex flex-1 flex-col px-6 pt-8" @submit.prevent="next">
      <div v-if="step === 0" class="flex flex-col gap-4">
        <label class="flex flex-col gap-1.5 text-sm">
          Email
          <input v-model="email" type="email" autocomplete="email" class="field" />
        </label>
        <label class="flex flex-col gap-1.5 text-sm">
          Password
          <input v-model="password" type="password" autocomplete="new-password" class="field" />
        </label>
        <label class="flex flex-col gap-1.5 text-sm">
          Username
          <input v-model="username" type="text" autocomplete="username" class="field" />
        </label>
      </div>

      <div v-else-if="step === 1" class="flex flex-col gap-4">
        <label class="flex flex-col gap-1.5 text-sm">
          Full name
          <input v-model="fullName" type="text" autocomplete="name" class="field" />
        </label>
        <fieldset>
          <legend class="text-sm text-zinc-300">Gender</legend>
          <div class="mt-2 flex gap-2">
            <button
              v-for="option in genders"
              :key="option"
              type="button"
              class="rounded-full px-4 py-2 text-sm capitalize"
              :class="gender === option ? 'bg-blue-500 text-white' : 'bg-zinc-900 text-zinc-400'"
              @click="gender = option"
            >
              {{ option }}
            </button>
          </div>
        </fieldset>
        <label class="flex flex-col gap-1.5 text-sm">
          Birth date
          <input v-model="birthDate" type="date" :max="today" class="field" />
        </label>
      </div>

      <div v-else class="flex flex-col gap-4">
        <div class="grid grid-cols-2 gap-3">
          <label class="flex flex-col gap-1.5 text-sm">
            Height (cm)
            <input v-model="height" inputmode="decimal" class="field" />
          </label>
          <label class="flex flex-col gap-1.5 text-sm">
            Weight (kg)
            <input v-model="weight" inputmode="decimal" class="field" />
          </label>
        </div>
        <label class="flex flex-col gap-1.5 text-sm">
          Body fat % <span class="text-zinc-500">(optional)</span>
          <input v-model="bodyFat" inputmode="decimal" class="field" />
        </label>
        <label class="flex flex-col gap-1.5 text-sm">
          Target weight (kg)
          <input v-model="targetWeight" inputmode="decimal" class="field" />
        </label>
        <label class="flex items-start gap-3 text-sm text-zinc-300">
          <input v-model="acceptedPrivacy" type="checkbox" class="mt-1 size-4 accent-blue-500" required />
          <span>
            I agree to the
            <RouterLink class="font-medium text-blue-400" :to="{ name: 'privacy' }">Privacy Policy</RouterLink>
            and consent to IronLog storing my height, weight, and body-fat percentage to calculate BMI, FFMI, and training stats.
          </span>
        </label>
      </div>

      <p v-if="errorMessage" class="mt-4 text-sm text-red-500">{{ errorMessage }}</p>

      <div class="mt-auto flex gap-3 py-6">
        <button
          v-if="step > 0"
          type="button"
          class="rounded-xl px-4 py-3 text-zinc-300"
          @click="step -= 1"
        >
          Back
        </button>
        <button
          type="submit"
          class="flex-1 rounded-xl bg-blue-500 py-3 font-semibold text-white disabled:opacity-60"
          :disabled="submitting"
        >
          {{ step === 2 ? (submitting ? 'Creating…' : 'Finish') : 'Next' }}
        </button>
      </div>
    </form>
  </div>
</template>

<style scoped>
.field {
  border-radius: 0.75rem;
  border: 1px solid #27272a;
  background: #18181b;
  padding: 0.75rem;
  outline: none;
}
.field:focus {
  border-color: #3b82f6;
}
</style>
