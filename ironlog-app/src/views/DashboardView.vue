<script setup lang="ts">
import type { ChartData } from 'chart.js'
import { Info, LogOut, User } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { Bar } from 'vue-chartjs'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { barOptions } from '../lib/charts'
import { useAuthStore } from '../stores/authStore'
import { useHistoryStore } from '../stores/historyStore'
import type { HistoryWorkout } from '../types/history'
import { startOfWeekMonday, toDateInput, toTimeInput } from '../utils/dates'
import { calculateBMI, calculateFFMI, calculateGoalProgress, calculateUSNavyBodyFat } from '../utils/fitnessMath'
import { buildWeekSeries } from '../utils/weekSeries'

const auth = useAuthStore()
const history = useHistoryStore()
const router = useRouter()
const route = useRoute()

const range = ref<30 | 90>(30)
const metric = ref<'volume' | 'sets'>('volume')
const showAll = ref(false)
const editing = ref<HistoryWorkout | null>(null)
const editDate = ref('')
const editStart = ref('')
const editEnd = ref('')
const pendingDelete = ref<HistoryWorkout | null>(null)
const actionError = ref('')
const navyOpen = ref(false)
const infoCard = ref<'bmi' | 'ffmi' | 'bench' | 'goal' | null>(null)
const confirmLogout = ref(false)
const navyHeight = ref('')
const waist = ref('')
const neck = ref('')
const hip = ref('')
const navyError = ref('')
const navySaving = ref(false)

onMounted(() => {
  void history.loadRecent()
})

const metrics = computed(() => {
  const profile = auth.profile
  if (!profile) return null
  const weight = profile.current_weight ?? 0
  const height = profile.height ?? 0
  const fat = profile.current_body_fat ?? 0
  const target = profile.target_weight ?? 0
  return {
    bmi: calculateBMI(weight, height),
    ffmi: calculateFFMI(weight, height, fat),
    goal: target > 0 ? calculateGoalProgress(weight, target) : null,
  }
})

const weeklySets = computed(() => {
  const monday = startOfWeekMonday(new Date())
  return history.recent
    .filter((workout) => new Date(workout.start_time) >= monday)
    .reduce((sum, workout) => sum + workout.total_sets, 0)
})

const chart = computed(() =>
  buildWeekSeries(
    history.recent.map((workout) => ({
      startTime: workout.start_time,
      totalVolume: workout.total_volume,
      totalSets: workout.total_sets,
    })),
    range.value,
    metric.value,
  ),
)

const chartData = computed<ChartData<'bar'>>(() => ({
  labels: chart.value.map((point) => point.label),
  datasets: [
    {
      data: chart.value.map((point) => point.value),
      backgroundColor: '#3b82f6',
      borderRadius: 6,
    },
  ],
}))

const visibleHistory = computed(() => (showAll.value ? history.recent : history.recent.slice(0, 3)))

function exerciseSummary(workout: HistoryWorkout): string {
  const names: string[] = []
  for (const set of workout.sets) {
    if (!names.includes(set.name)) names.push(set.name)
    if (names.length === 3) break
  }
  return names.join(' · ')
}

function openEdit(workout: HistoryWorkout) {
  const start = new Date(workout.start_time)
  const end = new Date(workout.end_time)
  editing.value = workout
  editDate.value = toDateInput(start)
  editStart.value = toTimeInput(start)
  editEnd.value = toTimeInput(end)
  actionError.value = ''
}

async function saveTimes() {
  const workout = editing.value
  if (!workout) return
  const start = new Date(`${editDate.value}T${editStart.value}`)
  const end = new Date(`${editDate.value}T${editEnd.value}`)
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    actionError.value = 'Enter a valid date and time.'
    return
  }
  actionError.value = (await history.updateTimes(workout.id, start, end)) ?? ''
  if (!actionError.value) editing.value = null
}

async function confirmDelete() {
  const workout = pendingDelete.value
  if (!workout) return
  actionError.value = (await history.removeWorkout(workout.id)) ?? ''
  if (!actionError.value) pendingDelete.value = null
}

function bmiClass(category: string | undefined): string {
  if (category === 'HEALTHY') return 'text-emerald-300'
  if (category === 'OVERWEIGHT') return 'text-orange-300'
  if (category === 'OBESE') return 'text-red-500'
  if (category === 'UNDERWEIGHT') return 'text-sky-300'
  return 'text-zinc-500'
}

function bodyFatAmount(): number | null {
  const amount = Number(auth.profile?.current_body_fat)
  return Number.isFinite(amount) && amount > 0 ? amount : null
}

