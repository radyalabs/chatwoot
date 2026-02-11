<script setup>
import { ref, watch, computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import RecurrenceSelector from './RecurrenceSelector.vue';
import WhatsAppUnofficialChannels from 'dashboard/api/WhatsAppUnofficialChannels';

const { t } = useI18n();

const props = defineProps({
  reminder: {
    type: Object,
    default: null,
  },
  inboxesByType: {
    type: Object,
    default: () => ({}),
  },
  allInboxesByType: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['save', 'close']);

const dialogRef = ref(null);

// Form fields
const title = ref('');
const description = ref('');
const inboxType = ref('');
const senderInboxId = ref('');
const messageType = ref('personal');
const receiverAddress = ref('');
const receiverName = ref('');
const messageTemplate = ref('');
const scheduledAt = ref('');
const recurrenceRule = ref(null);
const endsAt = ref(null);
const endsAfterCount = ref(null);

const groups = ref([]);
const isLoadingGroups = ref(false);
const isPopulating = ref(false);

const isEditing = computed(() => !!props.reminder);

const INBOX_TYPE_OPTIONS = [
  {
    value: 'whatsapp_unofficial',
    label: 'WhatsApp Go',
    channelType: 'Channel::WhatsappUnofficial',
  },
  {
    value: 'whatsapp',
    label: 'WhatsApp Official',
    channelType: 'Channel::Whatsapp',
  },
  {
    value: 'telegram',
    label: 'Telegram',
    channelType: 'Channel::Telegram',
  },
  {
    value: 'instagram',
    label: 'Instagram',
    channelType: 'Channel::Instagram',
  },
];

const filteredInboxes = computed(() => {
  if (!inboxType.value) return [];
  return props.inboxesByType[inboxType.value] || [];
});

const allFilteredInboxes = computed(() => {
  if (!inboxType.value) return [];
  return props.allInboxesByType[inboxType.value] || [];
});

const showMessageTypeSelector = computed(() => {
  return ['whatsapp_unofficial', 'whatsapp'].includes(inboxType.value);
});

const showGroupSelector = computed(() => {
  return showMessageTypeSelector.value && messageType.value === 'group';
});

const formatInboxLabel = inbox => {
  const phone = inbox.phone_number ? ` (${inbox.phone_number})` : '';
  return `${inbox.name}${phone}`;
};

const receiverPlaceholder = computed(() => {
  if (['whatsapp_unofficial', 'whatsapp'].includes(inboxType.value)) {
    return t('AGENT_MGMT.NOTIFICATION.RECEIVER_PLACEHOLDER_WHATSAPP');
  }
  if (inboxType.value === 'telegram') return 'Chat ID';
  if (inboxType.value === 'instagram') return 'Username / IGID';
  return '';
});

const resetForm = () => {
  title.value = '';
  description.value = '';
  inboxType.value = '';
  senderInboxId.value = '';
  messageType.value = 'personal';
  receiverAddress.value = '';
  receiverName.value = '';
  messageTemplate.value = '';
  scheduledAt.value = '';
  recurrenceRule.value = null;
  endsAt.value = null;
  endsAfterCount.value = null;
};

const populateForm = reminder => {
  isPopulating.value = true;
  title.value = reminder.title || '';
  description.value = reminder.description || '';
  inboxType.value = reminder.receiver_channel_type || '';
  senderInboxId.value = reminder.inbox_id || '';
  messageType.value = reminder.message_type || 'personal';
  receiverAddress.value = reminder.receiver_address || '';
  receiverName.value = reminder.receiver_name || '';
  messageTemplate.value = reminder.message_template || '';
  scheduledAt.value = reminder.scheduled_at
    ? formatDateTimeLocal(reminder.scheduled_at, reminder.timezone)
    : '';
  recurrenceRule.value = reminder.recurrence_rule
    ? { ...reminder.recurrence_rule }
    : null;
  endsAt.value = reminder.ends_at || null;
  endsAfterCount.value = reminder.ends_after_count || null;
  nextTick(() => {
    isPopulating.value = false;
  });
};

const formatDateTimeLocal = (isoString, _timezone) => {
  const date = new Date(isoString);
  const offset = date.getTimezoneOffset();
  const localDate = new Date(date.getTime() - offset * 60 * 1000);
  return localDate.toISOString().slice(0, 16);
};

const open = () => {
  if (props.reminder) {
    populateForm(props.reminder);
    if (props.reminder.message_type === 'group') {
      fetchGroups();
    }
  } else {
    resetForm();
  }
  nextTick(() => {
    dialogRef.value?.open();
  });
};

const close = () => {
  emit('close');
};

const canSave = computed(() => {
  return (
    title.value.trim() &&
    inboxType.value &&
    senderInboxId.value &&
    receiverAddress.value.trim() &&
    messageTemplate.value.trim() &&
    scheduledAt.value
  );
});

const handleSave = () => {
  let nameToSave = receiverName.value;
  if (messageType.value === 'group' && !nameToSave) {
    const selectedGroup = groups.value.find(
      g => g.value === receiverAddress.value
    );
    nameToSave = selectedGroup?.label || '';
  } else if (messageType.value === 'personal' && !nameToSave) {
    nameToSave = receiverAddress.value;
  }

  // Handle custom recurrence end conditions
  let finalEndsAt = endsAt.value;
  let finalEndsAfterCount = endsAfterCount.value;

  if (recurrenceRule.value?._ends_at) {
    finalEndsAt = recurrenceRule.value._ends_at;
    delete recurrenceRule.value._ends_at;
  }
  if (recurrenceRule.value?._ends_after_count) {
    finalEndsAfterCount = recurrenceRule.value._ends_after_count;
    delete recurrenceRule.value._ends_after_count;
  }

  // Clean up internal metadata from rule
  const cleanRule = recurrenceRule.value
    ? Object.fromEntries(
        Object.entries(recurrenceRule.value).filter(
          ([key]) => !key.startsWith('_')
        )
      )
    : null;

  const payload = {
    title: title.value,
    description: description.value || null,
    inbox_id: senderInboxId.value,
    receiver_channel_type: inboxType.value,
    message_type: messageType.value,
    receiver_address: receiverAddress.value,
    receiver_name: nameToSave,
    message_template: messageTemplate.value,
    scheduled_at: new Date(scheduledAt.value).toISOString(),
    recurrence_rule:
      cleanRule && Object.keys(cleanRule).length > 0 ? cleanRule : null,
    ends_at: finalEndsAt || null,
    ends_after_count: finalEndsAfterCount || null,
  };

  if (props.reminder?.id) {
    payload.id = props.reminder.id;
  }

  emit('save', payload);
  dialogRef.value?.close();
};

const fetchGroups = async () => {
  if (!senderInboxId.value || inboxType.value !== 'whatsapp_unofficial') {
    groups.value = [];
    return;
  }
  isLoadingGroups.value = true;
  try {
    const response = await WhatsAppUnofficialChannels.getGroups(
      senderInboxId.value
    );
    groups.value = (response.data?.payload || []).map(g => ({
      label: g.name,
      value: g.jid,
    }));
  } catch (error) {
    console.error('Failed to fetch groups:', error);
    groups.value = [];
  } finally {
    isLoadingGroups.value = false;
  }
};

// Reset inbox and receiver when inbox type changes
watch(inboxType, () => {
  if (isPopulating.value) return;
  senderInboxId.value = '';
  messageType.value = 'personal';
  receiverAddress.value = '';
  receiverName.value = '';
  groups.value = [];
});

// Reset receiver when sender inbox changes
watch(senderInboxId, () => {
  if (isPopulating.value) return;
  receiverAddress.value = '';
  receiverName.value = '';
  groups.value = [];
  if (messageType.value === 'group') {
    fetchGroups();
  }
});

// Reset receiver and fetch groups when message type changes
watch(messageType, newType => {
  if (isPopulating.value) return;
  receiverAddress.value = '';
  receiverName.value = '';
  if (newType === 'group') {
    fetchGroups();
  }
});

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      isEditing
        ? $t('AGENT_MGMT.SALESBOT.REMINDER.FORM_TITLE_EDIT')
        : $t('AGENT_MGMT.SALESBOT.REMINDER.FORM_TITLE_ADD')
    "
    width="2xl"
    :show-confirm-button="false"
    :show-cancel-button="false"
    overflow-y-auto
    @close="close"
  >
    <div class="flex flex-col gap-5">
      <!-- Title -->
      <Input
        v-model="title"
        :label="$t('AGENT_MGMT.SALESBOT.REMINDER.TITLE_LABEL')"
        :placeholder="$t('AGENT_MGMT.SALESBOT.REMINDER.TITLE_PLACEHOLDER')"
      />

      <!-- Description -->
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.SALESBOT.REMINDER.DESCRIPTION_LABEL') }}
        </label>
        <textarea
          v-model="description"
          rows="2"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all resize-none"
          placeholder="Optional description..."
        />
      </div>

      <!-- Inbox Type -->
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.SALESBOT.REMINDER.INBOX_TYPE_LABEL') }}
        </label>
        <select
          v-model="inboxType"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all"
        >
          <option value="" disabled>Select inbox type</option>
          <option
            v-for="opt in INBOX_TYPE_OPTIONS"
            :key="opt.value"
            :value="opt.value"
          >
            {{ opt.label }}
          </option>
        </select>
      </div>

      <!-- Inbox Selection -->
      <div v-if="inboxType" class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.SALESBOT.REMINDER.INBOX_LABEL') }}
        </label>
        <select
          v-model="senderInboxId"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all"
        >
          <option value="" disabled>
            {{ $t('AGENT_MGMT.NOTIFICATION.SENDER_INBOX_PLACEHOLDER') }}
          </option>
          <option
            v-for="inbox in filteredInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ formatInboxLabel(inbox) }}
          </option>
        </select>
      </div>

      <!-- Message Type (WhatsApp only) -->
      <div v-if="showMessageTypeSelector" class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.NOTIFICATION.MESSAGE_TYPE_LABEL') }}
        </label>
        <div class="flex items-center gap-4">
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="messageType"
              type="radio"
              value="personal"
              class="w-4 h-4 text-green-600 border-gray-300 focus:ring-green-500"
            />
            <span class="text-sm text-slate-900 dark:text-slate-100">
              {{ $t('AGENT_MGMT.NOTIFICATION.MESSAGE_TYPE_PERSONAL') }}
            </span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="messageType"
              type="radio"
              value="group"
              class="w-4 h-4 text-green-600 border-gray-300 focus:ring-green-500"
            />
            <span class="text-sm text-slate-900 dark:text-slate-100">
              {{ $t('AGENT_MGMT.NOTIFICATION.MESSAGE_TYPE_GROUP') }}
            </span>
          </label>
        </div>
      </div>

      <!-- Receiver Address -->
      <div v-if="!showGroupSelector && inboxType">
        <Input
          v-model="receiverAddress"
          :label="$t('AGENT_MGMT.NOTIFICATION.RECEIVER_ADDRESS_LABEL')"
          :placeholder="receiverPlaceholder"
        />
      </div>
      <div v-if="showGroupSelector" class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.NOTIFICATION.RECEIVER_GROUP_LABEL') }}
        </label>
        <ComboBox
          v-model="receiverAddress"
          :options="groups"
          :placeholder="
            $t('AGENT_MGMT.NOTIFICATION.RECEIVER_GROUP_PLACEHOLDER')
          "
          :search-placeholder="
            $t('AGENT_MGMT.NOTIFICATION.GROUP_SEARCH_PLACEHOLDER')
          "
          :empty-state="$t('AGENT_MGMT.NOTIFICATION.NO_GROUPS_FOUND')"
          :initial-display-limit="5"
          :disabled="isLoadingGroups"
          :message="
            isLoadingGroups
              ? $t('AGENT_MGMT.NOTIFICATION.LOADING_GROUPS')
              : ''
          "
        />
      </div>

      <!-- Message -->
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.SALESBOT.REMINDER.MESSAGE_LABEL') }}
        </label>
        <textarea
          v-model="messageTemplate"
          rows="4"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all resize-none"
          :placeholder="
            $t('AGENT_MGMT.SALESBOT.REMINDER.MESSAGE_PLACEHOLDER')
          "
        />
      </div>

      <!-- Date & Time -->
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.SALESBOT.REMINDER.SCHEDULE_LABEL') }}
        </label>
        <input
          v-model="scheduledAt"
          type="datetime-local"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all"
        />
      </div>

      <!-- Recurrence -->
      <RecurrenceSelector
        v-model="recurrenceRule"
        :scheduled-at="scheduledAt"
      />
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <button
          type="button"
          class="w-full px-4 py-2 text-sm font-medium rounded-lg border border-gray-300 dark:border-gray-600 text-slate-700 dark:text-slate-300 bg-white dark:bg-transparent hover:bg-gray-50 dark:hover:bg-slate-700 transition-colors"
          @click="dialogRef?.close()"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.CANCEL_BUTTON') }}
        </button>
        <button
          type="button"
          :disabled="!canSave"
          class="w-full px-4 py-2 text-sm font-medium rounded-lg text-white transition-colors"
          :class="
            canSave
              ? 'bg-green-600 hover:bg-green-700'
              : 'bg-gray-400 cursor-not-allowed'
          "
          @click="handleSave"
        >
          {{
            isEditing
              ? $t('AGENT_MGMT.NOTIFICATION.SAVE_BUTTON_EDIT')
              : $t('AGENT_MGMT.NOTIFICATION.SAVE_BUTTON')
          }}
        </button>
      </div>
    </template>
  </Dialog>
</template>
