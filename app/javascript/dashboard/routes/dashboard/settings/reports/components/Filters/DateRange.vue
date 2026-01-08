<script>
import { DATE_RANGE_OPTIONS } from '../../constants';

const EVENT_NAME = 'on-range-change';

export default {
  name: 'ReportFiltersDateRange',
  data() {
    const translatedOptions = Object.values(DATE_RANGE_OPTIONS).map(option => ({
      ...option,
      name: this.$t(option.translationKey),
    }));

    return {
      selectedOption: translatedOptions[0], // Default 7 hari terakhir
      options: translatedOptions,
    };
  },
  methods: {
    updateRange(selectedRange) {
      this.selectedOption = selectedRange;
      this.$emit(EVENT_NAME, selectedRange);
    },
  },
};
</script>

<template>
  <div class="multiselect-wrap--small date-range-filter-container">
    <multiselect
      v-model="selectedOption"
      class="no-margin"
      track-by="name"
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
  position: relative; /* Penting untuk konteks stacking */

  .multiselect {
    min-height: 36px;
    
    /* Tombol Input Utama */
    .multiselect__tags {
      background-color: #ffffff;
      border: 1px solid #e5e7eb;
      border-radius: 6px;
      padding-top: 6px;
      padding-left: 10px;
      min-height: 36px;
    }

    /* Teks Pilihan Aktif */
    .multiselect__single {
      background: transparent;
      margin-bottom: 0;
      padding-top: 2px;
      font-size: 0.875rem;
      font-weight: 500;
      color: #374151;
    }
    
    /* Icon Panah */
    .multiselect__select {
      top: 2px;
    }

    .multiselect__content-wrapper {
      background-color: #ffffff !important; /* Warna Putih Solid (Light Mode) */
      border: 1px solid #e5e7eb !important;
      border-radius: 8px !important;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05) !important;
      margin-top: 4px;
      padding: 4px 0;
      z-index: 99999 !important; /* Z-Index sangat tinggi agar di atas segalanya */
      position: absolute;
    }

    .multiselect__option {
      padding: 10px 12px;
      font-size: 0.875rem;
      color: #374151;
      background-color: #ffffff; /* Pastikan item juga punya background */
      
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
    background-color: #1f2937 !important; /* Gray 800 Solid */
    border-color: #374151 !important;
  }

  .multiselect__single {
    color: #f3f4f6 !important; /* Text Putih */
  }
  
  .multiselect__select:before {
    border-color: #9ca3af transparent transparent !important;
  }

  /* Dropdown Menu Dark Mode */
  .multiselect__content-wrapper {
    background-color: #1f2937 !important; /* Gray 800 Solid (Tidak Transparan) */
    border-color: #374151 !important;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.5) !important;
  }

  .multiselect__option {
    background-color: #1f2937 !important; /* Gray 800 */
    color: #d1d5db !important; /* Text Gray 300 */
    
    &--highlight {
      background-color: #389947 !important; /* Hijau Chatwoot */
      color: #ffffff !important;
    }
    
    &--selected {
      background-color: #064e3b !important; /* Hijau Tua */
      color: #ecfdf5 !important;
    }
  }
}

@media (prefers-color-scheme: dark) {
  .date-range-filter-container .multiselect__tags {
    background-color: #1f2937 !important;
    border-color: #374151 !important;
  }
  .date-range-filter-container .multiselect__single {
    color: #f3f4f6 !important;
  }
  .date-range-filter-container .multiselect__content-wrapper {
    background-color: #1f2937 !important;
    border-color: #374151 !important;
  }
  .date-range-filter-container .multiselect__option {
    background-color: #1f2937 !important;
    color: #d1d5db !important;
  }
  .date-range-filter-container .multiselect__option--highlight {
    background-color: #389947 !important;
    color: #ffffff !important;
  }
}
</style>