function fatLabel(): string {
  const amount = bodyFatAmount()
  return amount == null ? 'CALCULATE' : `${amount.toFixed(1)}% FAT`
}

function bodyFatText(): string {
  const amount = bodyFatAmount()
  return amount == null ? 'not set' : `${amount.toFixed(1)}%`
}

function benchTier(ratio: number): string {
  if (ratio >= 2) return 'Elite'
  if (ratio >= 1.5) return 'Advanced'
  if (ratio >= 1) return 'Strong'
  return 'Building'
}

function openNavy() {
  navyHeight.value = auth.profile?.height ? String(auth.profile.height) : ''
  navyError.value = ''
  infoCard.value = null
  navyOpen.value = true
}

async function applyNavy() {
  const profile = auth.profile
  if (!profile) return
  navyError.value = ''
  const result = calculateUSNavyBodyFat({
    gender: profile.gender,
    heightCm: Number(navyHeight.value),
    waistCm: Number(waist.value),
    neckCm: Number(neck.value),
    hipCm: profile.gender === 'female' ? Number(hip.value) : null,
  })
  if (result == null) {
    navyError.value =
      profile.gender === 'other'
        ? 'The Navy formula needs male or female on your profile.'
        : 'Check the measurements. Waist must be larger than neck.'
    return
  }
  navySaving.value = true
  const error = await auth.updateBodyFat(result)
  navySaving.value = false
  if (error) {
    navyError.value = error
    return
  }
  navyOpen.value = false
}

async function signOut() {
  await auth.signOut()
  await router.replace({ name: 'login' })
}

function formatMinutes(seconds: number): string {
  return `${Math.max(1, Math.round(seconds / 60))} min`
}
</script>

