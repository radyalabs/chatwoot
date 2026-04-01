<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import ReminderCard from './ReminderCard.vue';
import ReminderFormModal from './ReminderFormModal.vue';

const { t } = useI18n();

const props = defineProps({
  aiAgentId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();
const allInboxes = useMapGetter('inboxes/getInboxes');
const reminders = useMapGetter('scheduledReminders/getScheduledReminders');
const uiFlags = useMapGetter('scheduledReminders/getUIFlags');

const editingReminder = ref(null);
const showFormModal = ref(false);
const searchQuery = ref('');
const formModalRef = ref(null);

const SUPPORTED_CHANNEL_TYPES = {
  whatsapp_unofficial: INBOX_TYPES.WHATSAPP_UNOFFICIAL,
  whatsapp: INBOX_TYPES.WHATSAPP,
  telegram: INBOX_TYPES.TELEGRAM,
  instagram: INBOX_TYPES.INSTAGRAM,
};

// Group inboxes by channel type (all inboxes)
const allInboxesByType = computed(() => {
  const result = {};
  Object.entries(SUPPORTED_CHANNEL_TYPES).forEach(([key, channelType]) => {
    result[key] = (allInboxes.value || []).filter(
      inbox => inbox.channel_type === channelType
    );
  });
  return result;
});

// Group inboxes by channel type (connected only)
const connectedInboxesByType = computed(() => {
  const result = {};
  Object.entries(SUPPORTED_CHANNEL_TYPES).forEach(([key, channelType]) => {
    result[key] = (allInboxes.value || []).filter(inbox => {
      if (inbox.channel_type !== channelType) return false;
      // WhatsApp Unofficial has explicit status
      if (channelType === INBOX_TYPES.WHATSAPP_UNOFFICIAL) {
        return inbox.whatsapp_status === 'connected';
      }
      // For other channels, assume connected if they exist
      return true;
    });
  });
  return result;
});

const hasAnyConnectedInbox = computed(() => {
  return Object.values(connectedInboxesByType.value).some(
    inboxes => inboxes.length > 0
  );
});

const filteredReminders = computed(() => {
  if (!searchQuery.value.trim()) return reminders.value || [];
  const query = searchQuery.value.toLowerCase();
  return (reminders.value || []).filter(
    r =>
      r.title?.toLowerCase().includes(query) ||
      r.description?.toLowerCase().includes(query) ||
      r.receiver_name?.toLowerCase().includes(query)
  );
});

const openAddForm = () => {
  editingReminder.value = null;
  showFormModal.value = true;
  setTimeout(() => {
    formModalRef.value?.open();
  }, 50);
};

const openEditForm = id => {
  const reminder = (reminders.value || []).find(r => r.id === id);
  if (reminder) {
    editingReminder.value = reminder;
    showFormModal.value = true;
    setTimeout(() => {
      formModalRef.value?.open();
    }, 50);
  }
};

const handleSave = async payload => {
  try {
    if (payload.id) {
      const { id, ...data } = payload;
      await store.dispatch('scheduledReminders/update', {
        aiAgentId: props.aiAgentId,
        reminderId: id,
        data,
      });
    } else {
      await store.dispatch('scheduledReminders/create', {
        aiAgentId: props.aiAgentId,
        data: payload,
      });
    }
  } catch (error) {
    console.error('Failed to save reminder:', error);
  }
};

const handleDelete = async id => {
  if (!window.confirm(t('AGENT_MGMT.REMINDER.MANAGEMENT.DELETE_CONFIRM'))) {
    return;
  }
  try {
    await store.dispatch('scheduledReminders/delete', {
      aiAgentId: props.aiAgentId,
      reminderId: id,
    });
  } catch (error) {
    console.error('Failed to delete reminder:', error);
  }
};

const handleFormClose = () => {
  showFormModal.value = false;
  editingReminder.value = null;
};

onMounted(() => {
  store.dispatch('inboxes/get');
  if (props.aiAgentId) {
    store.dispatch('scheduledReminders/get', props.aiAgentId);
  }
});
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- Header -->
    <div class="flex items-start justify-between gap-4">
      <div class="flex flex-col gap-1">
        <h3
          class="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2"
        >
          <span class="i-lucide-bell w-5 h-5 text-green-600 dark:text-green-400" />
          {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.HEADER') }}
        </h3>
        <p class="text-sm text-gray-500">
          {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.DESC') }}
        </p>
      </div>
      <button
        :disabled="!hasAnyConnectedInbox"
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-all font-medium shadow-sm active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed disabled:active:scale-100 flex-shrink-0"
        @click="openAddForm"
      >
        <svg
          class="w-5 h-5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 4v16m8-8H4"
          />
        </svg>
        {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.ADD_BUTTON') }}
      </button>
    </div>

    <!-- No inbox warning -->
    <div
      v-if="!hasAnyConnectedInbox"
      class="flex items-center gap-3 px-4 py-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl"
    >
      <span
        class="i-lucide-alert-triangle w-5 h-5 text-slate-600 dark:text-slate-300 flex-shrink-0"
      />
      <span class="text-sm text-slate-600 dark:text-slate-300">
        {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.NO_INBOX_AVAILABLE') }}
      </span>
    </div>

    <!-- Search -->
    <div
      v-if="(reminders || []).length > 0"
      class="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-n-strong bg-n-solid-1 border-slate-900 dark:border-slate-50 focus-within:ring-2 focus-within:ring-woot-500 transition-shadow"
    >
      <span class="i-lucide-search size-4 text-n-slate-10 flex-shrink-0" />
      <input
        v-model="searchQuery"
        type="search"
        :placeholder="t('AGENT_MGMT.REMINDER.MANAGEMENT.SEARCH_PLACEHOLDER')"
        class="flex-1 min-w-0 py-2 text-sm bg-transparent border-none text-slate-900 dark:text-slate-50 placeholder:text-n-slate-10 focus:outline-none"
      />
    </div>

    <!-- Loading -->
    <div
      v-if="uiFlags?.isFetching"
      class="flex items-center justify-center py-12"
    >
      <span class="i-lucide-loader-2 w-5 h-5 animate-spin text-gray-400" />
    </div>

    <!-- Reminders List -->
    <div
      v-else-if="filteredReminders.length > 0"
      class="flex flex-col gap-4"
    >
      <ReminderCard
        v-for="reminder in filteredReminders"
        :key="reminder.id"
        :reminder="reminder"
        :all-inboxes-by-type="allInboxesByType"
        :connected-inboxes-by-type="connectedInboxesByType"
        @edit="openEditForm"
        @delete="handleDelete"
      />
    </div>

    <!-- Empty State -->
    <div
      v-else-if="!uiFlags?.isFetching"
      class="flex flex-col items-center justify-center py-12 bg-white dark:bg-slate-800 rounded-xl border border-dashed border-gray-300 dark:border-gray-700"
    >
      <div
        class="w-16 h-16 bg-gray-50 dark:bg-slate-700 rounded-full flex items-center justify-center mb-4"
      >
        <span class="i-lucide-bell-off w-8 h-8 text-gray-400" />
      </div>
      <p class="text-base font-medium text-gray-900 dark:text-gray-200">
        {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.EMPTY_STATE') }}
      </p>
    </div>

    <!-- Form Modal -->
    <ReminderFormModal
      v-if="showFormModal"
      ref="formModalRef"
      :reminder="editingReminder"
      :inboxes-by-type="connectedInboxesByType"
      :all-inboxes-by-type="allInboxesByType"
      @save="handleSave"
      @close="handleFormClose"
    />
  </div>
</template>
