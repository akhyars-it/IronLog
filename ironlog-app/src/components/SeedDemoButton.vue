<script setup lang="ts">
import { ref } from 'vue'
import { seedDemoData } from '../utils/seedDemoData'

const emit = defineEmits<{ seeded: [] }>()
const busy = ref(false)
const message = ref('')
const failed = ref(false)

async function run() {
  busy.value = true
  message.value = ''
  failed.value = false
  const result = await seedDemoData()
  busy.value = false
  failed.value = !result.ok
  message.value = result.message
  if (result.ok) emit('seeded')
}
</script>

<template>
  <div>
    <button
      type="button"
      class="rounded-full border border-zinc-700 px-3 py-1.5 text-xs font-medium text-zinc-200 disabled:opacity-50"
      :disabled="busy"
      @click="run"
    >
      {{ busy ? 'Seeding…' : 'Seed 2 Weeks Demo Data' }}
    </button>
    <p v-if="message" class="mt-2 text-xs" :class="failed ? 'text-red-500' : 'text-emerald-300'">{{ message }}</p>
  </div>
</template>
