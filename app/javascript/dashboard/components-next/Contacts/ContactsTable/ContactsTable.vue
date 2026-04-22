<script setup>
import { computed, h } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
} from '@tanstack/vue-table';
import { useMapGetter } from 'dashboard/composables/store';

import Table from 'dashboard/components/table/Table.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contacts: { type: Array, required: true },
  customAttributes: { type: Array, default: () => [] },
  mandatoryColumns: {
    type: Array,
    default: () => [
      'name',
      'email',
      'phoneNumber',
      'companyName',
      'location',
      'createdAt',
    ],
  },
});

const emit = defineEmits(['sendMessage', 'viewContact']);

const { t } = useI18n();

const uiFlags = useMapGetter('contacts/getUIFlags');
// eslint-disable-next-line no-unused-vars
const isUpdating = computed(() => uiFlags.value?.isUpdating || false);

const columnHelper = createColumnHelper();

const formatDate = timestamp => {
  if (!timestamp) return '---';
  return new Date(timestamp * 1000).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const formatLocation = additionalAttributes => {
  if (!additionalAttributes) return '---';
  const { country, countryCode, city } = additionalAttributes;
  if (!country && !countryCode && !city) return '---';

  const flag = countryCode
    ? `<span class="fi fi-${countryCode.toLowerCase()} mr-1"></span>`
    : '';
  const locationText = [city, country].filter(Boolean).join(', ');
  return flag + locationText;
};

const formatCompanyName = additionalAttributes => {
  return additionalAttributes?.companyName || '---';
};

const onClickViewDetails = id => {
  emit('viewContact', id);
};

const onSendMessage = id => {
  emit('sendMessage', id);
};

const columns = computed(() => {
  const cols = [];

  if (props.mandatoryColumns.includes('name')) {
    cols.push(
      columnHelper.accessor('name', {
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.NAME'),
        cell: ({ row }) => {
          const contact = row.original;
          return h('div', { class: 'flex items-center gap-3' }, [
            h(Avatar, {
              name: contact.name,
              src: contact.thumbnail,
              size: 32,
            }),
            h('div', { class: 'flex flex-col' }, [
              h(
                'span',
                { class: 'font-medium text-n-slate-12' },
                contact.name || '---'
              ),
              contact.email
                ? h('span', { class: 'text-xs text-n-slate-10' }, contact.email)
                : null,
            ]),
          ]);
        },
        size: 250,
      })
    );
  }

  if (props.mandatoryColumns.includes('phoneNumber')) {
    cols.push(
      columnHelper.accessor('phoneNumber', {
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.PHONE'),
        cell: ({ getValue }) => {
          const value = getValue();
          return h('span', {}, value || '---');
        },
        size: 150,
      })
    );
  }

  if (props.mandatoryColumns.includes('companyName')) {
    cols.push(
      columnHelper.accessor('additionalAttributes', {
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.COMPANY'),
        cell: ({ getValue }) => {
          const value = formatCompanyName(getValue());
          return h(
            'span',
            { class: value === '---' ? 'text-n-slate-8' : '' },
            value
          );
        },
        size: 180,
      })
    );
  }

  if (props.mandatoryColumns.includes('location')) {
    cols.push(
      columnHelper.accessor('additionalAttributes', {
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.LOCATION'),
        cell: ({ getValue }) => {
          const value = formatLocation(getValue());
          return h(
            'span',
            {
              class: value === '---' ? 'text-n-slate-8' : '',
              innerHTML: value,
            },
            ''
          );
        },
        size: 180,
      })
    );
  }

  if (props.mandatoryColumns.includes('createdAt')) {
    cols.push(
      columnHelper.accessor('createdAt', {
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.CREATED_AT'),
        cell: ({ getValue }) => {
          const value = getValue();
          return h('span', {}, formatDate(value));
        },
        size: 120,
      })
    );
  }

  if (props.mandatoryColumns.includes('lastActivityAt')) {
    cols.push(
      columnHelper.accessor('lastActivityAt', {
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.LAST_ACTIVITY'),
        cell: ({ getValue }) => {
          const value = getValue();
          return h('span', {}, formatDate(value));
        },
        size: 140,
      })
    );
  }

  props.customAttributes.forEach(attr => {
    cols.push(
      columnHelper.accessor('customAttributes', {
        id: attr.key,
        header: attr.label || attr.key,
        cell: ({ row }) => {
          const customAttrs = row.original.customAttributes || {};
          const value = customAttrs[attr.key];
          return h(
            'span',
            { class: value ? '' : 'text-n-slate-8' },
            value || '---'
          );
        },
        size: 150,
      })
    );
  });

  cols.push(
    columnHelper.display({
      id: 'actions',
      header: '',
      cell: ({ row }) => {
        const contact = row.original;
        return h('div', { class: 'flex items-center gap-2' }, [
          h(Button, {
            icon: 'i-lucide-message-circle',
            variant: 'ghost',
            size: 'xs',
            'aria-label': t('CONTACTS_LAYOUT.TABLE.SEND_MESSAGE'),
            onClick: () => onSendMessage(contact.id),
          }),
          h(Button, {
            icon: 'i-lucide-eye',
            variant: 'ghost',
            size: 'xs',
            'aria-label': t('CONTACTS_LAYOUT.TABLE.VIEW_DETAILS'),
            onClick: () => onClickViewDetails(contact.id),
          }),
        ]);
      },
      size: 100,
    })
  );

  return cols;
});

const table = useVueTable({
  get data() {
    return props.contacts;
  },
  columns: columns.value,
  getCoreRowModel: getCoreRowModel(),
  enableSorting: true,
});
</script>

<template>
  <div class="contacts-table-container">
    <div class="table-wrapper overflow-x-auto">
      <Table :table="table" class="w-full min-w-[800px]" />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.contacts-table-container {
  @apply flex flex-col flex-1;

  .table-wrapper {
    @apply overflow-x-auto;
  }
}
</style>
