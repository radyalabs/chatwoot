<script setup>
import { computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import Button from 'dashboard/components-next/button/Button.vue';
import NotificationCard from './NotificationCard.vue';
import NotificationFormModal from './NotificationFormModal.vue';
import { ref } from 'vue';

const props = defineProps({
  aiAgentId: {
    type: [Number, String],
    required: true,
  },
  titleKey: {
    type: String,
    default: 'AGENT_MGMT.LEADGENBOT.NOTIFICATION.TITLE',
  },
  descKey: {
    type: String,
    default: 'AGENT_MGMT.LEADGENBOT.NOTIFICATION.DESC',
  },
  variableConfig: {
    type: Object,
    default: () => ({
      helpKey: 'AGENT_MGMT.LEADGENBOT.NOTIFICATION.TEMPLATE_HELP',
      variables: [
        {
          labelKey: 'AGENT_MGMT.LEADGENBOT.NOTIFICATION.VAR_CUSTOMER_NAME',
          value: '{{nama_pelanggan}}',
          example: 'Budi Santoso',
        },
        {
          labelKey:
            'AGENT_MGMT.LEADGENBOT.NOTIFICATION.VAR_CONSULTATION_DATE',
          value: '{{tanggal_konsultasi}}',
          example: '25 Des 2025',
        },
        {
          labelKey:
            'AGENT_MGMT.LEADGENBOT.NOTIFICATION.VAR_CONSULTATION_TIME',
          value: '{{waktu_konsultasi}}',
          example: '10:00',
        },
        {
          labelKey: 'AGENT_MGMT.LEADGENBOT.NOTIFICATION.VAR_SERVICE_NAME',
          value: '{{nama_layanan}}',
          example: 'Konsultasi Bisnis',
        },
      ],
    }),
  },
});

const store = useStore();
const allInboxes = useMapGetter('inboxes/getInboxes');
const notifications = useMapGetter(
  'agentNotificationSettings/getAgentNotificationSettings'
);
const uiFlags = useMapGetter('agentNotificationSettings/getUIFlags');

const whatsappUnofficialInboxes = computed(() => {
  return (allInboxes.value || []).filter(
    inbox => inbox.channel_type === INBOX_TYPES.WHATSAPP_UNOFFICIAL
  );
});

const hasInboxes = computed(() => whatsappUnofficialInboxes.value.length > 0);

const editingRule = ref(null);
const formModalRef = ref(null);

onMounted(() => {
  store.dispatch('inboxes/get');
  if (props.aiAgentId) {
    store.dispatch('agentNotificationSettings/get', props.aiAgentId);
  }
});

const openAddForm = () => {
  editingRule.value = null;
  formModalRef.value?.open();
};

const openEditForm = id => {
  const rule = notifications.value.find(n => n.id === id);
  if (rule) {
    editingRule.value = { ...rule };
    formModalRef.value?.open();
  }
};

const handleSave = async payload => {
  try {
    if (payload.id) {
      await store.dispatch('agentNotificationSettings/update', {
        aiAgentId: props.aiAgentId,
        settingId: payload.id,
        data: payload,
      });
    } else {
      await store.dispatch('agentNotificationSettings/create', {
        aiAgentId: props.aiAgentId,
        data: payload,
      });
    }
  } catch (error) {
    console.error('Failed to save notification setting:', error);
  }
  editingRule.value = null;
};

const handleDelete = async id => {
  try {
    await store.dispatch('agentNotificationSettings/delete', {
      aiAgentId: props.aiAgentId,
      settingId: id,
    });
  } catch (error) {
    console.error('Failed to delete notification setting:', error);
  }
};

const handleFormClose = () => {
  editingRule.value = null;
};
</script>

<template>
  <div
    class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-6 border border-blue-200 dark:border-blue-800"
  >
    <!-- Header -->
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center">
        <div
          class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3"
        >
          <span
            class="i-lucide-bell w-5 h-5 text-green-600 dark:text-green-400"
          />
        </div>
        <div>
          <h4 class="font-medium text-slate-900 dark:text-slate-25">
            {{ $t(titleKey) }}
          </h4>
          <p class="text-sm text-slate-600 dark:text-slate-400">
            {{ $t(descKey) }}
          </p>
        </div>
      </div>
    </div>

    <div class="border-t border-blue-200 dark:border-blue-700 pt-4">
      <!-- Add Notification Button -->
      <div class="mb-4">
        <Button
          :label="$t('AGENT_MGMT.NOTIFICATION.ADD_BUTTON')"
          variant="outline"
          color="slate"
          size="sm"
          :disabled="!hasInboxes"
          @click="openAddForm"
        />
        <p
          v-if="!hasInboxes"
          class="mt-1 text-xs text-slate-500 dark:text-slate-400 italic"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.NO_INBOX_AVAILABLE') }}
        </p>
      </div>

      <!-- Loading State -->
      <div
        v-if="uiFlags.isFetching"
        class="text-sm text-slate-500 dark:text-slate-400 text-center py-4"
      >
        Loading...
      </div>

      <!-- Notification Cards -->
      <div
        v-else-if="notifications.length"
        class="flex flex-col gap-3"
      >
        <NotificationCard
          v-for="rule in notifications"
          :key="rule.id"
          :rule="rule"
          :whatsapp-unofficial-inboxes="whatsappUnofficialInboxes"
          :whatsapp-groups="[]"
          @edit="openEditForm"
          @delete="handleDelete"
        />
      </div>
      <div
        v-else
        class="text-sm text-slate-500 dark:text-slate-400 text-center py-4"
      >
        {{ $t('AGENT_MGMT.NOTIFICATION.EMPTY_STATE') }}
      </div>
    </div>

    <!-- Form Modal -->
    <NotificationFormModal
      ref="formModalRef"
      :rule="editingRule"
      :whatsapp-unofficial-inboxes="whatsappUnofficialInboxes"
      :variable-config="variableConfig"
      @save="handleSave"
      @close="handleFormClose"
    />
  </div>
</template>
