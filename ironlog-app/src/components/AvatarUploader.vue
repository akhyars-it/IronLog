<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/authStore'
import { friendlyError } from '../utils/errorHandler'

const props = defineProps<{
  userId: string
  url: string | null
}>()

const emit = defineEmits<{
  uploaded: [url: string]
}>()

const auth = useAuthStore()
const uploading = ref(false)
const errorMessage = ref('')
const fileInput = ref<HTMLInputElement | null>(null)

function openPicker() {
  fileInput.value?.click()
}

async function onFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return

  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
    errorMessage.value = 'Use a JPEG, PNG, or WebP image.'
    return
  }
  if (file.size > 5 * 1024 * 1024) {
    errorMessage.value = 'Images need to be 5 MB or smaller.'
    return
  }

  uploading.value = true
  errorMessage.value = ''
  const path = `${props.userId}/avatar`
  const { error } = await supabase.storage.from('avatars').upload(path, file, {
    upsert: true,
    contentType: file.type,
  })
  if (error) {
    errorMessage.value = friendlyError(error)
    uploading.value = false
    return
  }

  const { data } = supabase.storage.from('avatars').getPublicUrl(path)
  const publicUrl = `${data.publicUrl}?v=${Date.now()}`
  const saved = await auth.updateAvatarUrl(publicUrl)
  uploading.value = false
  if (saved) {
    errorMessage.value = saved
    return
  }
  emit('uploaded', publicUrl)
}
</script>

<template>
  <div class="flex flex-col items-center gap-3">
    <button
      type="button"
      class="relative h-24 w-24 overflow-hidden rounded-full border border-zinc-700 bg-zinc-900"
      :disabled="uploading"
      @click="openPicker"
    >
      <img v-if="url" :src="url" alt="Profile photo" class="h-full w-full object-cover" />
      <span v-else class="text-xs text-zinc-500">Add photo</span>
      <span
        v-if="uploading"
        class="absolute inset-0 grid place-items-center bg-black/60 text-xs text-white"
      >
        Saving
      </span>
    </button>
    <button type="button" class="text-sm font-medium text-blue-400" :disabled="uploading" @click="openPicker">
      Change profile picture
    </button>
    <input
      ref="fileInput"
      class="hidden"
      type="file"
      accept="image/jpeg,image/png,image/webp"
      @change="onFile"
    />
    <p v-if="errorMessage" class="text-center text-sm text-red-500">{{ errorMessage }}</p>
  </div>
</template>
