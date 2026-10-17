<script setup lang="ts">
import { ChevronLeft } from 'lucide-vue-next'
import { useRouter } from 'vue-router'

const props = defineProps<{ to?: string; label?: string }>()
const router = useRouter()

function go() {
  if (props.to) {
    void router.push(props.to)
    return
  }
  router.back()
}
</script>

<template>
  <button
    type="button"
    class="mb-4 grid h-10 w-10 place-items-center rounded-full border border-white/15 bg-zinc-900/45 text-white shadow-[0_8px_24px_rgba(0,0,0,0.35)] backdrop-blur-xl"
    :aria-label="label ?? 'Back'"
    @click="go"
  >
    <ChevronLeft :size="20" />
  </button>
</template>
