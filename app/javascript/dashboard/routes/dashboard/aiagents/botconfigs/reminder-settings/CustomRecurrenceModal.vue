<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const props = defineProps({
  rule: {
    type: Object,
    default: null,
  },
  scheduledAt: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['save', 'close']);

const wrapperRef = ref(null);

onMounted(() => {
  wrapperRef.value?.focus();
});

const DAYS_SHORT = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const FREQUENCY_OPTIONS = [
  { value: 'daily', label: 'day' },
  { value: 'weekly', label: 'week' },
  { value: 'monthly', label: 'month' },
  { value: 'yearly', label: 'year' },
];

const frequency = ref(props.rule?.frequency || 'weekly');
const interval = ref(props.rule?.interval || 1);
const daysOfWeek = ref([...(props.rule?.days_of_week || [])]);
const dayOfMonth = ref(props.rule?.day_of_month || null);
const endsType = ref('never');
const endsDate = ref('');
const endsAfterCount = ref(13);

const scheduledDate = computed(() => {
  return props.scheduledAt ? new Date(props.scheduledAt) : new Date();
});

// Auto-select current day when switching to weekly
watch(frequency, newFreq => {
  if (newFreq === 'weekly' && daysOfWeek.value.length === 0) {
    daysOfWeek.value = [scheduledDate.value.getDay()];
  }
  if (newFreq === 'monthly' && !dayOfMonth.value) {
    dayOfMonth.value = scheduledDate.value.getDate();
  }
});

const showDaySelector = computed(() => frequency.value === 'weekly');
const showDayOfMonth = computed(() => frequency.value === 'monthly');

const toggleDay = day => {
  const index = daysOfWeek.value.indexOf(day);
  if (index >= 0) {
    daysOfWeek.value.splice(index, 1);
  } else {
    daysOfWeek.value.push(day);
  }
};

const canSave = computed(() => {
  if (frequency.value === 'weekly' && daysOfWeek.value.length === 0)
    return false;
  if (interval.value < 1) return false;
  if (endsType.value === 'on_date' && !endsDate.value) return false;
  if (endsType.value === 'after_count' && endsAfterCount.value < 1)
    return false;
  return true;
});

const handleSave = () => {
  const rule = {
    frequency: frequency.value,
    interval: interval.value,
  };

  if (frequency.value === 'weekly') {
    rule.days_of_week = [...daysOfWeek.value].sort();
  }
  if (frequency.value === 'monthly') {
    rule.day_of_month = dayOfMonth.value;
  }

  const endData = {};
  if (endsType.value === 'on_date' && endsDate.value) {
    endData._ends_at = endsDate.value;
  }
  if (endsType.value === 'after_count' && endsAfterCount.value) {
    endData._ends_after_count = endsAfterCount.value;
  }

  const freqLabel = {
    daily: 'day',
    weekly: 'week',
    monthly: 'month',
    yearly: 'year',
  }[frequency.value];
  const pluralLabel = interval.value > 1 ? `${freqLabel}s` : freqLabel;
  let summary = `Every ${interval.value > 1 ? `${interval.value} ` : ''}${pluralLabel}`;
  if (frequency.value === 'weekly' && daysOfWeek.value.length) {
    const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    summary +=
      ' on ' +
      [...daysOfWeek.value].sort().map(d => DAY_NAMES[d]).join(', ');
  }

  emit('save', { ...rule, ...endData, _summary: summary });
};

const handleClose = () => {
  emit('close');
};
</script>

<template>
  <div
    ref="wrapperRef"
    class="fixed inset-0 z-[9999] flex items-center justify-center"
    tabindex="-1"
    @keydown.esc.stop="handleClose"
  >
    <!-- Backdrop: clicking this area closes the modal -->
    <div
      class="absolute inset-0 bg-n-alpha-black1 backdrop-blur-[4px]"
      @click="handleClose"
    />

    <!-- Card: stops clicks from propagating to backdrop -->
    <div
      class="relative z-10 w-full max-w-md mx-4 rounded-xl shadow-2xl bg-white dark:bg-slate-800 p-0 overflow-visible"
      @click.stop
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-gray-200 dark:border-gray-700"
      >
        <h3 class="text-base font-medium text-slate-900 dark:text-slate-100">
          Custom recurrence
        </h3>
        <button
          type="button"
          class="p-1 rounded hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
          @click="handleClose"
        >
          <span class="i-lucide-x size-4 text-gray-500 dark:text-gray-400" />
        </button>
      </div>

      <!-- Content -->
      <div class="flex flex-col gap-5 px-6 py-5">
        <!-- Repeat every N [unit] -->
        <div class="flex items-center gap-3">
          <span
            class="text-sm text-gray-700 dark:text-gray-300 whitespace-nowrap"
          >
            Repeat every
          </span>
          <input
            v-model.number="interval"
            type="number"
            min="1"
            max="99"
            class="w-16 px-2 py-1.5 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm text-center"
          />
          <select
            v-model="frequency"
            class="px-3 py-1.5 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm"
          >
            <option
              v-for="opt in FREQUENCY_OPTIONS"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}{{ interval > 1 ? 's' : '' }}
            </option>
          </select>
        </div>

        <!-- Repeat on days (weekly) -->
        <div v-if="showDaySelector">
          <span class="block text-sm text-gray-700 dark:text-gray-300 mb-2">
            Repeat on
          </span>
          <div class="flex gap-1.5">
            <button
              v-for="(label, index) in DAYS_SHORT"
              :key="index"
              type="button"
              class="w-9 h-9 rounded-full text-xs font-medium transition-all duration-150"
              :class="
                daysOfWeek.includes(index)
                  ? 'bg-woot-500 text-white shadow-sm'
                  : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
              "
              @click="toggleDay(index)"
            >
              {{ label }}
            </button>
          </div>
        </div>

        <!-- Day of month (monthly) -->
        <div v-if="showDayOfMonth">
          <span class="block text-sm text-gray-700 dark:text-gray-300 mb-2">
            On day
          </span>
          <input
            v-model.number="dayOfMonth"
            type="number"
            min="1"
            max="31"
            class="w-20 px-2 py-1.5 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm text-center"
          />
        </div>

        <!-- Ends -->
        <div>
          <span class="block text-sm text-gray-700 dark:text-gray-300 mb-2">
            {{ t('AGENT_MGMT.SALESBOT.REMINDER.ENDS_LABEL') }}
          </span>
          <div class="flex flex-col gap-2.5">
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                v-model="endsType"
                type="radio"
                value="never"
                class="text-woot-500"
              />
              <span class="text-sm text-gray-700 dark:text-gray-300">
                {{ t('AGENT_MGMT.SALESBOT.REMINDER.ENDS_NEVER') }}
              </span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                v-model="endsType"
                type="radio"
                value="on_date"
                class="text-woot-500"
              />
              <span class="text-sm text-gray-700 dark:text-gray-300">
                {{ t('AGENT_MGMT.SALESBOT.REMINDER.ENDS_ON') }}
              </span>
              <input
                v-if="endsType === 'on_date'"
                v-model="endsDate"
                type="date"
                class="px-2 py-1 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm"
              />
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                v-model="endsType"
                type="radio"
                value="after_count"
                class="text-woot-500"
              />
              <span class="text-sm text-gray-700 dark:text-gray-300">
                {{ t('AGENT_MGMT.SALESBOT.REMINDER.ENDS_AFTER') }}
              </span>
              <input
                v-if="endsType === 'after_count'"
                v-model.number="endsAfterCount"
                type="number"
                min="1"
                max="999"
                class="w-16 px-2 py-1 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-sm text-center"
              />
              <span
                v-if="endsType === 'after_count'"
                class="text-sm text-gray-500"
              >
                {{ t('AGENT_MGMT.SALESBOT.REMINDER.OCCURRENCES') }}
              </span>
            </label>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div
        class="flex justify-end gap-2 px-6 py-4 border-t border-gray-200 dark:border-gray-700"
      >
        <button
          type="button"
          class="px-4 py-2 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
          @click="handleClose"
        >
          {{ t('AGENT_MGMT.NOTIFICATION.CANCEL_BUTTON') }}
        </button>
        <button
          type="button"
          :disabled="!canSave"
          class="px-4 py-2 text-sm font-medium text-white bg-woot-500 rounded-lg hover:bg-woot-600 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="handleSave"
        >
          Done
        </button>
      </div>
    </div>
  </div>
</template>
