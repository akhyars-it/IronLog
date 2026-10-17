<script setup lang="ts">
import { useRoute } from 'vue-router'
import BottomNav from './BottomNav.vue'

const route = useRoute()
</script>

<template>
  <div class="relative mx-auto flex min-h-dvh w-full max-w-md flex-col bg-zinc-950 pt-[env(safe-area-inset-top)] text-zinc-100">
    <main class="flex-1 overflow-y-auto" :class="route.meta.hideNav ? 'pb-[env(safe-area-inset-bottom)]' : 'pb-[calc(7rem+env(safe-area-inset-bottom))]'">
      <RouterView />
    </main>
    <BottomNav v-if="!route.meta.hideNav" />
  </div>
</template>
