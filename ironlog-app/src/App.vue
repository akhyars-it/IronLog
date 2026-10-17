<script setup lang="ts">
import { watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from './stores/authStore'

const auth = useAuthStore()
const router = useRouter()

watch(
  () => auth.session,
  (session) => {
    if (auth.initialized && !session && router.currentRoute.value.meta.requiresAuth) {
      void router.replace({ name: 'login' })
    }
  },
)
</script>

<template>
  <RouterView />
</template>
