<script setup>
import { computed, h, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
} from '@tanstack/vue-table';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Table from 'dashboard/components/table/Table.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';

const props = defineProps({
  contacts: { type: Array, required: true },
  customAttributes: { type: Array, default: () => [] },
  visibleColumns: {
    type: Array,
    default: () => ['name', 'phoneNumber', 'companyName', 'location'],
  },
});

const emit = defineEmits(['viewContact']);

const { t } = useI18n();
const store = useStore();

const uiFlags = useMapGetter('contacts/getUIFlags');
const isUpdating = computed(() => uiFlags.value?.isUpdating || false);

const columnHelper = createColumnHelper();

const contactForEdit = ref(null);
const contactsFormRef = ref(null);
const editDialogRef = ref(null);
const removedCustomAttrs = ref([]);

const getContactData = contact => ({
  id: contact.id,
  name: contact.name,
  email: contact.email,
  phoneNumber: contact.phoneNumber,
  additionalAttributes: contact.additionalAttributes || {},
  customAttributes: contact.customAttributes || {},
});

const openEditModal = contact => {
  contactForEdit.value = getContactData(contact);
  removedCustomAttrs.value = [];
  editDialogRef.value?.open();
};

const closeEditModal = () => {
  editDialogRef.value?.close();
};

const onDialogClose = () => {
  contactForEdit.value = null;
};

const handleFormUpdate = updatedData => {
  Object.assign(contactForEdit.value, updatedData);
};

const handleRemoveCustomAttr = key => {
  if (!contactForEdit.value) return;
  const newAttrs = { ...contactForEdit.value.customAttributes };
  delete newAttrs[key];
  contactForEdit.value = { ...contactForEdit.value, customAttributes: newAttrs };
  if (!removedCustomAttrs.value.includes(key)) {
    removedCustomAttrs.value = [...removedCustomAttrs.value, key];
  }
};

const handleUpdateContact = async () => {
  if (!contactForEdit.value) return;
  try {
    if (removedCustomAttrs.value.length > 0) {
      await store.dispatch('contacts/deleteCustomAttributes', {
        id: contactForEdit.value.id,
        customAttributes: removedCustomAttrs.value,
      });
    }
    await store.dispatch('contacts/update', contactForEdit.value);
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'));
    closeEditModal();
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.ERROR_MESSAGE'));
  }
};

const onClickViewDetails = id => {
  emit('viewContact', id);
};

