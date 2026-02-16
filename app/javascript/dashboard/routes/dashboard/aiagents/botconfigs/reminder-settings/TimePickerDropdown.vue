<script setup>
import { ref, watch, nextTick, onMounted, onBeforeUnmount } from 'vue';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  placeholder: {
    type: String,
    default: 'Select time',
  },
});

const emit = defineEmits(['update:modelValue']);

const isOpen = ref(false);
const containerRef = ref(null);
const hourColRef = ref(null);
const minuteColRef = ref(null);

const HOURS = Array.from({ length: 24 }, (_, i) =>
  String(i).padStart(2, '0')
);
const MINUTES = Array.from({ length: 12 }, (_, i) =>
  String(i * 5).padStart(2, '0')
);

const ITEM_H = 36;
const VISIBLE = 5;
const PAD = Math.floor(VISIBLE / 2) * ITEM_H;

const selectedHour = ref('09');
const selectedMinute = ref('00');

watch(
  () => props.modelValue,
  val => {
    if (!val || !val.includes(':')) return;
    const [h, m] = val.split(':');
    selectedHour.value = h.padStart(2, '0');
    const min = parseInt(m, 10);
    const snapped = Math.round(min / 5) * 5;
    selectedMinute.value = String(
      snapped >= 60 ? 55 : snapped
    ).padStart(2, '0');
  },
  { immediate: true }
);

const emitValue = () => {
  emit('update:modelValue', `${selectedHour.value}:${selectedMinute.value}`);
};

const scrollTo = (el, idx, smooth = false) => {
  if (!el) return;
  el.scrollTo({ top: idx * ITEM_H, behavior: smooth ? 'smooth' : 'instant' });
};

let hTimer = null;
let mTimer = null;

const onHourScroll = () => {
  clearTimeout(hTimer);
  hTimer = setTimeout(() => {
    if (!hourColRef.value) return;
    const idx = Math.round(hourColRef.value.scrollTop / ITEM_H);
    const clamped = Math.max(0, Math.min(idx, HOURS.length - 1));
    selectedHour.value = HOURS[clamped];
    emitValue();
  }, 80);
};

const onMinuteScroll = () => {
  clearTimeout(mTimer);
  mTimer = setTimeout(() => {
    if (!minuteColRef.value) return;
    const idx = Math.round(minuteColRef.value.scrollTop / ITEM_H);
    const clamped = Math.max(0, Math.min(idx, MINUTES.length - 1));
    selectedMinute.value = MINUTES[clamped];
    emitValue();
  }, 80);
};

const clickHour = (h, i) => {
  selectedHour.value = h;
  scrollTo(hourColRef.value, i, true);
  emitValue();
};

const clickMinute = (m, i) => {
  selectedMinute.value = m;
  scrollTo(minuteColRef.value, i, true);
  emitValue();
};

const toggle = () => {
  if (isOpen.value) {
    isOpen.value = false;
    return;
  }
  if (!props.modelValue) {
    const now = new Date();
    selectedHour.value = String(now.getHours()).padStart(2, '0');
    const snapped = Math.round(now.getMinutes() / 5) * 5;
    selectedMinute.value = String(
      snapped >= 60 ? 0 : snapped
    ).padStart(2, '0');
    emitValue();
  }
  isOpen.value = true;
  nextTick(() => {
    scrollTo(hourColRef.value, Math.max(0, HOURS.indexOf(selectedHour.value)));
    scrollTo(
      minuteColRef.value,
      Math.max(0, MINUTES.indexOf(selectedMinute.value))
    );
  });
};

const handleClickOutside = e => {
  if (containerRef.value && !containerRef.value.contains(e.target)) {
    isOpen.value = false;
  }
};

onMounted(() => document.addEventListener('mousedown', handleClickOutside));
onBeforeUnmount(() => {
  document.removeEventListener('mousedown', handleClickOutside);
  clearTimeout(hTimer);
  clearTimeout(mTimer);
});
</script>

<template>
  <div ref="containerRef" class="relative">
    <button
      type="button"
      class="w-full flex items-center gap-2 p-2.5 text-sm text-left border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 hover:border-gray-400 dark:hover:border-gray-500 focus:ring-2 focus:ring-green-500 transition-all"
      @click="toggle"
    >
      <span
        class="i-lucide-clock size-4 text-slate-400 dark:text-slate-500 shrink-0"
      />
      <span
        class="flex-1"
        :class="{ 'text-slate-400 dark:text-slate-500': !modelValue }"
      >
        {{ modelValue || placeholder }}
      </span>
      <span
        class="i-lucide-chevron-down size-4 text-slate-400 shrink-0 transition-transform duration-200"
        :class="{ 'rotate-180': isOpen }"
      />
    </button>

    <div
      v-if="isOpen"
      class="absolute z-50 mt-1 w-full bg-white dark:bg-slate-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg overflow-hidden"
    >
      <div class="relative flex" :style="{ height: VISIBLE * ITEM_H + 'px' }">
        <!-- Center highlight band -->
        <div
          class="absolute inset-x-2 pointer-events-none z-10 border-y border-green-500/30 bg-green-50/50 dark:bg-green-900/20 rounded-sm"
          :style="{ top: PAD + 'px', height: ITEM_H + 'px' }"
        />

        <!-- Hour column -->
        <div
          ref="hourColRef"
          class="flex-1 overflow-y-auto scroll-col"
          :style="{
            paddingTop: PAD + 'px',
            paddingBottom: PAD + 'px',
          }"
          @scroll="onHourScroll"
        >
          <button
            v-for="(h, i) in HOURS"
            :key="h"
            type="button"
            class="snap-item w-full text-center text-sm transition-colors"
            :class="
              h === selectedHour
                ? 'text-green-600 dark:text-green-400 font-semibold'
                : 'text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-200'
            "
            @click="clickHour(h, i)"
          >
            {{ h }}
          </button>
        </div>

        <!-- Separator -->
        <div
          class="flex items-center justify-center w-5 text-slate-400 dark:text-slate-500 font-bold text-base select-none pointer-events-none"
        >
          :
        </div>

        <!-- Minute column -->
        <div
          ref="minuteColRef"
          class="flex-1 overflow-y-auto scroll-col"
          :style="{
            paddingTop: PAD + 'px',
            paddingBottom: PAD + 'px',
          }"
          @scroll="onMinuteScroll"
        >
          <button
            v-for="(m, i) in MINUTES"
            :key="m"
            type="button"
            class="snap-item w-full text-center text-sm transition-colors"
            :class="
              m === selectedMinute
                ? 'text-green-600 dark:text-green-400 font-semibold'
                : 'text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-200'
            "
            @click="clickMinute(m, i)"
          >
            {{ m }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.scroll-col {
  scroll-snap-type: y mandatory;
  overscroll-behavior: contain;
  scrollbar-width: none;
  -ms-overflow-style: none;
  mask-image: linear-gradient(
    to bottom,
    transparent 0%,
    black 25%,
    black 75%,
    transparent 100%
  );
  -webkit-mask-image: linear-gradient(
    to bottom,
    transparent 0%,
    black 25%,
    black 75%,
    transparent 100%
  );
}
.scroll-col::-webkit-scrollbar {
  display: none;
}
.snap-item {
  height: 36px;
  line-height: 36px;
  scroll-snap-align: center;
  scroll-snap-stop: always;
}
</style>
