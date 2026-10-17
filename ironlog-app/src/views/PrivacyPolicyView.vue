<script setup lang="ts">
import { computed } from 'vue'
import GlassBackButton from '../components/GlassBackButton.vue'
import { useAuthStore } from '../stores/authStore'

const auth = useAuthStore()
const backTo = computed(() => (auth.session ? '/profile/edit' : '/login'))
</script>

<template>
  <div class="mx-auto min-h-dvh w-full max-w-md bg-zinc-950 px-5 pt-[calc(1.5rem+env(safe-area-inset-top))] pb-[calc(2rem+env(safe-area-inset-bottom))] text-zinc-100">
    <GlassBackButton :to="backTo" label="Back" />
    <p class="text-xs font-semibold tracking-[0.2em] text-blue-400">IRONLOG</p>
    <h1 class="mt-3 text-3xl font-semibold tracking-tight">Privacy policy</h1>
    <p class="mt-2 text-sm text-zinc-400">What IronLog stores, why, and how to erase it.</p>

    <article class="mt-6 rounded-3xl border border-white/15 bg-zinc-900/45 p-6 shadow-[0_8px_32px_rgba(0,0,0,0.45)] ring-1 ring-inset ring-white/5 backdrop-blur-2xl saturate-150">
      <h2 class="text-sm font-semibold tracking-wide text-zinc-200">Data we collect</h2>
      <ul class="mt-3 list-disc space-y-2 pl-5 text-sm leading-relaxed text-zinc-300">
        <li>Account email, username, and optional display name and bio.</li>
        <li>Birth date and gender, used as profile details.</li>
        <li>Height, weight, target weight, and optional body-fat percentage.</li>
        <li>Workout logs: exercises, sets, weight, reps, duration, and notes.</li>
        <li>An optional avatar photo you choose to upload.</li>
      </ul>

      <h2 class="mt-6 text-sm font-semibold tracking-wide text-zinc-200">Why we collect it</h2>
      <p class="mt-3 text-sm leading-relaxed text-zinc-300">
        Height, weight, and body fat are used to calculate BMI and FFMI. Logged sets are used to calculate volume and estimated 1RM.
        The same records are synced to your private cloud account through Supabase so they are available when you sign in again.
      </p>

      <h2 class="mt-6 text-sm font-semibold tracking-wide text-zinc-200">How it is protected</h2>
      <p class="mt-3 text-sm leading-relaxed text-zinc-300">
        Traffic to Supabase uses encrypted HTTPS. Row Level Security limits each signed-in user to their own profile, routines, workouts, and avatar path.
        IronLog does not sell this data and does not use it for advertising.
      </p>

      <h2 class="mt-6 text-sm font-semibold tracking-wide text-zinc-200">Delete your account</h2>
      <p class="mt-3 text-sm leading-relaxed text-zinc-300">
        In Edit Profile, open Delete Account, type DELETE, and confirm. That permanently removes your account, body metrics, workout logs, routines, and avatar in one step.
      </p>
    </article>
  </div>
</template>
