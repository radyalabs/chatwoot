<script setup>
import { onMounted, computed, ref, reactive, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { debounce } from '@chatwoot/utils';
import { useUISettings } from 'dashboard/composables/useUISettings';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';

import ContactsListLayout from 'dashboard/components-next/Contacts/ContactsListLayout.vue';
import ContactsList from 'dashboard/components-next/Contacts/Pages/ContactsList.vue';
import ContactsTable from 'dashboard/components-next/Contacts/ContactsTable/ContactsTable.vue';
import ContactEmptyState from 'dashboard/components-next/Contacts/EmptyState/ContactEmptyState.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const DEFAULT_SORT_FIELD = 'last_activity_at';
const DEBOUNCE_DELAY = 300;

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const { updateUISettings, uiSettings } = useUISettings();

const contacts = useMapGetter('contacts/getContactsList');
const contactAttributes = useMapGetter('attributes/getContactAttributes');
const uiFlags = useMapGetter('contacts/getUIFlags');
const customViewsUiFlags = useMapGetter('customViews/getUIFlags');
const segments = useMapGetter('customViews/getContactCustomViews');
const appliedFilters = useMapGetter('contacts/getAppliedContactFilters');
const meta = useMapGetter('contacts/getMeta');

const searchQuery = computed(() => route.query?.search);
const searchValue = ref(searchQuery.value || '');
const pageNumber = computed(() => Number(route.query?.page) || 1);

const parseSortSettings = (sortString = '') => {
  const hasDescending = sortString.startsWith('-');
  const sortField = hasDescending ? sortString.slice(1) : sortString;
  return {
    sort: sortField || DEFAULT_SORT_FIELD,
    order: hasDescending ? '-' : '',
  };
};

const { contacts_sort_by: contactSortBy = '' } = uiSettings.value ?? {};
const { sort: initialSort, order: initialOrder } =
  parseSortSettings(contactSortBy);

const sortState = reactive({
  activeSort: initialSort,
  activeOrdering: initialOrder,
});

const viewMode = ref(uiSettings.value?.contacts_view_mode || 'table');

const DEFAULT_MANDATORY_COLUMNS = [
  'name',
  'phoneNumber',
  'companyName',
  'location',
  'createdAt',
];

const customColumns = ref(uiSettings.value?.contacts_custom_columns || []);

const visibleColumns = computed(() => {
  const savedCustom = uiSettings.value?.contacts_visible_custom_columns || [];
  return [...DEFAULT_MANDATORY_COLUMNS, ...savedCustom];
});

const columnSettingsDialogRef = ref(null);
const columnSettingsData = ref([]);
const newCustomColumnKey = ref('');

const mandatoryColumns = [
  { key: 'name', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.NAME') },
  { key: 'phoneNumber', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.PHONE') },
  { key: 'companyName', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.COMPANY') },
  { key: 'location', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.LOCATION') },
  // { key: 'createdAt', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.CREATED_AT') },
];

const handleViewModeChange = async newMode => {
  viewMode.value = newMode;
  await updateUISettings({
    contacts_view_mode: newMode,
  });
};

const handleViewContact = contactId => {
  router.push({
    name: 'contacts_edit',
    params: { contactId },
  });
};

const openColumnSettings = () => {
  const savedCustom = uiSettings.value?.contacts_visible_custom_columns || [];
  const initialData = [...DEFAULT_MANDATORY_COLUMNS, ...savedCustom];
  columnSettingsData.value = initialData;
  columnSettingsDialogRef.value?.open();
};

const allColumns = computed(() => [
  ...mandatoryColumns,
  ...(customColumns.value || []),
]);

const isMandatory = key => {
  return mandatoryColumns.some(m => m.key === key);
};

const isChecked = key => columnSettingsData.value.includes(key);

const toggleColumn = key => {
  if (!isMandatory(key)) {
    const idx = columnSettingsData.value.indexOf(key);
    if (idx > -1) {
      columnSettingsData.value = columnSettingsData.value.filter(
        k => k !== key
      );
    } else {
      columnSettingsData.value = [...columnSettingsData.value, key];
    }
  }
};

const addCustomColumn = () => {
  if (newCustomColumnKey.value.trim()) {
    const key = newCustomColumnKey.value.trim();
    if (!customColumns.value.find(c => c.key === key)) {
      customColumns.value = [...customColumns.value, { key, label: key }];
      store.dispatch('contacts/createCustomAttribute', {
        attribute_key: key,
        attribute_display_name: key,
        attribute_display_type: 'text',
        attribute_model: 'contact_attribute',
      });
    }
    newCustomColumnKey.value = '';
  }
};

const deleteCustomColumn = key => {
  customColumns.value = customColumns.value.filter(c => c.key !== key);
  columnSettingsData.value = columnSettingsData.value.filter(k => k !== key);
  const attr = contactAttributes.value?.find(a => a.attributeKey === key);
  if (attr) {
    store.dispatch('attributes/delete', attr.id);
  }
};

const saveColumnSettings = async () => {
  const selectedCustom = columnSettingsData.value.filter(
    k => !DEFAULT_MANDATORY_COLUMNS.includes(k)
  );
  await updateUISettings({
    contacts_visible_custom_columns: selectedCustom,
    contacts_custom_columns: customColumns.value,
  });
  columnSettingsDialogRef.value?.close();

  // eslint-disable-next-line no-use-before-define
  await fetchContacts();
};

const closeColumnSettings = () => {
  columnSettingsDialogRef.value?.close();
};

const activeLabel = computed(() => route.params.label);

const activeSegmentId = computed(() => route.params.segmentId);
const isFetchingList = computed(
  () => uiFlags.value.isFetching || customViewsUiFlags.value.isFetching
);
const currentPage = computed(() => Number(meta.value?.currentPage));
const totalItems = computed(() => meta.value?.count);
const activeSegment = computed(() => {
  if (!activeSegmentId.value) return undefined;
  return segments.value.find(view => view.id === Number(activeSegmentId.value));
});

const hasContacts = computed(() => contacts.value.length > 0);
const isContactIndexView = computed(
  () => route.name === 'contacts_dashboard_index' && pageNumber.value === 1
);
const hasAppliedFilters = computed(() => {
  return appliedFilters.value.length > 0;
});
const showEmptyStateLayout = computed(() => {
  return (
    !searchQuery.value &&
    !hasContacts.value &&
    isContactIndexView.value &&
    !hasAppliedFilters.value
  );
});
const showEmptyText = computed(() => {
  return (
    (searchQuery.value ||
      hasAppliedFilters.value ||
      !isContactIndexView.value) &&
    !hasContacts.value
  );
});

const headerTitle = computed(() => {
  if (searchQuery.value) return t('CONTACTS_LAYOUT.HEADER.SEARCH_TITLE');
  if (activeSegmentId.value) return activeSegment.value?.name;
  if (activeLabel.value) return `#${activeLabel.value}`;
  return t('CONTACTS_LAYOUT.HEADER.TITLE');
});

const updatePageParam = (page, search = '') => {
  const query = {
    ...route.query,
    page: page.toString(),
    ...(search ? { search } : {}),
  };

  if (!search) {
    delete query.search;
  }

  router.replace({ query });
};

const buildSortAttr = () =>
  `${sortState.activeOrdering}${sortState.activeSort}`;

const getCommonFetchParams = (page = 1) => ({
  page,
  sortAttr: buildSortAttr(),
  label: activeLabel.value,
});

const fetchContacts = async (page = 1) => {
  await store.dispatch('contacts/clearContactFilters');
  await store.dispatch('contacts/get', getCommonFetchParams(page));
  updatePageParam(page);
};

const fetchSavedOrAppliedFilteredContact = async (payload, page = 1) => {
  if (!activeSegmentId.value && !hasAppliedFilters.value) return;
  await store.dispatch('contacts/filter', {
    ...getCommonFetchParams(page),
    queryPayload: payload,
  });
  updatePageParam(page);
};

const searchContacts = debounce(async (value, page = 1) => {
  await store.dispatch('contacts/clearContactFilters');
  searchValue.value = value;

  if (!value) {
    updatePageParam(page);
    await fetchContacts(page);
    return;
  }

  updatePageParam(page, value);
  await store.dispatch('contacts/search', {
    ...getCommonFetchParams(page),
    search: encodeURIComponent(value),
  });
}, DEBOUNCE_DELAY);

const fetchContactsBasedOnContext = async page => {
  updatePageParam(page, searchValue.value);
  if (isFetchingList.value) return;
  if (searchQuery.value) {
    await searchContacts(searchQuery.value, page);
    return;
  }
  // Reset the search value when we change the view
  searchValue.value = '';
  // If there are applied filters or active segment with query
  if (
    (hasAppliedFilters.value || activeSegment.value?.query) &&
    !activeLabel.value
  ) {
    const queryPayload =
      activeSegment.value?.query || filterQueryGenerator(appliedFilters.value);
    await fetchSavedOrAppliedFilteredContact(queryPayload, page);
    return;
  }
  // Default case: fetch regular contacts + label
  await fetchContacts(page);
};

const handleSort = async ({ sort, order }) => {
  Object.assign(sortState, { activeSort: sort, activeOrdering: order });

  await updateUISettings({
    contacts_sort_by: buildSortAttr(),
  });

  if (searchQuery.value) {
    await searchContacts(searchValue.value);
    return;
  }

  await (activeSegmentId.value || hasAppliedFilters.value
    ? fetchSavedOrAppliedFilteredContact(
        activeSegmentId.value
          ? activeSegment.value?.query
          : filterQueryGenerator(appliedFilters.value)
      )
    : fetchContacts());
};

const createContact = async contact => {
  await store.dispatch('contacts/create', contact);
};

watch(
  () => uiSettings.value?.contacts_sort_by,
  newSortBy => {
    if (newSortBy) {
      const { sort, order } = parseSortSettings(newSortBy);
      sortState.activeSort = sort;
      sortState.activeOrdering = order;
    }
  },
  { immediate: true }
);

watch(
  [activeLabel, activeSegment],
  () => {
    fetchContactsBasedOnContext(pageNumber.value);
  },
  { deep: true }
);

watch(searchQuery, value => {
  if (isFetchingList.value) return;
  searchValue.value = value || '';
  // Reset the view if there is search query when we click on the sidebar group
  if (value === undefined) {
    fetchContacts();
  }
});

onMounted(async () => {
  if (!activeSegmentId.value) {
    if (searchQuery.value) {
      await searchContacts(searchQuery.value, pageNumber.value);
      return;
    }
    await fetchContacts(pageNumber.value);
  } else if (activeSegment.value && activeSegmentId.value) {
    await fetchSavedOrAppliedFilteredContact(
      activeSegment.value.query,
      pageNumber.value
    );
  }
});
</script>

<template>
  <div
    class="flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-background"
  >
    <ContactsListLayout
      :search-value="searchValue"
      :header-title="headerTitle"
      :current-page="currentPage"
      :total-items="totalItems"
      :show-pagination-footer="!isFetchingList && hasContacts"
      :active-sort="sortState.activeSort"
      :active-ordering="sortState.activeOrdering"
      :active-segment="activeSegment"
      :segments-id="activeSegmentId"
      :is-fetching-list="isFetchingList"
      :has-applied-filters="hasAppliedFilters"
      :view-mode="viewMode"
      @update:current-page="fetchContactsBasedOnContext"
      @search="searchContacts"
      @update:sort="handleSort"
      @apply-filter="fetchSavedOrAppliedFilteredContact"
      @clear-filters="fetchContacts"
      @update:view-mode="handleViewModeChange"
      @column-settings="openColumnSettings"
    >
      <div
        v-if="isFetchingList"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <template v-else>
        <ContactEmptyState
          v-if="showEmptyStateLayout"
          class="pt-14"
          :title="t('CONTACTS_LAYOUT.EMPTY_STATE.TITLE')"
          :subtitle="t('CONTACTS_LAYOUT.EMPTY_STATE.SUBTITLE')"
          :button-label="t('CONTACTS_LAYOUT.EMPTY_STATE.BUTTON_LABEL')"
          @create="createContact"
        />

        <div
          v-else-if="showEmptyText"
          class="flex items-center justify-center py-10"
        >
          <span class="text-base text-n-slate-11">
            {{
              searchQuery || !hasAppliedFilters
                ? t('CONTACTS_LAYOUT.EMPTY_STATE.SEARCH_EMPTY_STATE_TITLE')
                : t('CONTACTS_LAYOUT.EMPTY_STATE.LIST_EMPTY_STATE_TITLE')
            }}
          </span>
        </div>

        <ContactsTable
          v-else-if="viewMode === 'table'"
          :contacts="contacts"
          :custom-attributes="customColumns"
          :mandatory-columns="visibleColumns"
          @view-contact="handleViewContact"
        />
        <ContactsList v-else :contacts="contacts" />
      </template>
    </ContactsListLayout>

    <Dialog
      ref="columnSettingsDialogRef"
      :title="t('CONTACTS_LAYOUT.TABLE.COLUMN_SETTINGS_TITLE')"
      width="sm"
    >
      <div class="flex flex-col gap-3">
        <p class="text-sm font-medium text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.TABLE.COLUMNS') }}
        </p>
        <div class="max-h-64 overflow-y-auto space-y-1">
          <label
            v-for="col in allColumns"
            :key="col.key"
            class="flex items-center justify-between gap-2 py-1"
          >
            <div class="flex items-center gap-2">
              <input
                type="checkbox"
                class="w-4 h-4"
                :checked="isChecked(col.key)"
                :disabled="isMandatory(col.key)"
                @change="toggleColumn(col.key)"
              />
              <span class="text-sm text-n-slate-12">{{ col.label }}</span>
            </div>
            <button
              type="button"
              class="text-n-slate-10 hover:text-n-ruby-11"
              @click="deleteCustomColumn(col.key)"
            >
              <Icon icon="i-lucide-trash-2" class="size-4" />
            </button>
          </label>
        </div>

        <div class="flex items-center gap-2 mt-2">
          <input
            v-model="newCustomColumnKey"
            type="text"
            :placeholder="t('CONTACTS_LAYOUT.TABLE.COLUMN_KEY')"
            class="flex-1 h-8 px-2 text-sm border rounded-lg"
            @keyup.enter="addCustomColumn"
          />
          <Button size="sm" @click="addCustomColumn">
            <Icon icon="i-lucide-plus" class="size-4" />
          </Button>
        </div>
      </div>
      <template #footer>
        <div class="flex justify-end gap-2">
          <Button variant="ghost" size="sm" @click="closeColumnSettings">
            {{ t('DIALOG.BUTTONS.CANCEL') }}
          </Button>
          <Button size="sm" @click="saveColumnSettings">
            {{ t('DIALOG.BUTTONS.CONFIRM') }}
          </Button>
        </div>
      </template>
    </Dialog>
  </div>
</template>
