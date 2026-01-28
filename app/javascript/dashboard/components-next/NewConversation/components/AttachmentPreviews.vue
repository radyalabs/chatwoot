<script setup>
import { computed } from 'vue';
import { fileNameWithEllipsis } from '@chatwoot/utils';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  attachments: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['update:attachments']);

const isTypeImage = file => {
  const type = file.content_type || file.type;
  return type.includes('image');
};

const filteredImageAttachments = computed(() => {
  return props.attachments.filter(attachment =>
    isTypeImage(attachment.resource)
  );
});

const filteredNonImageAttachments = computed(() => {
  return props.attachments.filter(
    attachment => !isTypeImage(attachment.resource)
  );
});

const removeAttachment = id => {
  const updatedAttachments = props.attachments.filter(
    attachment => attachment.resource.id !== id
  );
  emit('update:attachments', updatedAttachments);
};
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <div
      v-if="filteredImageAttachments.length > 0"
      class="flex flex-wrap gap-3"
    >
      <div
        v-for="attachment in filteredImageAttachments"
        :key="attachment.id || attachment.tempId"
        class="relative group/image w-[72px] h-[72px]"
      >
        <img
          class="object-cover w-[72px] h-[72px] rounded-lg"
          :class="{ 'opacity-50': attachment.uploading }"
          :src="attachment.thumb"
        />
        <div
          v-if="attachment.uploading"
          class="absolute inset-0 flex items-center justify-center"
        >
          <div
            class="w-6 h-6 border-2 border-woot-500 border-t-transparent rounded-full animate-spin"
          />
        </div>
        <Button
          v-else
          variant="ghost"
          icon="i-lucide-trash"
          color="slate"
          class="absolute top-1 right-1 !w-5 !h-5 transition-opacity duration-150 ease-in-out opacity-0 group-hover/image:opacity-100"
          @click="removeAttachment(attachment.resource.id)"
        />
      </div>
    </div>
    <div
      v-if="filteredNonImageAttachments.length > 0"
      class="flex flex-wrap gap-3"
    >
      <div
        v-for="attachment in filteredNonImageAttachments"
        :key="attachment.id || attachment.tempId"
        class="max-w-[300px] inline-flex items-center h-8 min-w-0 bg-n-alpha-2 dark:bg-n-solid-3 rounded-lg gap-3 ltr:pl-3 rtl:pr-3 ltr:pr-2 rtl:pl-2"
      >
        <span class="text-sm font-medium text-n-slate-11">
          {{ fileNameWithEllipsis(attachment.resource) }}
        </span>
        <div
          v-if="attachment.uploading"
          class="w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin shrink-0"
        />
        <Button
          v-else
          variant="ghost"
          icon="i-lucide-x"
          color="slate"
          size="xs"
          class="shrink-0 !h-5 !w-5"
          @click="removeAttachment(attachment.resource.id)"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.animate-spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
