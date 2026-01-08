<script>
import { DATE_RANGE_OPTIONS } from '../../constants';

const EVENT_NAME = 'on-range-change';

export default {
  name: 'ReportFiltersDateRange',
  props: {
    selectedDateRange: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    const translatedOptions = Object.values(DATE_RANGE_OPTIONS).map(option => ({
      ...option,
      name: this.$t(option.translationKey),
    }));

    return {
      options: translatedOptions,
      selectedOption: null, 
    };
  },
  watch: {
    selectedDateRange: {
      immediate: true,
      handler(newVal) {
        if (newVal && newVal.id) {
          const found = this.options.find(opt => opt.id === newVal.id);
          this.selectedOption = found || this.options[0];
        } else {
          this.selectedOption = this.options[0];
        }
      },
    },
  },
  methods: {
    updateRange(option) {
      this.$emit(EVENT_NAME, option);
    },
  },
};
</script>

<template>
  <div class="multiselect-wrap--small date-range-filter-container">
    <multiselect
      v-model="selectedOption"
      class="no-margin"
      track-by="id"
      label="name"
      :placeholder="$t('FORMS.MULTISELECT.SELECT_ONE')"
      :options="options"
      :searchable="false"
      :allow-empty="false"
      select-label=""
      selected-label=""
      deselect-label=""
      @select="updateRange"
    />
  </div>
</template>

<style lang="scss">
.date-range-filter-container {
  min-width: 200px;
  position: relative;

  .multiselect {
    min-height: 36px;
    
    .multiselect__tags {
      background-color: #ffffff;
      border: 1px solid #e5e7eb;
      border-radius: 6px;
      padding-top: 6px;
      padding-left: 10px;
      min-height: 36px;
    }

    .multiselect__single {
      background: transparent;
      margin-bottom: 0;
      padding-top: 2px;
      font-size: 0.875rem;
      font-weight: 500;
      color: #374151;
    }
    
    .multiselect__select {
      top: 2px;
    }

    .multiselect__content-wrapper {
      background-color: #ffffff !important;
      border: 1px solid #e5e7eb !important;
      border-radius: 8px !important;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05) !important;
      margin-top: 4px;
      padding: 4px 0;
      z-index: 99999 !important;
      position: absolute;
    }

    .multiselect__option {
      padding: 10px 12px;
      font-size: 0.875rem;
      color: #374151;
      background-color: #ffffff;
      
      &--highlight {
        background-color: #389947 !important;
        color: #ffffff !important;
      }
      
      &--selected {
        background-color: #ecfdf5 !important;
        color: #065f46 !important;
        font-weight: bold;
        
        &.multiselect__option--highlight {
            background-color: #389947 !important;
            color: #ffffff !important;
        }
      }
    }
  }
}

.dark .date-range-filter-container,
[data-theme="dark"] .date-range-filter-container {
  
  .multiselect__tags {
    background-color: #1f2937 !important;
    border-color: #374151 !important;
  }

  .multiselect__single {
    color: #f3f4f6 !important;
  }
  
  .multiselect__select:before {
    border-color: #9ca3af transparent transparent !important;
  }

  .multiselect__content-wrapper {
    background-color: #1f2937 !important;
    border-color: #374151 !important;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.5) !important;
  }

  .multiselect__option {
    background-color: #1f2937 !important;
    color: #d1d5db !important;
    
    &--highlight {
      background-color: #389947 !important;
      color: #ffffff !important;
    }
    
    &--selected {
      background-color: #064e3b !important;
      color: #ecfdf5 !important;
    }
  }
}
</style>