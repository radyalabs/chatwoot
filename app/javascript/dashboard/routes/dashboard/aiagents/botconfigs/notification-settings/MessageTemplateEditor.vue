<script setup>
import { ref, computed } from 'vue';
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

const textareaRef = ref(null);
const showVariableMenu = ref(false);

const examplePreview = computed(() => {
  let text = props.modelValue;
  props.variableConfig.variables.forEach(v => {
    text = text.replaceAll(v.value, v.example);
  });
  return text;
});

const insertVariable = (variable) => {
  const textarea = textareaRef.value;
  if (!textarea) return;

  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const before = props.modelValue.substring(0, start);
  const after = props.modelValue.substring(end);
  const newValue = before + variable.value + after;

  emit('update:modelValue', newValue);
  showVariableMenu.value = false;

  // Restore cursor position after the inserted variable
  const cursorPos = start + variable.value.length;
  requestAnimationFrame(() => {
    textarea.focus();
    textarea.setSelectionRange(cursorPos, cursorPos);
  });
};

const handleInput = (event) => {
  emit('update:modelValue', event.target.value);
};
</script>

<template>
  <div class="flex flex-col gap-1">
    <div class="flex items-center justify-between mb-0.5">
      <label class="text-sm font-medium text-slate-900 dark:text-slate-25">
        {{ $t('AGENT_MGMT.NOTIFICATION.TEMPLATE_LABEL') }}
      </label>
      <div class="relative">
        <button
          type="button"
          class="text-sm font-medium text-green-600 dark:text-green-400 hover:text-green-700 dark:hover:text-green-300 transition-colors"
          @click="showVariableMenu = !showVariableMenu"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.TEMPLATE_ADD_VARIABLE') }}
        </button>
        <div
          v-if="showVariableMenu"
          class="absolute right-0 top-full mt-1 z-10 w-52 bg-slate-700 dark:bg-slate-700 rounded-lg shadow-lg border border-slate-600 dark:border-slate-600 overflow-hidden"
        >
          <button
            v-for="variable in variableConfig.variables"
            :key="variable.value"
            type="button"
            class="w-full text-left px-4 py-2.5 text-sm text-white hover:bg-slate-600 dark:hover:bg-slate-600 transition-colors"
            @click="insertVariable(variable)"
          >
            {{ $t(variable.labelKey) }}
          </button>
        </div>
      </div>
    </div>
    <div
      class="flex flex-col gap-2 px-3 pt-3 pb-3 border rounded-lg bg-n-alpha-black2 border-n-weak dark:border-n-weak hover:border-n-slate-6 dark:hover:border-n-slate-6 transition-all duration-500 ease-in-out"
    >
      <textarea
        ref="textareaRef"
        :value="modelValue"
        rows="4"
        :placeholder="$t('AGENT_MGMT.NOTIFICATION.TEMPLATE_PLACEHOLDER')"
        class="flex w-full reset-base text-sm p-0 !rounded-none !bg-transparent dark:!bg-transparent !border-0 !mb-0 placeholder:text-n-slate-10 dark:placeholder:text-n-slate-10 text-n-slate-12 dark:text-n-slate-12"
        @input="handleInput"
        @click="showVariableMenu = false"
      />
    </div>
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
      <p class="mt-1 mb-0 text-sm font-semibold text-slate-900 dark:text-slate-25">
        {{ examplePreview }}
      </p>
    </div>
  </div>
</template>
