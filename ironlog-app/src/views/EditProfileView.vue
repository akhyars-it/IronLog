<script setup lang="ts">
import { computed, defineAsyncComponent, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import AvatarUploader from '../components/AvatarUploader.vue'
import GlassBackButton from '../components/GlassBackButton.vue'
import { useActiveWorkoutStore } from '../stores/activeWorkoutStore'
import { useAuthStore } from '../stores/authStore'
import { useExerciseStore } from '../stores/exerciseStore'
import { useHistoryStore } from '../stores/historyStore'
import { useRoutineStore } from '../stores/routineStore'
import type { Gender } from '../types/database'
import { calculateBMI, calculateFFMI, calculateUSNavyBodyFat } from '../utils/fitnessMath'

const demoSeedEnabled = import.meta.env.DEV || import.meta.env.VITE_ENABLE_DEMO_SEED === 'true'
const SeedDemoButton = demoSeedEnabled
  ? defineAsyncComponent(() => import('../components/SeedDemoButton.vue'))
  : null

const auth = useAuthStore()
const router = useRouter()
const activeWorkout = useActiveWorkoutStore()
const history = useHistoryStore()
const exercises = useExerciseStore()
const routines = useRoutineStore()
const genders: Gender[] = ['male', 'female', 'other']
const today = new Date().toISOString().slice(0, 10)

const form = reactive({
  username: '',
  fullName: '',
  bio: '',
  gender: 'male' as Gender,
  birthDate: '',
  height: '',
  weight: '',
  targetWeight: '',
  bodyFat: '',
})

const saving = ref(false)
const message = ref('')
const errorMessage = ref('')

const calculatorOpen = ref(false)
const deleteOpen = ref(false)
const deleteConfirm = ref('')
const deleting = ref(false)
const waist = ref('')
const neck = ref('')
const hip = ref('')
const calculatorError = ref('')

function fillFromProfile() {
  const profile = auth.profile
  if (!profile) return
  form.username = profile.username
  form.fullName = profile.full_name ?? ''
  form.bio = profile.bio ?? ''
  form.gender = profile.gender
  form.birthDate = profile.birth_date ?? ''
  form.height = profile.height?.toString() ?? ''
  form.weight = profile.current_weight?.toString() ?? ''
  form.targetWeight = profile.target_weight?.toString() ?? ''
  form.bodyFat = profile.current_body_fat?.toString() ?? ''
}

watch(() => auth.profile, fillFromProfile, { immediate: true })

function optionalPositive(value: string): number | null | undefined {
  if (!value.trim()) return null
  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed <= 0) return undefined
  return parsed
}

const preview = computed(() => {
  const weight = Number(form.weight)
  const height = Number(form.height)
  const fat = Number(form.bodyFat)
  return {
    bmi: calculateBMI(weight, height),
    ffmi: calculateFFMI(weight, height, fat),
  }
})

async function save() {
  message.value = ''
  errorMessage.value = ''
  if (!form.username.trim()) {
    errorMessage.value = 'Username is required'
    return
  }
  const height = optionalPositive(form.height)
  const weight = optionalPositive(form.weight)
  const target = optionalPositive(form.targetWeight)
  if (height === undefined || weight === undefined || target === undefined) {
    errorMessage.value = 'Height, weight, and target weight must be numbers greater than zero'
    return
  }
  let bodyFat: number | null = null
  if (form.bodyFat.trim()) {
    bodyFat = Number(form.bodyFat)
    if (!Number.isFinite(bodyFat) || bodyFat < 0 || bodyFat > 100) {
      errorMessage.value = 'Body fat must be between 0 and 100'
      return
    }
  }
  if (form.birthDate && form.birthDate > today) {
    errorMessage.value = 'Birth date cannot be in the future'
    return
  }

  saving.value = true
  const error = await auth.upsertProfile({
    username: form.username,
    fullName: form.fullName,
    gender: form.gender,
    birthDate: form.birthDate || null,
    heightCm: height,
    weightKg: weight,
    targetWeightKg: target,
    bodyFatPercent: bodyFat,
    bio: form.bio,
  })
  saving.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  message.value = 'Profile updated'
}

