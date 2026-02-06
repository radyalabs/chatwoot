<script setup>
import { computed } from 'vue';
const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  variableConfig: {
    type: Object,
    default: () => ({
      helpKey: 'AGENT_MGMT.LEADGENBOT.NOTIFICATION.TEMPLATE_HELP',
      variables: [],
    }),
  },
});

const emit = defineEmits(['update:modelValue']);

const examplePreview = computed(() => {
  let text = props.modelValue;
  props.variableConfig.variables.forEach(v => {
    text = text.replaceAll(v.value, v.example);
  });
  return text;
});

const hasContentSummary = computed(() => {
  return props.modelValue.includes('{{content_summary}}');
});

const handleInput = (event) => {
  emit('update:modelValue', event.target.value);
};
</script>

<template>
  <div class="flex flex-col gap-1">
    <div class="flex flex-col gap-0.5 mb-0.5">
      <label class="text-sm font-medium text-slate-900 dark:text-slate-25">
        {{ $t('AGENT_MGMT.NOTIFICATION.TEMPLATE_LABEL') }}
      </label>
      <span class="text-xs text-amber-600 dark:text-amber-400">
        {{ $t('AGENT_MGMT.NOTIFICATION.CONTENT_SUMMARY_REQUIRED') }}
      </span>
    </div>
    <div
      class="flex flex-col gap-2 px-3 pt-3 pb-3 border rounded-lg bg-n-alpha-black2 border-n-weak dark:border-n-weak hover:border-n-slate-6 dark:hover:border-n-slate-6 transition-all duration-500 ease-in-out"
    >
      <textarea
        :value="modelValue"
        rows="4"
        :placeholder="$t('AGENT_MGMT.NOTIFICATION.TEMPLATE_PLACEHOLDER')"
        class="flex w-full reset-base text-sm p-0 !rounded-none !bg-transparent dark:!bg-transparent !border-0 !mb-0 placeholder:text-n-slate-10 dark:placeholder:text-n-slate-10 text-n-slate-12 dark:text-n-slate-12"
        @input="handleInput"
      />
    </div>
    <!-- Validation warning when {{content_summary}} is missing -->
    <p
      v-if="modelValue.trim() && !hasContentSummary"
      class="text-xs text-red-500 dark:text-red-400 mt-1 mb-0"
    >
      {{ $t('AGENT_MGMT.NOTIFICATION.CONTENT_SUMMARY_MISSING_WARNING') }}
    </p>
    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 mb-0">
      {{ $t(variableConfig.helpKey) }}
    </p>

    <!-- Example Preview -->
    <div
      v-if="modelValue"
      class="mt-3 border border-slate-200 dark:border-slate-700 rounded-lg p-4 bg-white dark:bg-slate-800/50"
    >
      <span class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
        {{ $t('AGENT_MGMT.NOTIFICATION.TEMPLATE_PREVIEW_LABEL') }}
      </span>
      <p class="mt-1 mb-0 text-sm font-semibold text-slate-900 dark:text-slate-25 whitespace-pre-wrap">
        {{ examplePreview }}
      </p>
    </div>
  </div>
</template>
