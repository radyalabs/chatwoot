<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/form/Input.vue';

const props = defineProps({
  visibleColumns: { type: Array, required: true },
  availableColumns: { type: Array, required: true },
  customAttributes: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'update:visibleColumns',
  'addCustomColumn',
  'removeCustomColumn',
]);

const { t } = useI18n();

const showSettings = ref(false);
const newColumnKey = ref('');
const newColumnLabel = ref('');

const mandatoryColumns = ['name', 'email', 'phoneNumber'];

const toggleColumn = columnKey => {
  if (mandatoryColumns.includes(columnKey)) return;

  const newVisible = props.visibleColumns.includes(columnKey)
    ? props.visibleColumns.filter(c => c !== columnKey)
    : [...props.visibleColumns, columnKey];

  emit('update:visibleColumns', newVisible);
};

const isColumnVisible = columnKey => props.visibleColumns.includes(columnKey);
const isMandatory = columnKey => mandatoryColumns.includes(columnKey);

const addCustomColumn = () => {
  if (!newColumnKey.value.trim() || !newColumnLabel.value.trim()) return;

  emit('addCustomColumn', {
    key: newColumnKey.value.trim(),
    label: newColumnLabel.value.trim(),
  });

  newColumnKey.value = '';
  newColumnLabel.value = '';
};

const removeCustomColumn = columnKey => {
  emit('removeCustomColumn', columnKey);
};

const allColumns = computed(() => [
  ...props.availableColumns.map(col => ({
    key: col,
    label: t(`CONTACTS_LAYOUT.TABLE.COLUMN.${col.toUpperCase()}`),
    isCustom: false,
  })),
  ...props.customAttributes.map(col => ({
    key: col.key,
    label: col.label,
    isCustom: true,
  })),
]);
</script>

<template>
  <div class="column-settings">
    <Button
      icon="i-lucide-settings-2"
      variant="ghost"
      size="sm"
      :label="t('CONTACTS_LAYOUT.TABLE.COLUMN_SETTINGS')"
      @click="showSettings = !showSettings"
    />

    <div v-if="showSettings" class="column-settings-dropdown">
      <div class="settings-header">
        <h4>{{ t('CONTACTS_LAYOUT.TABLE.COLUMN_SETTINGS_TITLE') }}</h4>
      </div>

      <div class="columns-list">
        <div
          v-for="column in allColumns"
          :key="column.key"
          class="column-item"
          :class="{ 'is-mandatory': isMandatory(column.key) }"
        >
          <label class="flex items-center gap-2">
            <input
              type="checkbox"
              :checked="isColumnVisible(column.key)"
              :disabled="isMandatory(column.key)"
              @change="toggleColumn(column.key)"
            />
            <span>{{ column.label }}</span>
          </label>
          <button
            v-if="column.isCustom"
            class="remove-btn"
            @click="removeCustomColumn(column.key)"
          >
            <span class="i-lucide-x" />
          </button>
        </div>
      </div>

      <div class="add-custom-column">
        <h5>{{ t('CONTACTS_LAYOUT.TABLE.ADD_CUSTOM_COLUMN') }}</h5>
        <div class="flex gap-2">
          <Input
            v-model="newColumnKey"
            :placeholder="t('CONTACTS_LAYOUT.TABLE.COLUMN_KEY')"
            class="flex-1"
          />
          <Input
            v-model="newColumnLabel"
            :placeholder="t('CONTACTS_LAYOUT.TABLE.COLUMN_LABEL')"
            class="flex-1"
          />
          <Button icon="i-lucide-plus" size="sm" @click="addCustomColumn" />
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.column-settings {
  @apply relative;

  .column-settings-dropdown {
    @apply absolute right-0 top-full mt-2 z-50 w-80 bg-n-solid-2 border border-n-weak rounded-lg shadow-lg;
  }

  .settings-header {
    @apply p-4 border-b border-n-weak;

    h4 {
      @apply font-medium text-n-slate-12 m-0;
    }
  }

  .columns-list {
    @apply p-4 max-h-64 overflow-y-auto;
  }

  .column-item {
    @apply flex items-center justify-between py-2;

    &.is-mandatory {
      @apply opacity-60;
    }

    label {
      @apply flex items-center gap-2 cursor-pointer;

      input[type='checkbox'] {
        @apply w-4 h-4 rounded;
      }
    }

    .remove-btn {
      @apply p-1 hover:bg-n-weak rounded;
    }
  }

  .add-custom-column {
    @apply p-4 border-t border-n-weak;

    h5 {
      @apply font-medium text-n-slate-12 mb-2 text-sm;
    }
  }
}
</style>
