<script setup lang="ts">
import { computed } from 'vue'
import type { PrimaryMuscle } from '../types/database'

const props = defineProps<{
  counts: Record<PrimaryMuscle, number>
  selected: string | null
}>()

const emit = defineEmits<{ select: [region: { id: string; label: string; group: PrimaryMuscle }] }>()

interface Region {
  id: string
  label: string
  group: PrimaryMuscle
  d: string
}

const front: Region[] = [
  { id: 'front-delts', label: 'Anterior delts', group: 'Shoulders', d: 'M70 72C58 58 44 70 42 88c-2 14 12 24 26 16 8-6 12-18 2-32z M130 72c12-14 26-2 28 16 2 14-12 24-26 16-8-6-12-18-2-32z' },
  { id: 'side-delts', label: 'Lateral delts', group: 'Shoulders', d: 'M40 90C26 86 18 104 24 122c4 12 16 14 22 2 6-14 6-24-6-34z M160 90c14-4 22 14 16 32-4 12-16 14-22 2-6-14-6-24 6-34z' },
  { id: 'pectorals', label: 'Pectorals', group: 'Chest', d: 'M70 102c8-14 28-12 30 8l0 30c-12 8-32 2-34-16-2-10 0-16 4-22z M130 102c-8-14-28-12-30 8l0 30c12 8 32 2 34-16 2-10 0-16-4-22z' },
  { id: 'biceps', label: 'Biceps', group: 'Arms', d: 'M42 110C28 118 22 140 30 160c6 14 18 12 22-2 6-18 2-36-10-48z M158 110c14 8 20 30 12 50-6 14-18 12-22-2-6-18-2-36 10-48z' },
  { id: 'forearms', label: 'Forearms', group: 'Arms', d: 'M34 166C24 172 18 196 26 220c4 12 16 10 18-4 4-22 0-42-10-50z M166 166c10 6 16 30 8 54-4 12-16 10-18-4-4-22 0-42 10-50z' },
  { id: 'abs', label: 'Abs', group: 'Core', d: 'M80 150h16a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4H80a4 4 0 0 1-4-4v-10a4 4 0 0 1 4-4z M104 150h16a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4h-16a4 4 0 0 1-4-4v-10a4 4 0 0 1 4-4z M80 172h16a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4H80a4 4 0 0 1-4-4v-10a4 4 0 0 1 4-4z M104 172h16a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4h-16a4 4 0 0 1-4-4v-10a4 4 0 0 1 4-4z M80 194h16a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4H80a4 4 0 0 1-4-4v-10a4 4 0 0 1 4-4z M104 194h16a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4h-16a4 4 0 0 1-4-4v-10a4 4 0 0 1 4-4z' },
  { id: 'obliques', label: 'Obliques', group: 'Core', d: 'M64 148c-8 6-12 28-8 52 2 10 12 8 16-2l4-42c0-6-4-10-12-8z M136 148c8 6 12 28 8 52-2 10-12 8-16-2l-4-42c0-6 4-10 12-8z' },
  { id: 'quads', label: 'Quads', group: 'Legs', d: 'M78 214C62 222 54 258 62 302c6 22 20 20 26 0 8-36 6-68-10-88z M122 214c16 8 24 44 16 88-6 22-20 20-26 0-8-36-6-68 10-88z' },
  { id: 'front-calves', label: 'Calves', group: 'Legs', d: 'M70 316C58 324 56 348 64 372c6 12 18 8 20-6 4-20 0-40-14-50z M130 316c12 8 14 32 6 56-6 12-18 8-20-6-4-20 0-40 14-50z' },
]

