<template>
  <div class="bg-white dark:bg-[#1a1d24] border border-slate-200 dark:border-slate-700/60 rounded-xl p-5 shadow-sm">
    <div class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
      <span class="i-lucide-list-filter w-4 h-4 text-green-600"></span>
      Filter Kontak
    </div>

    <div
      v-for="(filter, index) in filters"
      :key="index"
      class="flex flex-col md:flex-row items-start md:items-center gap-3 mb-4 w-full"
    >
      <div class="w-full md:w-[28%] shrink-0">
        <multiselect
          v-model="filter.attributeKey"
          :options="filterTypeOptions"
          track-by="attributeKey"
          label="label"
          :allow-empty="false"
          :searchable="true"
          select-label=""
          deselect-label=""
          placeholder="Pilih Atribut"
          class="w-full compact-dropdown"
          @select="onAttributeChange(index)"
        />
      </div>

      <div v-if="filter.attributeKey" class="w-full md:w-[28%] shrink-0">
        <multiselect
          v-model="filter.filterOperator"
          :options="getOperatorsFor(filter.attributeKey)"
          track-by="value"
          label="label"
          :allow-empty="false"
          :searchable="false"
          select-label=""
          deselect-label=""
          placeholder="Pilih Operator"
          class="w-full compact-dropdown"
        />
      </div>

      <div 
        v-if="filter.attributeKey && filter.filterOperator && !['is_present', 'is_not_present'].includes(filter.filterOperator.value)" 
        class="w-full flex-1 min-w-[200px]"
      >
        <input
          v-if="getInputType(filter.attributeKey) === 'date'"
          v-model="filter.value"
          type="date"
          class="w-full px-3 py-2.5 text-sm bg-transparent border border-slate-300 dark:border-slate-600 rounded-md text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-green-600 focus:border-green-600 transition-colors"
        />

        <multiselect
          v-else-if="getInputType(filter.attributeKey) === 'search_select'"
          v-model="filter.value"
          :options="getSelectOptions(filter.attributeKey)"
          track-by="value"
          label="label"
          :allow-empty="true"
          :searchable="true"
          select-label=""
          deselect-label=""
          placeholder="Masukkan data..."
          class="w-full compact-dropdown"
        />

        <input
          v-else
          v-model="filter.value"
          type="text"
          placeholder="Masukkan nilai data..."
          class="w-full px-3 py-2.5 text-sm bg-transparent border border-slate-300 dark:border-slate-600 rounded-md text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-green-600 focus:border-green-600 transition-colors"
          @keyup.enter="applyFilter"
        />
      </div>

      <button
        type="button"
        class="p-2.5 text-slate-400 hover:text-red-500 transition-colors focus:outline-none shrink-0"
        title="Hapus filter ini"
        @click="removeFilter(index)"
      >
        <span class="i-lucide-trash-2 w-4 h-4 block" />
      </button>
    </div>

    <div class="flex items-center justify-between mt-5 pt-4 border-t border-slate-100 dark:border-slate-700/50">
      <button
        type="button"
        class="text-sm font-medium text-blue-600 hover:text-blue-700 dark:text-blue-400 flex items-center gap-1.5 focus:outline-none transition-colors"
        @click="addFilter"
      >
        <span class="i-lucide-plus w-4 h-4" />
        Tambah filter
      </button>

      <div class="flex items-center gap-3">
        <span v-if="isFetchingCount" class="text-xs text-slate-500 flex items-center gap-1.5 mr-2">
          <svg class="animate-spin w-3.5 h-3.5" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          Menghitung...
        </span>

        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-md transition-colors focus:outline-none"
          @click="clearFilters"
        >
          Clear filters
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-semibold bg-green-600 text-white hover:bg-green-700 rounded-md transition-colors focus:outline-none"
          @click="applyFilter"
        >
          Terapkan filter
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import Multiselect from 'vue-multiselect';
import filterTypes from 'dashboard/routes/dashboard/contacts/contactFilterItems';
import COUNTRIES from 'shared/constants/countries';

const NO_VALUE_OPERATORS = new Set(['is_present', 'is_not_present']);
const BLOCKED_OPTIONS = [{ label: 'Ya', value: 'true' }, { label: 'Tidak', value: 'false' }];