async function applyNavy() {
  calculatorError.value = ''
  const height = Number(form.height)
  const result = calculateUSNavyBodyFat({
    gender: form.gender,
    heightCm: height,
    waistCm: Number(waist.value),
    neckCm: Number(neck.value),
    hipCm: form.gender === 'female' ? Number(hip.value) : null,
  })
  if (result == null) {
    calculatorError.value =
      form.gender === 'female'
        ? 'Check height, and make sure waist is larger than neck and waist + hip is larger than neck.'
        : form.gender === 'male'
          ? 'Check height, and make sure waist is larger than neck.'
          : 'The Navy formula applies to male or female profiles.'
    return
  }
  form.bodyFat = result.toFixed(1)
  const saved = await auth.updateBodyFat(result)
  if (saved) {
    calculatorError.value = saved
    return
  }
  calculatorOpen.value = false
  message.value = `Body fat updated to ${result.toFixed(1)}%`
}

function openDelete() {
  deleteConfirm.value = ''
  errorMessage.value = ''
  deleteOpen.value = true
}

async function confirmDelete() {
  errorMessage.value = ''
  if (deleteConfirm.value !== 'DELETE') {
    errorMessage.value = 'Type DELETE to confirm'
    return
  }
  deleting.value = true
  const error = await auth.deleteAccount()
  deleting.value = false
  if (error) {
    errorMessage.value = error
    return
  }
  activeWorkout.clear()
  history.reset()
  exercises.reset()
  routines.reset()
  try {
    for (const key of Object.keys(localStorage)) {
      if (key.startsWith('sb-') || key.startsWith('ironlog.')) localStorage.removeItem(key)
    }
  } catch {
    /* Storage may be unavailable inside a restricted webview. */
  }
  deleteOpen.value = false
  await router.replace({ name: 'login' })
}
</script>

