<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import CustomRecurrenceModal from './CustomRecurrenceModal.vue';

const { t } = useI18n();

const props = defineProps({
  modelValue: {
    type: Object,
    default: null,
  },
  scheduledAt: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['update:modelValue']);

const showCustomModal = ref(false);
const displayPreset = ref('none');

const DAYS_SHORT = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

const presetOptions = computed(() => [
  { value: 'none', label: t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_NONE') },
  { value: 'daily', label: t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_DAILY') },
  { value: 'weekly', label: t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_WEEKLY') },
  {
    value: 'monthly',
    label: t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_MONTHLY'),
  },
  {
    value: 'annually',
    label: t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_ANNUALLY'),
  },
  {
    value: 'weekday',
    label: t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_WEEKDAY'),
  },
  {
    value: 'custom',
    label: t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_CUSTOM'),
  },
]);

const selectedPreset = computed(() => {
  if (!props.modelValue) return 'none';

  const rule = props.modelValue;
  const freq = rule.frequency;
  const interval = rule.interval || 1;

  if (freq === 'daily' && interval === 1 && !rule.days_of_week?.length) {
    return 'daily';
  }
  if (freq === 'daily' && interval === 1 && rule.days_of_week) {
    const weekdays = [1, 2, 3, 4, 5];
    const ruleDays = [...(rule.days_of_week || [])].sort();
    if (JSON.stringify(ruleDays) === JSON.stringify(weekdays)) {
      return 'weekday';
    }
  }
  if (freq === 'weekly' && interval === 1) {
    return 'weekly';
  }
  if (freq === 'monthly' && interval === 1) {
    return 'monthly';
  }
  if (freq === 'yearly' && interval === 1) {
    return 'annually';
  }

  return 'custom';
});

// Keep displayPreset in sync when modelValue changes externally (e.g. on load/edit).
watch(selectedPreset, val => {
  displayPreset.value = val;
}, { immediate: true });

const selectedDaysOfWeek = computed(() => {
  if (!props.modelValue || props.modelValue.frequency !== 'weekly') return [];
  return props.modelValue.days_of_week || [];
});

const showDaySelector = computed(() => {
  return (
    props.modelValue &&
    props.modelValue.frequency === 'weekly' &&
    selectedPreset.value === 'weekly'
  );
});

const handlePresetChange = () => {
  const value = displayPreset.value; // v-model already updated this

  if (value === 'none') {
    emit('update:modelValue', null);
    return;
  }

  if (value === 'custom') {
    showCustomModal.value = true;
    return;
  }

  const scheduledDate = props.scheduledAt
    ? new Date(props.scheduledAt)
    : new Date();
  const dayOfWeek = scheduledDate.getDay();
  const dayOfMonth = scheduledDate.getDate();

  const ruleMap = {
    daily: { frequency: 'daily', interval: 1 },
    weekly: {
      frequency: 'weekly',
      interval: 1,
      days_of_week: [dayOfWeek],
    },
    monthly: {
      frequency: 'monthly',
      interval: 1,
      day_of_month: dayOfMonth,
    },
    annually: { frequency: 'yearly', interval: 1 },
    weekday: {
      frequency: 'daily',
      interval: 1,
      days_of_week: [1, 2, 3, 4, 5],
    },
  };

  emit('update:modelValue', ruleMap[value] || null);
};

const toggleDay = day => {
  const currentDays = [...(props.modelValue?.days_of_week || [])];
  const index = currentDays.indexOf(day);

  if (index >= 0) {
    currentDays.splice(index, 1);
  } else {
    currentDays.push(day);
  }

  if (currentDays.length === 0) {
    emit('update:modelValue', null);
    return;
  }

  emit('update:modelValue', {
    ...props.modelValue,
    days_of_week: currentDays.sort(),
  });
};

const handleCustomSave = rule => {
  emit('update:modelValue', rule);
  showCustomModal.value = false;
};

const handleCustomClose = () => {
  showCustomModal.value = false;
  displayPreset.value = selectedPreset.value;
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div>
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('AGENT_MGMT.SALESBOT.REMINDER.REPEAT_LABEL') }}
      </label>
      <select
        v-model="displayPreset"
        class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all"
        @change="handlePresetChange"
      >
        <option
          v-for="opt in presetOptions"
          :key="opt.value"
          :value="opt.value"
        >
          {{ opt.label }}
        </option>
      </select>
    </div>

    <!-- Day selection for weekly -->
    <div v-if="showDaySelector" class="flex flex-wrap gap-1.5">
      <button
        v-for="(label, index) in DAYS_SHORT"
        :key="index"
        type="button"
        class="w-9 h-9 rounded-full text-xs font-medium transition-all duration-150"
        :class="
          selectedDaysOfWeek.includes(index)
            ? 'bg-woot-500 text-white shadow-sm'
            : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
        "
        @click="toggleDay(index)"
      >
        {{ label }}
      </button>
    </div>

    <!-- Custom recurrence summary -->
    <div
      v-if="selectedPreset === 'custom' && modelValue"
      class="text-xs text-slate-500 dark:text-slate-400 bg-slate-50 dark:bg-slate-800 rounded-lg px-3 py-2"
    >
      {{ modelValue._summary || 'Custom schedule configured' }}
    </div>

    <CustomRecurrenceModal
      v-if="showCustomModal"
      :rule="modelValue"
      :scheduled-at="scheduledAt"
      @save="handleCustomSave"
      @close="handleCustomClose"
    />
  </div>
</template>
