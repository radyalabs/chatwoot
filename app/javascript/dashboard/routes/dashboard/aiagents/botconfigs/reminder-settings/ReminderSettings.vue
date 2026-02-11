<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import Button from 'dashboard/components-next/button/Button.vue';
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
  if (!window.confirm(t('AGENT_MGMT.SALESBOT.REMINDER.DELETE_CONFIRM'))) {
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

const handleToggle = async (id, enabled) => {
  try {
    await store.dispatch('scheduledReminders/update', {
      aiAgentId: props.aiAgentId,
      reminderId: id,
      data: { enabled },
    });
  } catch (error) {
    console.error('Failed to toggle reminder:', error);
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
  <div class="flex flex-col gap-4">
    <!-- Header -->
    <div class="flex items-start justify-between">
      <div>
        <h3
          class="text-base font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2"
        >
          <span class="i-lucide-bell w-5 h-5 text-woot-500" />
          {{ t('AGENT_MGMT.SALESBOT.REMINDER.HEADER') }}
        </h3>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
          {{ t('AGENT_MGMT.SALESBOT.REMINDER.DESC') }}
        </p>
      </div>
      <Button
        variant="solid"
        color-scheme="primary"
        size="small"
        :disabled="!hasAnyConnectedInbox"
        @click="openAddForm"
      >
        <span class="i-lucide-plus w-4 h-4 mr-1" />
        {{ t('AGENT_MGMT.SALESBOT.REMINDER.ADD_BUTTON') }}
      </Button>
    </div>

    <!-- No inbox warning -->
    <div
      v-if="!hasAnyConnectedInbox"
      class="flex items-center gap-2 px-4 py-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl"
    >
      <span class="i-lucide-alert-triangle w-5 h-5 text-slate-500 dark:text-slate-400" />
      <span class="text-sm text-slate-500 dark:text-slate-400">
        {{ t('AGENT_MGMT.SALESBOT.REMINDER.NO_INBOX_AVAILABLE') }}
      </span>
    </div>

    <!-- Search -->
    <div v-if="(reminders || []).length > 0" class="relative">
      <span
        class="i-lucide-search w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
      />
      <input
        v-model="searchQuery"
        type="text"
        :placeholder="t('AGENT_MGMT.SALESBOT.REMINDER.SEARCH_PLACEHOLDER')"
        class="w-full pl-10 pr-4 py-2 text-sm border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
      />
    </div>

    <!-- Loading -->
    <div
      v-if="uiFlags?.isFetching"
      class="flex items-center justify-center py-8"
    >
      <span class="i-lucide-loader-2 w-5 h-5 animate-spin text-gray-400" />
    </div>

    <!-- Reminders List -->
    <div
      v-else-if="filteredReminders.length > 0"
      class="flex flex-col gap-3"
    >
      <ReminderCard
        v-for="reminder in filteredReminders"
        :key="reminder.id"
        :reminder="reminder"
        :all-inboxes-by-type="allInboxesByType"
        :connected-inboxes-by-type="connectedInboxesByType"
        @edit="openEditForm"
        @delete="handleDelete"
        @toggle="handleToggle"
      />
    </div>

    <!-- Empty State -->
    <div
      v-else-if="!uiFlags?.isFetching"
      class="flex flex-col items-center justify-center py-8 text-gray-400 dark:text-gray-500"
    >
      <span class="i-lucide-bell-off w-8 h-8 mb-2" />
      <p class="text-sm">
        {{ t('AGENT_MGMT.SALESBOT.REMINDER.EMPTY_STATE') }}
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
