<script setup>
import { ref, computed, watch, watchEffect } from 'vue';
import { useI18n } from 'vue-i18n';

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

const displayPreset = ref('none');

const dayOptions = computed(() => [
  { index: 0, label: t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.SUNDAY') },
  { index: 1, label: t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.MONDAY') },
  { index: 2, label: t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.TUESDAY') },
  { index: 3, label: t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.WEDNESDAY') },
  { index: 4, label: t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.THURSDAY') },
  { index: 5, label: t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.FRIDAY') },
  { index: 6, label: t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.SATURDAY') },
]);

const frequencyOptions = computed(() => [
  { value: 'daily', label: t('AGENT_MGMT.REMINDER.MANAGEMENT.FREQUENCY.DAY') },
  { value: 'weekly', label: t('AGENT_MGMT.REMINDER.MANAGEMENT.FREQUENCY.WEEK') },
  { value: 'monthly', label: t('AGENT_MGMT.REMINDER.MANAGEMENT.FREQUENCY.MONTH') },
  { value: 'yearly', label: t('AGENT_MGMT.REMINDER.MANAGEMENT.FREQUENCY.YEAR') },
]);

// Custom inline state
const customFrequency = ref('weekly');
const customInterval = ref(1);
const customDaysOfWeek = ref([]);
const customDayOfMonth = ref(null);
const customEndsType = ref('never');
const customEndsDate = ref('');
const customEndsAfterCount = ref(1);

const presetOptions = computed(() => [
  { value: 'none', label: t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_NONE') },
  { value: 'daily', label: t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_DAILY') },
  { value: 'weekly', label: t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_WEEKLY') },
  {
    value: 'monthly',
    label: t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_MONTHLY'),
  },
  {
    value: 'annually',
    label: t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_ANNUALLY'),
  },
  {
    value: 'weekday',
    label: t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_WEEKDAY'),
  },
  {
    value: 'custom',
    label: t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_CUSTOM'),
  },
]);

const selectedPreset = computed(() => {
  if (!props.modelValue) return 'none';

  const rule = props.modelValue;
  // Explicit marker set when user saves via the custom inline section.
  if (rule.preset === 'custom') return 'custom';

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
// Do NOT override while the user is explicitly in custom mode — the emitted custom
// rule may coincidentally match a preset (e.g. weekly + interval 1) and would
// snap the dropdown back, fighting the user's selection.
watch(
  selectedPreset,
  val => {
    if (displayPreset.value === 'custom') return;
    displayPreset.value = val;
  },
  { immediate: true }
);

const scheduledDateObj = computed(() => {
  return props.scheduledAt ? new Date(props.scheduledAt) : new Date();
});

const initCustomState = () => {
  const rule = props.modelValue;
  if (rule && rule.frequency) {
    customFrequency.value = rule.frequency;
    customInterval.value = rule.interval || 1;
    customDaysOfWeek.value = [...(rule.days_of_week || [])];
    customDayOfMonth.value = rule.day_of_month || null;
  } else {
    customFrequency.value = 'weekly';
    customInterval.value = 1;
    customDaysOfWeek.value = [scheduledDateObj.value.getDay()];
    customDayOfMonth.value = scheduledDateObj.value.getDate();
  }
  if (rule?._ends_at) {
    customEndsType.value = 'on_date';
    customEndsDate.value = rule._ends_at;
    customEndsAfterCount.value = 1;
  } else if (rule?._ends_after_count) {
    customEndsType.value = 'after_count';
    customEndsAfterCount.value = rule._ends_after_count;
    customEndsDate.value = '';
  } else {
    customEndsType.value = 'never';
    customEndsDate.value = '';
    customEndsAfterCount.value = 1;
  }
};

// Init custom state when switching to custom preset
watch(displayPreset, newVal => {
  if (newVal === 'custom') {
    initCustomState();
  }
});

// Auto-select day/month when custom frequency changes
watch(customFrequency, newFreq => {
  if (newFreq === 'weekly' && customDaysOfWeek.value.length === 0) {
    customDaysOfWeek.value = [scheduledDateObj.value.getDay()];
  }
  if (newFreq === 'monthly' && !customDayOfMonth.value) {
    customDayOfMonth.value = scheduledDateObj.value.getDate();
  }
});

// Emit updated rule live whenever any custom field changes
watchEffect(() => {
  if (displayPreset.value !== 'custom') return;

  const freq = customFrequency.value;
  const intv = customInterval.value;
  const days = [...customDaysOfWeek.value];
  const dom = customDayOfMonth.value;
  const endsType = customEndsType.value;
  const endsDate = customEndsDate.value;
  const endsAfterCount = customEndsAfterCount.value;

  const rule = { frequency: freq, interval: intv, preset: 'custom' };

  if (freq === 'weekly') {
    rule.days_of_week = [...days].sort();
  }
  if (freq === 'monthly') {
    rule.day_of_month = dom;
  }
  if (endsType === 'on_date' && endsDate) {
    rule._ends_at = endsDate;
  }
  if (endsType === 'after_count' && endsAfterCount) {
    rule._ends_after_count = endsAfterCount;
  }

  const freqSingular = t(`AGENT_MGMT.REMINDER.MANAGEMENT.FREQUENCY.${freq.replace('daily','DAY').replace('weekly','WEEK').replace('monthly','MONTH').replace('yearly','YEAR')}`);
  const freqPlural = t(`AGENT_MGMT.REMINDER.MANAGEMENT.FREQUENCY.${freq.replace('daily','DAYS').replace('weekly','WEEKS').replace('monthly','MONTHS').replace('yearly','YEARS')}`);
  const freqLabel = intv > 1 ? freqPlural : freqSingular;
  let summary = `${t('AGENT_MGMT.REMINDER.MANAGEMENT.SUMMARY_EVERY')} ${intv > 1 ? `${intv} ` : ''}${freqLabel}`;
  if (freq === 'weekly' && days.length) {
    const allDays = [
      t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.SUNDAY'),
      t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.MONDAY'),
      t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.TUESDAY'),
      t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.WEDNESDAY'),
      t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.THURSDAY'),
      t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.FRIDAY'),
      t('AGENT_MGMT.REMINDER.MANAGEMENT.DAYS.SATURDAY'),
    ];
    summary += ` ${t('AGENT_MGMT.REMINDER.MANAGEMENT.SUMMARY_ON')} ` + [...days].sort().map(d => allDays[d]).join(', ');
  }
  rule._summary = summary;

  emit('update:modelValue', rule);
});

const selectedDaysOfWeek = computed(() => {
  if (!props.modelValue || props.modelValue.frequency !== 'weekly') return [];
  return props.modelValue.days_of_week || [];
});

const showDaySelector = computed(() => {
  return (
    props.modelValue &&
    props.modelValue.frequency === 'weekly' &&
    displayPreset.value === 'weekly'
  );
});

const showCustomInline = computed(() => displayPreset.value === 'custom');
const showCustomDaySelector = computed(() => customFrequency.value === 'weekly');
const showCustomDayOfMonth = computed(
  () => customFrequency.value === 'monthly'
);

const handlePresetChange = () => {
  const value = displayPreset.value;

  if (value === 'none') {
    emit('update:modelValue', null);
    return;
  }

  if (value === 'custom') {
    // Inline section appears via showCustomInline; initCustomState handled by watch(displayPreset)
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

const toggleCustomDay = day => {
  const index = customDaysOfWeek.value.indexOf(day);
  if (index >= 0) {
    customDaysOfWeek.value.splice(index, 1);
  } else {
    customDaysOfWeek.value.push(day);
  }
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div>
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_LABEL') }}
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

    <!-- Day selection for weekly preset -->
    <div v-if="showDaySelector" class="flex flex-col gap-2">
      <span class="text-sm text-gray-700 dark:text-gray-300">
        {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_ON') }}
      </span>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="day in dayOptions"
          :key="day.index"
          type="button"
          class="px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-150"
          :class="
            selectedDaysOfWeek.includes(day.index)
              ? 'bg-woot-500 text-white shadow-sm'
              : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
          "
          @click="toggleDay(day.index)"
        >
          {{ day.label }}
        </button>
      </div>
    </div>

    <!-- Inline custom recurrence section -->
    <div
      v-if="showCustomInline"
      class="border border-gray-200 dark:border-gray-700 rounded-lg p-4 flex flex-col gap-4"
    >
      <!-- Interval selector -->
      <div class="flex items-center gap-3">
        <span class="text-sm text-gray-700 dark:text-gray-300 whitespace-nowrap">
          {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_EVERY') }}
        </span>
        <input
          v-model.number="customInterval"
          type="number"
          min="1"
          max="99"
          class="w-16 px-2 py-1.5 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm text-center"
        />
        <select
          v-model="customFrequency"
          class="px-3 py-1.5 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm"
        >
          <option
            v-for="opt in frequencyOptions"
            :key="opt.value"
            :value="opt.value"
          >
            {{ customInterval > 1 ? t(`AGENT_MGMT.REMINDER.MANAGEMENT.FREQUENCY.${opt.value.replace('daily','DAYS').replace('weekly','WEEKS').replace('monthly','MONTHS').replace('yearly','YEARS')}`) : opt.label }}
          </option>
        </select>
      </div>

      <!-- Day-of-week selector (weekly) -->
      <div v-if="showCustomDaySelector">
        <span class="block text-sm text-gray-700 dark:text-gray-300 mb-2">
          {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_ON') }}
        </span>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="day in dayOptions"
            :key="day.index"
            type="button"
            class="px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-150"
            :class="
              customDaysOfWeek.includes(day.index)
                ? 'bg-woot-500 text-white shadow-sm'
                : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
            "
            @click="toggleCustomDay(day.index)"
          >
            {{ day.label }}
          </button>
        </div>
      </div>

      <!-- Day-of-month selector (monthly) -->
      <div v-if="showCustomDayOfMonth">
        <span class="block text-sm text-gray-700 dark:text-gray-300 mb-2">
          {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.ON_DAY') }}
        </span>
        <input
          v-model.number="customDayOfMonth"
          type="number"
          min="1"
          max="31"
          class="w-20 px-2 py-1.5 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm text-center"
        />
      </div>

      <!-- Ends -->
      <div>
        <span class="block text-sm text-gray-700 dark:text-gray-300 mb-2">
          {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.ENDS_LABEL') }}
        </span>
        <div class="flex flex-col gap-2.5">
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="customEndsType"
              type="radio"
              value="never"
              class="text-woot-500"
            />
            <span class="text-sm text-gray-700 dark:text-gray-300">
              {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.ENDS_NEVER') }}
            </span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="customEndsType"
              type="radio"
              value="on_date"
              class="text-woot-500"
            />
            <span class="text-sm text-gray-700 dark:text-gray-300">
              {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.ENDS_ON') }}
            </span>
            <input
              v-if="customEndsType === 'on_date'"
              v-model="customEndsDate"
              type="date"
              class="px-2 py-1 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm"
            />
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="customEndsType"
              type="radio"
              value="after_count"
              class="text-woot-500"
            />
            <span class="text-sm text-gray-700 dark:text-gray-300">
              {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.ENDS_AFTER') }}
            </span>
            <input
              v-if="customEndsType === 'after_count'"
              v-model.number="customEndsAfterCount"
              type="number"
              min="1"
              max="999"
              class="w-16 px-2 py-1 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm text-center"
            />
            <span
              v-if="customEndsType === 'after_count'"
              class="text-sm text-gray-500"
            >
              {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.OCCURRENCES') }}
            </span>
          </label>
        </div>
      </div>
    </div>
  </div>
</template>
