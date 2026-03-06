<script>
import parse from 'date-fns/parse';
import differenceInMinutes from 'date-fns/differenceInMinutes';
import { generateTimeSlots } from '../helpers/businessHour';

const timeSlots = generateTimeSlots(30);

export default {
  components: {},
  props: {
    dayName: {
      type: String,
      required: true,
    },
    timeSlot: {
      type: Object,
      default: () => ({
        from: '',
        to: '',
      }),
    },
  },
  emits: ['update'],
  computed: {
    fromTimeSlots() {
      return timeSlots;
    },
    toTimeSlots() {
      return timeSlots.filter(slot => {
        return slot !== '00:00';
      });
    },
    isDayEnabled: {
      get() {
        return Boolean(this.timeSlot.from && this.timeSlot.to);
      },
      set(value) {
        const newSlot = value
          ? {
              ...this.timeSlot,
              from: timeSlots[0],
              to: timeSlots[16],
              valid: true,
              openAllDay: false,
            }
          : {
              ...this.timeSlot,
              from: '',
              to: '',
              valid: false,
              openAllDay: false,
            };
        this.$emit('update', newSlot);
      },
    },
    fromTime: {
      get() {
        return this.timeSlot.from;
      },
      set(value) {
        const fromDate = parse(value, 'HH:mm', new Date());
        const valid = differenceInMinutes(this.toDate, fromDate) / 60 > 0;
        this.$emit('update', {
          ...this.timeSlot,
          from: value,
          valid,
        });
      },
    },
    toTime: {
      get() {
        return this.timeSlot.to;
      },
      set(value) {
        const toDate = parse(value, 'HH:mm', new Date());
        if (value === '00:00') {
          this.$emit('update', {
            ...this.timeSlot,
            to: value,
            valid: true,
          });
        } else {
          const valid = differenceInMinutes(toDate, this.fromDate) / 60 > 0;
          this.$emit('update', {
            ...this.timeSlot,
            to: value,
            valid,
          });
        }
      },
    },
    fromDate() {
      return parse(this.fromTime, 'HH:mm', new Date());
    },
    toDate() {
      return parse(this.toTime, 'HH:mm', new Date());
    },
    totalHours() {
      if (this.timeSlot.openAllDay) {
        return 24;
      }
      const totalHours = differenceInMinutes(this.toDate, this.fromDate) / 60;
      return totalHours;
    },
    hasError() {
      return !this.timeSlot.valid;
    },
    isOpenAllDay: {
      get() {
        return this.timeSlot.openAllDay;
      },
      set(value) {
        if (value) {
          this.$emit('update', {
            ...this.timeSlot,
            from: '00:00',
            to: '23:59',
            valid: true,
            openAllDay: value,
          });
        } else {
          this.$emit('update', {
            ...this.timeSlot,
            from: '09:00',
            to: '17:00',
            valid: true,
            openAllDay: value,
          });
        }
      },
    },
  },
};
</script>

<template>
  <div
    class="day-wrap flex py-2 px-0 min-h-[3rem] box-content border-b border-solid border-slate-50 dark:border-slate-600"
  >
    <div class="checkbox-wrap flex items-center">
      <input
        v-model="isDayEnabled"
        name="enable-day"
        class="m-0"
        type="checkbox"
        :title="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.ENABLE')"
      />
    </div>
    <div
      class="day flex items-center py-0 px-3 text-sm font-medium flex-shrink-0 min-w-28"
    >
      <span>{{ dayName }}</span>
    </div>
    <div
      v-if="isDayEnabled"
      class="flex flex-col flex-shrink-0 flex-grow relative"
    >
      <div class="flex items-center flex-shrink-0 flex-grow">
        <div class="checkbox-wrap flex items-center open-all-day mr-6">
          <input
            v-model="isOpenAllDay"
            name="enable-open-all-day"
            class="enable-checkbox text-sm font-medium"
            type="checkbox"
            :title="$t('INBOX_MGMT.BUSINESS_HOURS.ALL_DAY')"
          />
          <span class="text-sm font-medium ml-1">{{
            $t('INBOX_MGMT.BUSINESS_HOURS.ALL_DAY')
          }}</span>
        </div>
        <multiselect
          v-model="fromTime"
          :options="fromTimeSlots"
          deselect-label=""
          select-label=""
          selected-label=""
          :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
          :allow-empty="false"
          :disabled="isOpenAllDay"
        />
        <div class="separator-icon flex items-center py-0 px-3">
          <fluent-icon icon="subtract" type="solid" size="16" />
        </div>
        <multiselect
          v-model="toTime"
          :options="toTimeSlots"
          deselect-label=""
          select-label=""
          selected-label=""
          :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
          :allow-empty="false"
          :disabled="isOpenAllDay"
        />
      </div>
      <div v-if="hasError" class="date-error pt-1">
        <span class="error text-xs text-red-300 dark:text-red-500">{{
          $t('INBOX_MGMT.BUSINESS_HOURS.DAY.VALIDATION_ERROR')
        }}</span>
      </div>
    </div>
    <div
      v-else
      class="flex items-center flex-shrink-0 flex-grow text-sm text-slate-500 dark:text-slate-300"
    >
      <span>
        {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.UNAVAILABLE') }}
      </span>
    </div>
    <div>
      <span
        v-if="isDayEnabled && !hasError"
        class="label bg-woot-50 dark:bg-woot-600 text-woot-700 dark:text-woot-100 text-xs inline-block px-2 py-1 rounded-sm cursor-default whitespace-nowrap"
      >
        {{ totalHours }} {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.HOURS') }}
      </span>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.day-wrap::v-deep .multiselect {
  @apply m-0 w-[7.5rem];

  > .multiselect__tags {
    @apply pl-3;

    .multiselect__single {
      @apply text-sm leading-6 py-2 px-0;
    }
  }
}
</style>