const formatDate = timestamp => {
  if (!timestamp) return '---';
  return new Date(timestamp * 1000).toLocaleDateString('id-ID', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const formatLocation = additionalAttributes => {
  if (!additionalAttributes) return '---';
  const { country, city } = additionalAttributes;
  if (!country && !city) return '---';
  return [city, country].filter(Boolean).join(', ');
};

const formatCompanyName = additionalAttributes => {
  return additionalAttributes?.companyName || '---';
};

const columns = computed(() => {
  const cols = [];

  if (props.visibleColumns.includes('name')) {
    cols.push(
      columnHelper.display({
        id: 'name',
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.NAME'),
        cell: ({ row }) => {
          const contact = row.original;
          return h('div', { class: 'flex items-center gap-3' }, [
            h(Avatar, { name: contact.name, src: contact.thumbnail, size: 36 }),
            h('div', { class: 'flex flex-col' }, [
              h('span', { class: 'font-medium text-n-slate-12' }, contact.name || '---'),
              props.visibleColumns.includes('email') && contact.email
                ? h('span', { class: 'text-xs text-n-slate-10' }, contact.email)
                : null,
            ]),
          ]);
        },
        size: 250,
      })
    );
  }

  if (!props.visibleColumns.includes('name') && props.visibleColumns.includes('email')) {
    cols.push(
      columnHelper.display({
        id: 'email',
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.EMAIL'),
        cell: ({ row }) => {
          const value = row.original.email;
          return h('span', { class: value ? '' : 'text-n-slate-8' }, value || '---');
        },
        size: 200,
      })
    );
  }

  if (props.visibleColumns.includes('phoneNumber')) {
    cols.push(
      columnHelper.display({
        id: 'phoneNumber',
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.PHONE'),
        cell: ({ row }) => {
          const value = row.original.phoneNumber;
          return h('span', { class: value ? '' : 'text-n-slate-8' }, value || '---');
        },
        size: 150,
      })
    );
  }

  if (props.visibleColumns.includes('companyName')) {
    cols.push(
      columnHelper.display({
        id: 'companyName',
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.COMPANY'),
        cell: ({ row }) => {
          const value = formatCompanyName(row.original.additionalAttributes);
          return h('span', { class: value === '---' ? 'text-n-slate-8' : '' }, value);
        },
        size: 180,
      })
    );
  }

  if (props.visibleColumns.includes('location')) {
    cols.push(
      columnHelper.display({
        id: 'location',
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.LOCATION'),
        cell: ({ row }) => {
          const value = formatLocation(row.original.additionalAttributes);
          return h('span', { class: value === '---' ? 'text-n-slate-8' : '' }, value);
        },
        size: 150,
      })
    );
  }

  if (props.visibleColumns.includes('createdAt')) {
    cols.push(
      columnHelper.display({
        id: 'createdAt',
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.CREATED_AT'),
        cell: ({ row }) => {
          return h('span', { class: 'text-n-slate-11' }, formatDate(row.original.createdAt));
        },
        size: 120,
      })
    );
  }

  if (props.visibleColumns.includes('lastActivityAt')) {
    cols.push(
      columnHelper.display({
        id: 'lastActivityAt',
        header: t('CONTACTS_LAYOUT.TABLE.COLUMN.LAST_ACTIVITY'),
        cell: ({ row }) => {
          return h('span', { class: 'text-n-slate-11' }, formatDate(row.original.lastActivityAt));
        },
        size: 140,
      })
    );
  }

  props.customAttributes
    .filter(attr => props.visibleColumns.includes(attr.key))
    .forEach(attr => {
      cols.push(
        columnHelper.display({
          id: attr.key,
          header: attr.label || attr.key,
          cell: ({ row }) => {
            const value = (row.original.customAttributes || {})[attr.key];
            return h('span', { class: value ? '' : 'text-n-slate-8' }, value ?? '---');
          },
          size: 150,
        })
      );
    });

  cols.push(
    columnHelper.display({
      id: 'actions',
      header: t('CONTACTS_LAYOUT.TABLE.COLUMN.ACTIONS'),
      cell: ({ row }) => {
        const contact = row.original;
        return h('div', { class: 'flex items-center gap-1' }, [
          h(Button, {
            icon: 'i-lucide-pen',
            variant: 'ghost',
            size: 'sm',
            color: 'slate',
            'aria-label': t('CONTACTS_LAYOUT.TABLE.EDIT_CONTACT'),
            onClick: () => openEditModal(contact),
          }),
          h(Button, {
            icon: 'i-lucide-eye',
            variant: 'ghost',
            size: 'sm',
            color: 'slate',
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
  get columns() {
    return columns.value;
  },
  getCoreRowModel: getCoreRowModel(),
});
</script>

<template>
  <div class="contacts-table-container">
    <div class="table-wrapper">
      <Table :table="table" class="w-full min-w-[900px]" />
    </div>

    <Dialog
      ref="editDialogRef"
      :title="t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.TITLE')"
      width="3xl"
      @close="onDialogClose"
    >
      <template #default>
        <ContactsForm
          v-if="contactForEdit"
          ref="contactsFormRef"
          :contact-data="contactForEdit"
          @update="handleFormUpdate"
          @remove-custom-attr="handleRemoveCustomAttr"
        />
      </template>
      <template #footer>
        <div class="flex items-center justify-between w-full gap-3">
          <Button
            variant="link"
            class="h-10 hover:!no-underline hover:text-n-brand"
            @click="closeEditModal"
          >
            {{ t('DIALOG.BUTTONS.CANCEL') }}
          </Button>
          <Button
            color="blue"
            :is-loading="isUpdating"
            :disabled="isUpdating"
            @click="handleUpdateContact"
          >
            {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON') }}
          </Button>
        </div>
      </template>
    </Dialog>
  </div>
</template>

<style lang="scss" scoped>
.contacts-table-container {
  @apply flex flex-col flex-1 min-h-0;

  .table-wrapper {
    @apply w-full overflow-auto;
    max-height: calc(100vh - 5rem);
  }
}
</style>