const back: Region[] = [
  { id: 'traps', label: 'Traps', group: 'Back', d: 'M100 58L132 82L116 112H84L68 82Z' },
  { id: 'rear-delts', label: 'Posterior delts', group: 'Shoulders', d: 'M68 74C52 66 38 84 42 104c4 14 18 14 26 2 8-12 10-22 0-32z M132 74c16-8 30 10 26 30-4 14-18 14-26 2-8-12-10-22 0-32z' },
  { id: 'lats', label: 'Lats', group: 'Back', d: 'M78 104C60 114 46 140 52 174c4 20 20 16 28-2l8-56c2-8 0-14-10-12z M122 104c18 10 32 36 26 70-4 20-20 16-28-2l-8-56c-2-8 0-14 10-12z' },
  { id: 'lower-back', label: 'Lower back', group: 'Back', d: 'M86 156c-8 12-6 36 14 46 20-10 22-34 14-46-6-8-22-8-28 0z' },
  { id: 'triceps', label: 'Triceps', group: 'Arms', d: 'M40 108C24 118 16 142 28 166c8 14 22 8 26-8 6-20 0-40-14-50z M160 108c16 10 24 34 12 58-8 14-22 8-26-8-6-20 0-40 14-50z' },
  { id: 'rear-forearms', label: 'Forearms', group: 'Arms', d: 'M32 172C20 180 16 206 26 230c6 12 18 6 18-8 2-22-2-40-12-50z M168 172c12 8 16 34 6 58-6 12-18 6-18-8-2-22 2-40 12-50z' },
  { id: 'glutes', label: 'Glutes', group: 'Legs', d: 'M76 190C62 196 56 216 66 232c10 14 28 8 34-8l0-24c-6-10-16-12-24-10z M124 190c14 6 20 26 10 42-10 14-28 8-34-8l0-24c6-10 16-12 24-10z' },
  { id: 'hamstrings', label: 'Hamstrings', group: 'Legs', d: 'M76 236C60 246 52 278 62 318c8 18 22 14 26-4 8-36 4-64-12-78z M124 236c16 10 24 42 14 82-8 18-22 14-26-4-8-36-4-64 12-78z' },
  { id: 'rear-calves', label: 'Calves', group: 'Legs', d: 'M72 322C58 332 56 356 66 380c8 12 20 6 20-10 2-22-2-44-14-48z M128 322c14 10 16 34 6 58-8 12-20 6-20-10-2-22 2-44 14-48z' },
]

const maxCount = computed(() => Math.max(0, ...Object.values(props.counts)))

function heat(group: PrimaryMuscle): { fill: string; glow: string } {
  const count = props.counts[group] ?? 0
  if (!(count > 0) || !(maxCount.value > 0)) return { fill: '#27272a', glow: 'none' }
  const ratio = count / maxCount.value
  if (ratio < 0.25) return { fill: '#3b82f6', glow: 'drop-shadow(0 0 5px #3b82f6)' }
  if (ratio < 0.5) return { fill: '#22d3ee', glow: 'drop-shadow(0 0 6px #22d3ee)' }
  if (ratio < 0.75) return { fill: '#34d399', glow: 'drop-shadow(0 0 7px #34d399)' }
  return { fill: '#fb923c', glow: 'drop-shadow(0 0 8px #fb923c)' }
}

function styleFor(region: Region) {
  const paint = heat(region.group)
  const selected = props.selected === region.id
  return {
    fill: paint.fill,
    filter: paint.glow,
    stroke: selected ? '#ffffff' : 'rgba(255,255,255,0.18)',
    strokeWidth: selected ? 1.6 : 0.6,
  }
}
</script>

<template>
  <div class="grid grid-cols-2 gap-2">
    <figure v-for="side in [{ title: 'Front', regions: front }, { title: 'Back', regions: back }]" :key="side.title">
      <figcaption class="mb-1 text-center text-[10px] font-semibold tracking-[0.16em] text-zinc-500">
        {{ side.title.toUpperCase() }}
      </figcaption>
      <svg viewBox="0 0 200 400" class="w-full" role="img" :aria-label="`${side.title} muscle map`">
        <ellipse cx="100" cy="32" rx="16" ry="18" fill="#18181b" stroke="#3f3f46" />
        <path d="M90 48h20l4 18H86z" fill="#18181b" stroke="#3f3f46" />
        <ellipse cx="24" cy="228" rx="7" ry="8" fill="#18181b" stroke="#3f3f46" />
        <ellipse cx="176" cy="228" rx="7" ry="8" fill="#18181b" stroke="#3f3f46" />
        <ellipse cx="74" cy="386" rx="12" ry="6" fill="#18181b" stroke="#3f3f46" />
        <ellipse cx="126" cy="386" rx="12" ry="6" fill="#18181b" stroke="#3f3f46" />
        <path
          v-for="region in side.regions"
          :key="region.id"
          :d="region.d"
          class="cursor-pointer"
          :fill="styleFor(region).fill"
          :stroke="styleFor(region).stroke"
          :stroke-width="styleFor(region).strokeWidth"
          :style="{ filter: styleFor(region).filter }"
          @click="emit('select', { id: region.id, label: region.label, group: region.group })"
        >
          <title>{{ region.label }}</title>
        </path>
      </svg>
    </figure>
  </div>
</template>