<template>
  <section class="px-5 pt-8 pb-10">
    <GlassBackButton to="/" label="Back to dashboard" />
    <h1 class="text-2xl font-semibold tracking-tight">Edit profile</h1>
    <p class="mt-1 text-sm text-zinc-400">{{ auth.user?.email }}</p>

    <div class="mt-6">
      <AvatarUploader
        v-if="auth.user && auth.profile"
        :user-id="auth.user.id"
        :url="auth.profile.avatar_url"
      />
      <p v-else class="text-sm text-zinc-500">Save your profile before adding a photo.</p>
    </div>

    <form class="mt-8 flex flex-col gap-4" @submit.prevent="save">
      <label class="flex flex-col gap-1.5 text-sm">
        Username
        <input v-model="form.username" class="field" autocomplete="username" />
      </label>
      <label class="flex flex-col gap-1.5 text-sm">
        Full name
        <input v-model="form.fullName" class="field" autocomplete="name" />
      </label>
      <label class="flex flex-col gap-1.5 text-sm">
        Bio
        <textarea v-model="form.bio" rows="3" class="field" />
      </label>

      <fieldset>
        <legend class="text-sm">Gender</legend>
        <div class="mt-2 flex gap-2">
          <button
            v-for="option in genders"
            :key="option"
            type="button"
            class="rounded-full px-4 py-2 text-sm capitalize"
            :class="form.gender === option ? 'bg-blue-500 text-white' : 'bg-zinc-900 text-zinc-400'"
            @click="form.gender = option"
          >
            {{ option }}
          </button>
        </div>
      </fieldset>

      <label class="flex flex-col gap-1.5 text-sm">
        Birth date
        <input v-model="form.birthDate" type="date" :max="today" class="field" />
      </label>

      <div class="grid grid-cols-2 gap-3">
        <label class="flex flex-col gap-1.5 text-sm">
          Height (cm)
          <input v-model="form.height" inputmode="decimal" class="field" />
        </label>
        <label class="flex flex-col gap-1.5 text-sm">
          Weight (kg)
          <input v-model="form.weight" inputmode="decimal" class="field" />
        </label>
        <label class="flex flex-col gap-1.5 text-sm">
          Goal weight (kg)
          <input v-model="form.targetWeight" inputmode="decimal" class="field" />
        </label>
        <label class="flex flex-col gap-1.5 text-sm">
          Body fat %
          <input v-model="form.bodyFat" inputmode="decimal" class="field" />
        </label>
      </div>

      <button type="button" class="text-left text-sm font-medium text-orange-400" @click="calculatorOpen = true">
        Open Navy body-fat calculator
      </button>

      <p class="text-sm text-zinc-400">
        BMI {{ preview.bmi ? `${preview.bmi.bmi.toFixed(1)} · ${preview.bmi.category}` : '—' }}
        · FFMI {{ preview.ffmi ? preview.ffmi.toFixed(1) : '—' }}
      </p>

      <p v-if="errorMessage" class="text-sm text-red-500">{{ errorMessage }}</p>
      <p v-if="message" class="text-sm text-emerald-400">{{ message }}</p>

      <button
        type="submit"
        class="rounded-xl bg-blue-500 py-3 font-semibold text-white disabled:opacity-60"
        :disabled="saving"
      >
        {{ saving ? 'Saving…' : 'Save profile' }}
      </button>
    </form>

    <RouterLink class="mt-8 block text-sm text-zinc-500" :to="{ name: 'privacy' }">Privacy policy</RouterLink>

    <section v-if="demoSeedEnabled && SeedDemoButton" class="mt-10 border-t border-white/10 pt-6">
      <p class="text-[10px] font-semibold tracking-[0.18em] text-zinc-600">DEVELOPER TOOLS</p>
      <div class="mt-3">
        <SeedDemoButton />
      </div>
    </section>

    <section class="mt-10 rounded-3xl border border-red-500/40 bg-red-500/10 p-5">
      <h2 class="text-sm font-semibold text-red-500">Delete Account</h2>
      <p class="mt-2 text-sm leading-relaxed text-zinc-300">
        Permanently deletes your profile, body metrics, workout logs, routines, and avatar. This cannot be undone.
      </p>
      <button
        type="button"
        class="mt-4 w-full rounded-xl bg-red-600 py-3 font-semibold text-white hover:bg-red-500"
        @click="openDelete"
      >
        Delete Account
      </button>
    </section>

    <div
      v-if="calculatorOpen"
      class="fixed inset-0 z-30 grid place-items-end bg-black/70"
      @click.self="calculatorOpen = false"
    >
      <form
        class="w-full max-w-md rounded-t-3xl bg-zinc-900 p-6"
        role="dialog"
        aria-modal="true"
        aria-labelledby="navy-title"
        @submit.prevent="applyNavy"
      >
        <h2 id="navy-title" class="text-lg font-semibold">Navy body-fat calculator</h2>
        <p class="mt-1 text-sm text-zinc-400">
          Tape measurements in centimetres. Height and gender come from this form.
        </p>
        <label class="mt-4 flex flex-col gap-1.5 text-sm">
          Waist (cm)
          <input v-model="waist" inputmode="decimal" class="field" />
        </label>
        <label class="mt-3 flex flex-col gap-1.5 text-sm">
          Neck (cm)
          <input v-model="neck" inputmode="decimal" class="field" />
        </label>
        <label v-if="form.gender === 'female'" class="mt-3 flex flex-col gap-1.5 text-sm">
          Hips (cm)
          <input v-model="hip" inputmode="decimal" class="field" />
        </label>
        <p v-if="calculatorError" class="mt-3 text-sm text-red-500">{{ calculatorError }}</p>
        <div class="mt-5 flex gap-3">
          <button type="button" class="flex-1 py-3 text-zinc-300" @click="calculatorOpen = false">Cancel</button>
          <button type="submit" class="flex-1 rounded-xl bg-blue-500 py-3 font-semibold text-white">
            Calculate and update
          </button>
        </div>
      </form>
    </div>

    <div
      v-if="deleteOpen"
      class="fixed inset-0 z-30 grid place-items-end bg-black/70"
      @click.self="deleteOpen = false"
    >
      <form
        class="w-full max-w-md rounded-t-3xl border border-red-500/30 bg-zinc-900/80 p-6 shadow-[0_8px_32px_rgba(0,0,0,0.45)] ring-1 ring-inset ring-white/5 backdrop-blur-2xl"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-title"
        @submit.prevent="confirmDelete"
      >
        <h2 id="delete-title" class="text-lg font-semibold text-red-500">Delete Account</h2>
        <p class="mt-2 text-sm leading-relaxed text-zinc-300">
          This removes your account and every workout, routine, and photo stored for it. Type DELETE to confirm.
        </p>
        <label class="mt-4 flex flex-col gap-1.5 text-sm">
          Confirmation
          <input
            v-model="deleteConfirm"
            autocomplete="off"
            class="field"
            placeholder="DELETE"
          />
        </label>
        <p v-if="errorMessage" class="mt-3 text-sm text-red-500">{{ errorMessage }}</p>
        <div class="mt-5 flex gap-3">
          <button type="button" class="flex-1 py-3 text-zinc-300" @click="deleteOpen = false">Cancel</button>
          <button
            type="submit"
            class="flex-1 rounded-xl bg-red-600 py-3 font-semibold text-white hover:bg-red-500 disabled:opacity-60"
            :disabled="deleting || deleteConfirm !== 'DELETE'"
          >
            {{ deleting ? 'Deleting…' : 'Delete Account' }}
          </button>
        </div>
      </form>
    </div>
  </section>
</template>

<style scoped>
.field {
  width: 100%;
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
