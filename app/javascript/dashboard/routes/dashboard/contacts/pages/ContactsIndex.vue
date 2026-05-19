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
const contactAttributeKeys = useMapGetter('contactAttributeKeys/getContactAttributeKeys');
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

// Always-visible built-in columns (cannot be unchecked)
const ALWAYS_VISIBLE_KEYS = ['name', 'phoneNumber', 'companyName', 'location'];

const BUILT_IN_MANDATORY_COLUMNS = [
  { key: 'name', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.NAME') },
  { key: 'phoneNumber', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.PHONE') },
  { key: 'companyName', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.COMPANY') },
  { key: 'location', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.LOCATION') },
];

const BUILT_IN_OPTIONAL_COLUMNS = [
  { key: 'createdAt', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.CREATED_AT') },
  { key: 'lastActivityAt', label: t('CONTACTS_LAYOUT.TABLE.COLUMN.LAST_ACTIVITY') },
];

// All currently visible column keys (persisted in UI settings)
const visibleColumns = computed(
  () => uiSettings.value?.contacts_visible_columns || [...ALWAYS_VISIBLE_KEYS]
);

const formatAttrLabel = key =>
  key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());

// Custom attribute column definitions to pass to the table
const allCustomColumnDefs = computed(() =>
  (contactAttributeKeys.value || []).map(r => ({
    key: r.key,
    label: formatAttrLabel(r.key),
  }))
);

// --- Column settings dialog ---
const columnSettingsDialogRef = ref(null);
const columnSettingsData = ref([]);

const openColumnSettings = () => {
  columnSettingsData.value = [...visibleColumns.value];
  columnSettingsDialogRef.value?.open();
};

const isMandatoryColumn = key => ALWAYS_VISIBLE_KEYS.includes(key);

const isChecked = key => columnSettingsData.value.includes(key);

const toggleColumn = key => {
  if (isMandatoryColumn(key)) return;
  columnSettingsData.value = columnSettingsData.value.includes(key)
    ? columnSettingsData.value.filter(k => k !== key)
    : [...columnSettingsData.value, key];
};

const saveColumnSettings = async () => {
  await updateUISettings({ contacts_visible_columns: columnSettingsData.value });
  columnSettingsDialogRef.value?.close();
  // eslint-disable-next-line no-use-before-define
  await fetchContacts();
};

const closeColumnSettings = () => {
  columnSettingsDialogRef.value?.close();
};

// --- Navigation ---
const handleViewModeChange = async newMode => {
  viewMode.value = newMode;
  await updateUISettings({ contacts_view_mode: newMode });
};

const handleViewContact = contactId => {
  router.push({ name: 'contacts_edit', params: { contactId } });
};

// --- Derived state ---
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
const hasAppliedFilters = computed(() => appliedFilters.value.length > 0);
const showEmptyStateLayout = computed(
  () =>
    !searchQuery.value &&
    !hasContacts.value &&
    isContactIndexView.value &&
    !hasAppliedFilters.value
);
const showEmptyText = computed(
  () =>
    (searchQuery.value || hasAppliedFilters.value || !isContactIndexView.value) &&
    !hasContacts.value
);

const headerTitle = computed(() => {
  if (searchQuery.value) return t('CONTACTS_LAYOUT.HEADER.SEARCH_TITLE');
  if (activeSegmentId.value) return activeSegment.value?.name;
  if (activeLabel.value) return `#${activeLabel.value}`;
  return t('CONTACTS_LAYOUT.HEADER.TITLE');
});

// --- Fetch helpers ---
const updatePageParam = (page, search = '') => {
  const query = {
    ...route.query,
    page: page.toString(),
    ...(search ? { search } : {}),
  };
  if (!search) delete query.search;
  router.replace({ query });
};

const buildSortAttr = () => `${sortState.activeOrdering}${sortState.activeSort}`;

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
  searchValue.value = '';
  if (
    (hasAppliedFilters.value || activeSegment.value?.query) &&
    !activeLabel.value
  ) {
    const queryPayload =
      activeSegment.value?.query || filterQueryGenerator(appliedFilters.value);
    await fetchSavedOrAppliedFilteredContact(queryPayload, page);
    return;
  }
  await fetchContacts(page);
};

const handleSort = async ({ sort, order }) => {
  Object.assign(sortState, { activeSort: sort, activeOrdering: order });
  await updateUISettings({ contacts_sort_by: buildSortAttr() });

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

// --- Watchers ---
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

watch([activeLabel, activeSegment], () => {
  fetchContactsBasedOnContext(pageNumber.value);
}, { deep: true });

watch(searchQuery, value => {
  if (isFetchingList.value) return;
  searchValue.value = value || '';
  if (value === undefined) fetchContacts();
});

onMounted(async () => {
  store.dispatch('attributes/get');
  store.dispatch('contactAttributeKeys/get');

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
    class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-background"
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
          :custom-attributes="allCustomColumnDefs"
          :visible-columns="visibleColumns"
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
        <div class="max-h-72 overflow-y-auto space-y-0.5">
          <!-- Built-in columns -->
          <label
            v-for="col in [...BUILT_IN_MANDATORY_COLUMNS, ...BUILT_IN_OPTIONAL_COLUMNS]"
            :key="col.key"
            class="flex items-center gap-2 py-1.5 cursor-pointer"
            :class="{ 'opacity-50': isMandatoryColumn(col.key) }"
          >
            <input
              type="checkbox"
              class="w-4 h-4 flex-shrink-0"
              :checked="isChecked(col.key)"
              :disabled="isMandatoryColumn(col.key)"
              @change="toggleColumn(col.key)"
            />
            <span class="text-sm text-n-slate-12">{{ col.label }}</span>
          </label>

          <!-- Custom attribute columns -->
          <template v-if="contactAttributeKeys && contactAttributeKeys.length">
            <div class="my-2 border-t border-n-weak" />
            <label
              v-for="r in contactAttributeKeys"
              :key="r.key"
              class="flex items-center gap-2 py-1.5 cursor-pointer"
            >
              <input
                type="checkbox"
                class="w-4 h-4 flex-shrink-0"
                :checked="isChecked(r.key)"
                @change="toggleColumn(r.key)"
              />
              <span class="text-sm text-n-slate-12 truncate">{{ formatAttrLabel(r.key) }}</span>
            </label>
          </template>
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