function makeEmptyFilter() {
  return {
    attributeKey: null,
    filterOperator: null,
    value: '',
    queryOperator: 'AND',
  };
}

export default {
  name: 'ContactFilterBroadcast',
  components: { Multiselect },

  props: {
    estimatedCount: { type: Number, default: null },
    isFetchingCount: { type: Boolean, default: false },
  },

  emits: ['update:queryPayload'],

  data() {
    return {
      filters: [makeEmptyFilter()],
    };
  },

  computed: {
    filterTypeOptions() {
      return filterTypes.map(ft => ({
        ...ft,
        label: this.$t(`CONTACTS_FILTER.ATTRIBUTES.${ft.attributeI18nKey}`) || ft.attributeI18nKey,
      }));
    },
  },

  methods: {
    getOperatorsFor(attributeKeyObj) {
      if (!attributeKeyObj) return [];
      const ft = filterTypes.find(f => f.attributeKey === attributeKeyObj.attributeKey);
      if (!ft) return [];
      return (ft.filterOperators || []).map(op => ({
        value: op.value,
        label: this.$t(`CONTACTS_FILTER.OPERATOR_LABELS.${op.value}`) || op.value,
      }));
    },

    getInputType(attributeKeyObj) {
      if (!attributeKeyObj) return 'plain_text';
      const ft = filterTypes.find(f => f.attributeKey === attributeKeyObj.attributeKey);
      return ft?.inputType ?? 'plain_text';
    },

    getSelectOptions(attributeKeyObj) {
      if (!attributeKeyObj) return [];
      if (attributeKeyObj.attributeKey === 'country_code') {
        return COUNTRIES.map(c => ({ label: c.name, value: c.dial_code }));
      }
      if (attributeKeyObj.attributeKey === 'blocked') {
        return BLOCKED_OPTIONS;
      }
      return [];
    },

    onAttributeChange(index) {
      this.filters[index].filterOperator = null;
      this.filters[index].value = '';
    },

    addFilter() {
      this.filters.push(makeEmptyFilter());
    },

    removeFilter(index) {
      if (this.filters.length === 1) {
        this.filters = [makeEmptyFilter()];
      } else {
        this.filters.splice(index, 1);
      }
      this.applyFilter();
    },

    clearFilters() {
      this.filters = [makeEmptyFilter()];
      this.emitQueryPayload();
    },

    applyFilter() {
      this.emitQueryPayload();
    },

    buildFilterPayload() {
      return this.filters
        .filter(f => {
          if (!f.attributeKey || !f.filterOperator) return false;
          if (NO_VALUE_OPERATORS.has(f.filterOperator.value)) return true;
          const val = typeof f.value === 'object' ? f.value?.value : f.value;
          return val !== '' && val !== null && val !== undefined;
        })
        .map((f, idx) => {
          const val = typeof f.value === 'object' ? f.value?.value : f.value;
          return {
            attribute_key:   f.attributeKey.attributeKey,
            attribute_model: f.attributeKey.attribute_type ?? 'standard',
            filter_operator: f.filterOperator.value,
            values: NO_VALUE_OPERATORS.has(f.filterOperator.value) ? [] : [val],
            query_operator: idx === 0 ? null : 'AND',
            data_type: f.attributeKey.dataType,
          };
        });
    },

    emitQueryPayload() {
      const payload = this.buildFilterPayload();
      this.$emit('update:queryPayload', payload.length ? payload : null);
    },
  }
};
</script>

<style scoped>
.compact-dropdown {
  @apply text-sm text-slate-700 dark:text-slate-200;
}
:deep(.compact-dropdown .multiselect__tags) {
  @apply bg-transparent border-slate-300 dark:border-slate-600 rounded-md min-h-[42px] flex items-center px-3 py-0;
}
:deep(.compact-dropdown .multiselect__input) {
  @apply bg-transparent dark:text-white pt-0 pb-0 mb-0;
}
:deep(.compact-dropdown .multiselect__single) {
  @apply bg-transparent dark:text-white pt-0 pb-0 mb-0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 90%;
}
:deep(.compact-dropdown .multiselect__select) {
  @apply h-[40px] top-0;
}
:deep(.compact-dropdown .multiselect__content-wrapper) {
  @apply bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 z-50 rounded-lg shadow-lg mt-1;
}
</style>