<template>
  <section class="px-5 pt-8 pb-8">
    <div class="flex items-start gap-4">
      <button type="button" class="shrink-0" aria-label="Edit profile" @click="router.push('/profile/edit')">
        <img
          v-if="auth.profile?.avatar_url"
          :src="auth.profile.avatar_url"
          alt=""
          class="h-[84px] w-[84px] rounded-full border-2 border-blue-500/50 object-cover"
        />
        <span v-else class="grid h-[84px] w-[84px] place-items-center rounded-full border-2 border-blue-500/50 bg-zinc-900 text-zinc-500">
          <User :size="40" />
        </span>
      </button>
      <div class="min-w-0 flex-1">
        <div class="flex items-start justify-between gap-2">
          <h1 class="truncate text-xl font-bold">
            {{ auth.profile?.full_name || auth.profile?.username || 'Fitness Athlete' }}
          </h1>
          <div class="flex shrink-0 gap-2">
            <button
              type="button"
              class="grid h-9 w-9 place-items-center rounded-full border border-white/15 bg-zinc-900/60 text-zinc-200 backdrop-blur"
              aria-label="Profile settings"
              @click="router.push('/profile/edit')"
            >
              <User :size="16" />
            </button>
            <button
              type="button"
              class="grid h-9 w-9 place-items-center rounded-full border border-white/15 bg-zinc-900/60 text-zinc-200 backdrop-blur"
              aria-label="Log out"
              @click="confirmLogout = true"
            >
              <LogOut :size="16" />
            </button>
          </div>
        </div>
        <p v-if="auth.profile?.bio" class="mt-1 text-sm text-zinc-400">{{ auth.profile.bio }}</p>
        <p class="mt-2 inline-flex rounded-full bg-blue-500/15 px-2.5 py-1 text-[10px] font-black tracking-wide text-blue-400 shadow-[0_0_18px_rgba(59,130,246,0.45)]">
          {{ weeklySets }} SETS THIS WEEK
        </p>
      </div>
    </div>

    <p v-if="route.query.saved === '1'" class="mt-3 text-sm text-emerald-300">Workout saved.</p>

    <div class="mt-5 rounded-3xl border border-white/10 bg-white/5 p-4 backdrop-blur-xl">
      <div class="grid grid-cols-4 gap-1 text-center">
        <button type="button" class="min-w-0" @click="infoCard = 'bmi'">
          <span class="flex items-center justify-center gap-0.5 text-[10px] font-bold text-zinc-400">BMI <Info :size="11" /></span>
          <span class="mt-1 block text-lg font-bold">{{ metrics?.bmi ? metrics.bmi.bmi.toFixed(1) : '—' }}</span>
          <span class="text-[9px] font-black" :class="bmiClass(metrics?.bmi?.category)">{{ metrics?.bmi?.category ?? 'SET HEIGHT' }}</span>
        </button>
        <button type="button" class="min-w-0" @click="infoCard = 'ffmi'">
          <span class="flex items-center justify-center gap-0.5 text-[10px] font-bold text-zinc-400">FFMI <Info :size="11" /></span>
          <span class="mt-1 block text-lg font-bold">{{ metrics?.ffmi ? metrics.ffmi.toFixed(1) : '—' }}</span>
          <span class="text-[9px] font-black text-blue-400">{{ fatLabel() }}</span>
        </button>
        <button type="button" class="min-w-0" @click="infoCard = 'bench'">
          <span class="flex items-center justify-center gap-0.5 text-[10px] font-bold text-zinc-400">STRENGTH <Info :size="11" /></span>
          <span class="mt-1 block text-lg font-bold">{{ history.benchRatio ? `${history.benchRatio.ratio.toFixed(2)}x` : '—' }}</span>
          <span class="text-[9px] font-black text-blue-400">BENCH/BW</span>
        </button>
        <button type="button" class="min-w-0" @click="infoCard = 'goal'">
          <span class="flex items-center justify-center gap-0.5 text-[10px] font-bold text-zinc-400">GOAL <Info :size="11" /></span>
          <span class="mt-1 block text-lg font-bold">{{ auth.profile?.target_weight ? `${Math.round(auth.profile.target_weight)}kg` : '—' }}</span>
          <span class="text-[9px] font-semibold" :class="metrics?.goal ? 'text-red-500' : 'text-zinc-400'">
            {{ metrics?.goal ? `${metrics.goal.kilogramsLeft.toFixed(1)}kg LEFT` : 'SET TARGET' }}
          </span>
        </button>
      </div>
      <div v-if="metrics?.goal" class="mt-5 h-2 overflow-hidden rounded-full bg-black/30">
        <div
          class="h-full max-w-full rounded-full bg-red-500 shadow-[0_0_12px_rgba(239,68,68,0.85)]"
          :style="{ width: `${metrics.goal.progress * 100}%` }"
        ></div>
      </div>
    </div>

    <div class="mt-5 rounded-2xl border border-zinc-800 p-3">
      <div class="flex items-center justify-between gap-2">
        <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500">WEEKLY</p>
        <div class="flex gap-2 text-xs">
          <button type="button" :class="range === 30 ? 'text-blue-300' : 'text-zinc-500'" @click="range = 30">30d</button>
          <button type="button" :class="range === 90 ? 'text-blue-300' : 'text-zinc-500'" @click="range = 90">90d</button>
          <button type="button" :class="metric === 'volume' ? 'text-blue-300' : 'text-zinc-500'" @click="metric = 'volume'">
            Volume
          </button>
          <button type="button" :class="metric === 'sets' ? 'text-blue-300' : 'text-zinc-500'" @click="metric = 'sets'">
            Sets
          </button>
        </div>
      </div>
      <div class="mt-3 h-44">
        <Bar :data="chartData" :options="barOptions()" />
      </div>
    </div>

    <div class="mt-6 flex items-center justify-between">
      <h2 class="text-sm font-semibold">Training history</h2>
      <button v-if="history.recent.length > 3" type="button" class="text-xs text-blue-300" @click="showAll = !showAll">
        {{ showAll ? 'Show less' : 'See all' }}
      </button>
    </div>
    <p v-if="history.loading" class="mt-3 text-sm text-zinc-500">Loading…</p>
    <p v-else-if="history.recent.length === 0" class="mt-3 text-sm text-zinc-500">No workouts in the last 90 days.</p>
    <ul class="mt-3 flex flex-col gap-2">
      <li v-for="workout in visibleHistory" :key="workout.id" class="rounded-2xl border border-zinc-800 bg-zinc-900/60 p-4">
        <RouterLink :to="{ name: 'workout-detail', params: { id: workout.id } }" class="block">
          <p class="font-medium">{{ workout.routine_name }}</p>
          <p class="mt-1 text-xs text-zinc-400">
            {{ new Date(workout.start_time).toLocaleString() }} · {{ formatMinutes(workout.duration_seconds) }} ·
            {{ workout.total_sets }} sets · {{ Math.round(workout.total_volume) }} kg
          </p>
          <p v-if="exerciseSummary(workout)" class="mt-1 text-xs text-zinc-500">{{ exerciseSummary(workout) }}</p>
        </RouterLink>
        <div class="mt-3 flex gap-3 text-xs">
          <button type="button" class="text-blue-300" @click="openEdit(workout)">Edit date</button>
          <button type="button" class="text-red-500 hover:text-red-400" @click="pendingDelete = workout">Delete</button>
        </div>
      </li>
    </ul>

    <div v-if="editing" class="fixed inset-0 z-40 flex items-end justify-center bg-black/70 p-4" @click.self="editing = null">
      <form class="w-full max-w-md rounded-3xl border border-zinc-800 bg-zinc-950 p-5" @submit.prevent="saveTimes">
        <h2 class="text-lg font-semibold">Edit date and time</h2>
        <label class="mt-4 flex flex-col gap-1 text-sm">
          Date
          <input v-model="editDate" type="date" class="field" required />
        </label>
        <div class="mt-3 grid grid-cols-2 gap-2">
          <label class="flex flex-col gap-1 text-sm">
            Start
            <input v-model="editStart" type="time" class="field" required />
          </label>
          <label class="flex flex-col gap-1 text-sm">
            End
            <input v-model="editEnd" type="time" class="field" required />
          </label>
        </div>
        <p class="mt-2 text-xs text-zinc-500">If the end time is earlier than the start, it lands on the next day.</p>
        <p v-if="actionError" class="mt-2 text-sm text-red-500">{{ actionError }}</p>
        <div class="mt-4 flex gap-2">
          <button type="button" class="flex-1 rounded-xl border border-zinc-700 py-3 text-sm" @click="editing = null">Cancel</button>
          <button type="submit" class="flex-1 rounded-xl bg-blue-600 py-3 text-sm font-semibold">Save</button>
        </div>
      </form>
    </div>

    <div
      v-if="pendingDelete"
      class="fixed inset-0 z-40 flex items-end justify-center bg-black/70 p-4"
      @click.self="pendingDelete = null"
    >
      <div class="w-full max-w-md rounded-3xl border border-zinc-800 bg-zinc-950 p-5">
        <h2 class="text-lg font-semibold">Delete workout?</h2>
        <p class="mt-2 text-sm text-zinc-400">{{ pendingDelete.routine_name }} and its sets will be removed.</p>
        <p v-if="actionError" class="mt-2 text-sm text-red-500">{{ actionError }}</p>
        <div class="mt-4 flex gap-2">
          <button type="button" class="flex-1 rounded-xl border border-zinc-700 py-3 text-sm" @click="pendingDelete = null">
            Cancel
          </button>
          <button type="button" class="flex-1 rounded-xl bg-red-600 py-3 text-sm font-semibold text-white hover:bg-red-500" @click="confirmDelete">
            Delete
          </button>
        </div>
      </div>
    </div>

    <div v-if="infoCard" class="fixed inset-0 z-[60] grid place-items-center overflow-y-auto bg-black/50 p-5" @click.self="infoCard = null">
      <div class="my-auto w-full max-w-sm rounded-3xl border border-white/15 bg-zinc-900/45 p-6 shadow-2xl backdrop-blur-2xl">
        <template v-if="infoCard === 'bmi'">
          <h2 class="text-lg font-semibold">BMI</h2>
          <p class="mt-3 text-sm leading-relaxed text-zinc-300">
            Body Mass Index (BMI) is a simple tool using height and weight to estimate if you are in a healthy weight range. While important for general health risk assessment, it doesnt distinguish between muscle and fat. For lifters, it's best used as a baseline alongside FFMI.
          </p>
          <p class="mt-3 text-sm text-zinc-400">BMI = weight (kg) / height (m)²</p>
          <p class="mt-2 text-sm">You are <span class="font-semibold" :class="bmiClass(metrics?.bmi?.category)">{{ metrics?.bmi?.category ?? 'not calculated yet' }}</span>.</p>
        </template>
        <template v-else-if="infoCard === 'ffmi'">
          <h2 class="text-lg font-semibold">FFMI</h2>
          <p class="mt-3 text-sm leading-relaxed text-zinc-300">
            Fat-Free Mass Index (FFMI) measures muscle mass relative to your height. While BMI might label a muscular person as 'overweight', a high FFMI confirms that the weight is quality muscle. Tap the calculator to estimate your body fat using measurements.
          </p>
          <p class="mt-3 text-sm text-zinc-400">Lean mass = weight × (1 − body fat). FFMI = lean mass / height².</p>
          <p class="mt-2 text-sm">Current body fat: {{ bodyFatText() }}.</p>
          <button type="button" class="mt-4 w-full rounded-full bg-blue-600 py-2.5 text-sm font-semibold" @click="openNavy">
            Navy body-fat calculator
          </button>
        </template>
        <template v-else-if="infoCard === 'bench'">
          <h2 class="text-lg font-semibold">Strength</h2>
          <p class="mt-3 text-sm leading-relaxed text-zinc-300">
            This measures 'Relative Strength', how powerful you are for your size. We use the Bench Categories as the universal benchmark for upper-body integrity. A 1.0x ratio is equal to beching your own bodyweight and that's 'Strong'. 1.5x is 'Advanced' and 2.0x is 'Elite'.
          </p>
          <ul class="mt-3 space-y-1 text-sm text-zinc-300">
            <li>1.0x Strong</li>
            <li>1.5x Advanced</li>
            <li>2.0x Elite</li>
          </ul>
          <p v-if="history.benchRatio" class="mt-3 text-sm">
            Heaviest bench {{ history.benchRatio.weight }} kg · {{ history.benchRatio.ratio.toFixed(2) }}x · {{ benchTier(history.benchRatio.ratio) }}.
            {{ history.benchRatio.source === 'recent' ? 'From your latest bench session.' : 'From your all-time max bench.' }}
          </p>
          <p v-else class="mt-3 text-sm text-zinc-400">Log a bench-category set and a body weight to see your ratio.</p>
        </template>
        <template v-else>
          <h2 class="text-lg font-semibold">Goal</h2>
          <p class="mt-3 text-sm leading-relaxed text-zinc-300">
            Goal tracks the distance between your current scale weight and your target. Ensure your progress is sustainable by aiming for a 0.5% - 1% change in your weight per week.
          </p>
          <p v-if="metrics?.goal" class="mt-3 text-sm font-semibold text-red-500">
            {{ metrics.goal.kilogramsLeft.toFixed(1) }} kg LEFT · {{ metrics.goal.direction }}.
          </p>
        </template>
        <button type="button" class="mt-5 w-full rounded-full border border-white/15 py-2.5 text-sm" @click="infoCard = null">Close</button>
      </div>
    </div>

    <div v-if="confirmLogout" class="fixed inset-0 z-[60] grid place-items-center overflow-y-auto bg-black/50 p-5" @click.self="confirmLogout = false">
      <div class="my-auto w-full max-w-sm rounded-3xl border border-white/15 bg-zinc-900/45 p-6 shadow-2xl backdrop-blur-2xl">
        <h2 class="text-lg font-semibold">Log out?</h2>
        <p class="mt-2 text-sm text-zinc-400">You'll need to sign in again to see your training.</p>
        <div class="mt-5 flex gap-2">
          <button type="button" class="flex-1 rounded-full border border-white/15 py-2.5 text-sm" @click="confirmLogout = false">Cancel</button>
          <button type="button" class="flex-1 rounded-full bg-blue-600 py-2.5 text-sm font-semibold" @click="signOut">Log out</button>
        </div>
      </div>
    </div>

    <div v-if="navyOpen" class="fixed inset-0 z-[70] grid place-items-center overflow-y-auto bg-black/50 p-5" @click.self="navyOpen = false">
      <form class="my-auto w-full max-w-sm rounded-3xl border border-white/15 bg-zinc-900/45 p-6 shadow-2xl backdrop-blur-2xl" @submit.prevent="applyNavy">
        <h2 class="text-lg font-semibold">Navy body fat</h2>
        <p class="mt-1 text-sm text-zinc-400">Tape measurements. Saving updates FFMI immediately.</p>
        <label class="mt-4 flex flex-col gap-1 text-sm">
          Height (cm)
          <input v-model="navyHeight" inputmode="decimal" class="field" />
        </label>
        <label class="mt-3 flex flex-col gap-1 text-sm">
          Neck (cm)
          <input v-model="neck" inputmode="decimal" class="field" />
        </label>
        <label class="mt-3 flex flex-col gap-1 text-sm">
          Waist (cm)
          <input v-model="waist" inputmode="decimal" class="field" />
        </label>
        <label v-if="auth.profile?.gender === 'female'" class="mt-3 flex flex-col gap-1 text-sm">
          Hip (cm)
          <input v-model="hip" inputmode="decimal" class="field" />
        </label>
        <p v-if="navyError" class="mt-2 text-sm text-red-500">{{ navyError }}</p>
        <div class="mt-4 flex gap-2">
          <button type="button" class="flex-1 rounded-full border border-white/15 py-2.5 text-sm" @click="navyOpen = false">Cancel</button>
          <button type="submit" class="flex-1 rounded-full bg-blue-600 py-2.5 text-sm font-semibold" :disabled="navySaving">
            {{ navySaving ? 'Saving…' : 'Save' }}
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
  padding: 0.7rem 0.75rem;
  outline: none;
}
</style>
