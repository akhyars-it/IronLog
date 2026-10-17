<script setup lang="ts">
import { CalendarDays, ChartColumn, Dumbbell, LayoutDashboard, Library } from 'lucide-vue-next'
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const active = computed(() => {
  if (route.path.startsWith('/workout')) return 'workout'
  if (route.path.startsWith('/exercises')) return 'exercises'
  if (route.path.startsWith('/stats')) return 'stats'
  if (route.path.startsWith('/calendar')) return 'calendar'
  if (route.name === 'dashboard') return 'dashboard'
  return ''
})

const items = [
  { name: 'dashboard', to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { name: 'workout', to: '/workout', label: 'Workout', icon: Dumbbell },
  { name: 'exercises', to: '/exercises', label: 'Exercises', icon: Library },
  { name: 'stats', to: '/stats', label: 'Stats', icon: ChartColumn },
  { name: 'calendar', to: '/calendar', label: 'Calendar', icon: CalendarDays },
]
</script>

<template>
  <div class="pointer-events-none fixed inset-x-0 bottom-0 z-50 flex justify-center pb-[env(safe-area-inset-bottom)]">
  <nav
    class="pointer-events-auto mb-5 w-[calc(100%-2rem)] max-w-[380px] rounded-full border border-white/12 bg-zinc-900/60 px-2 py-1.5 shadow-[0_12px_40px_rgba(0,0,0,0.7)] ring-1 ring-inset ring-white/5 backdrop-blur-2xl saturate-150"
    aria-label="Primary"
  >
    <ul class="grid grid-cols-5 items-center gap-1">
      <li v-for="item in items" :key="item.name">
        <RouterLink
          :to="item.to"
          class="flex flex-col items-center gap-0.5 rounded-full py-1.5 text-[10px] font-medium active:scale-95"
          :class="
            active === item.name
              ? 'border border-blue-400/25 bg-blue-500/20 text-blue-400 shadow-inner transition-all duration-200'
              : 'text-zinc-400 transition-colors hover:text-zinc-200'
          "
          :aria-current="active === item.name ? 'page' : undefined"
        >
          <component :is="item.icon" :size="18" :stroke-width="2" />
          <span class="max-w-full truncate">{{ item.label }}</span>
        </RouterLink>
      </li>
    </ul>
  </nav>
  </div>
</template>
