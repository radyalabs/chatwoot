<script setup>
import { ref, watch, computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import MessageTemplateEditor from './MessageTemplateEditor.vue';
import WhatsAppUnofficialChannels from 'dashboard/api/WhatsAppUnofficialChannels';

const { t } = useI18n();

const props = defineProps({
  rule: {
    type: Object,
    default: null,
  },
  whatsappUnofficialInboxes: {
    type: Array,
    default: () => [],
  },
  variableConfig: {
    type: Object,
    default: () => ({
      helpKey: 'AGENT_MGMT.LEADGENBOT.NOTIFICATION.TEMPLATE_HELP',
      variables: [],
    }),
  },
});

const emit = defineEmits(['save', 'close']);

const dialogRef = ref(null);

const senderInboxId = ref('');
const category = ref('');
const interestLevel = ref('');
const messageType = ref('personal');
const receiverAddress = ref('');
const messageTemplate = ref('');

const groups = ref([]);
const isLoadingGroups = ref(false);
const isPopulating = ref(false);

const isEditing = computed(() => !!props.rule);

const formatInboxLabel = inbox => {
  const phone = inbox.phone_number ? ` (${inbox.phone_number})` : '';
  return `${inbox.name}${phone}`;
};

const resetForm = () => {
  senderInboxId.value = '';
  category.value = '';
  interestLevel.value = '';
  messageType.value = 'personal';
  receiverAddress.value = '';
  messageTemplate.value = t('AGENT_MGMT.NOTIFICATION.DEFAULT_TEMPLATE');
};

const populateForm = rule => {
  isPopulating.value = true;
  senderInboxId.value = rule.inbox_id || '';
  category.value = rule.category || '';
  interestLevel.value = rule.interest_level || '';
  messageType.value = rule.message_type || 'personal';
  receiverAddress.value = rule.receiver_address || '';
  messageTemplate.value = rule.message_template || '';
  nextTick(() => {
    isPopulating.value = false;
  });
};

const open = () => {
  if (props.rule) {
    populateForm(props.rule);
    if (props.rule.message_type === 'group') {
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

const handleSave = () => {
  const payload = {
    inbox_id: senderInboxId.value,
    category: category.value,
    interest_level: interestLevel.value || null,
    message_type: messageType.value,
    receiver_channel_type: 'whatsapp_unofficial',
    receiver_address: receiverAddress.value,
    message_template: messageTemplate.value,
  };
  if (props.rule?.id) {
    payload.id = props.rule.id;
  }
  emit('save', payload);
  dialogRef.value?.close();
};

const canSave = computed(() => {
  return (
    senderInboxId.value &&
    category.value.trim() &&
    receiverAddress.value.trim() &&
    messageTemplate.value.trim()
  );
});

const fetchGroups = async () => {
  if (!senderInboxId.value) {
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

// Reset receiver address when switching message type; fetch groups when switching to group
watch(messageType, newType => {
  if (isPopulating.value) return;
  receiverAddress.value = '';
  if (newType === 'group') {
    fetchGroups();
  }
});

// Re-fetch groups when sender inbox changes (if group mode is active)
watch(senderInboxId, () => {
  if (isPopulating.value) return;
  receiverAddress.value = '';
  groups.value = [];
  if (messageType.value === 'group') {
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
        ? $t('AGENT_MGMT.NOTIFICATION.FORM_TITLE_EDIT')
        : $t('AGENT_MGMT.NOTIFICATION.FORM_TITLE_ADD')
    "
    width="2xl"
    :show-confirm-button="false"
    :show-cancel-button="false"
    overflow-y-auto
    @close="close"
  >
    <div class="flex flex-col gap-5">
      <!-- Sender Inbox -->
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.NOTIFICATION.SENDER_INBOX_LABEL') }}
        </label>
        <select
          v-model="senderInboxId"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all"
        >
          <option value="" disabled>
            {{ $t('AGENT_MGMT.NOTIFICATION.SENDER_INBOX_PLACEHOLDER') }}
          </option>
          <option
            v-for="inbox in whatsappUnofficialInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ formatInboxLabel(inbox) }}
          </option>
        </select>
      </div>

      <!-- Category Notification -->
      <Input
        v-model="category"
        :label="$t('AGENT_MGMT.NOTIFICATION.CATEGORY_LABEL')"
        :placeholder="$t('AGENT_MGMT.NOTIFICATION.CATEGORY_PLACEHOLDER')"
      />

      <!-- Interest Level -->
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.NOTIFICATION.INTEREST_LEVEL_LABEL') }}
        </label>
        <select
          v-model="interestLevel"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all"
        >
          <option value="">
            {{ $t('AGENT_MGMT.NOTIFICATION.INTEREST_LEVEL_NONE') }}
          </option>
          <option value="low">
            {{ $t('AGENT_MGMT.NOTIFICATION.INTEREST_LOW') }}
          </option>
          <option value="medium">
            {{ $t('AGENT_MGMT.NOTIFICATION.INTEREST_MEDIUM') }}
          </option>
          <option value="high">
            {{ $t('AGENT_MGMT.NOTIFICATION.INTEREST_HIGH') }}
          </option>
        </select>
      </div>

      <!-- Message Type -->
      <div class="flex flex-col gap-1">
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

      <!-- Receiver Channel Address -->
      <div v-if="messageType === 'personal'">
        <Input
          v-model="receiverAddress"
          :label="$t('AGENT_MGMT.NOTIFICATION.RECEIVER_ADDRESS_LABEL')"
          :placeholder="
            $t('AGENT_MGMT.NOTIFICATION.RECEIVER_PLACEHOLDER_WHATSAPP')
          "
        />
      </div>
      <div v-else class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.NOTIFICATION.RECEIVER_GROUP_LABEL') }}
        </label>
        <div
          v-if="isLoadingGroups"
          class="text-sm text-slate-500 dark:text-slate-400 py-2"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.LOADING_GROUPS') }}
        </div>
        <select
          v-else-if="groups.length"
          v-model="receiverAddress"
          class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-green-500 transition-all"
        >
          <option value="" disabled>
            {{ $t('AGENT_MGMT.NOTIFICATION.RECEIVER_GROUP_PLACEHOLDER') }}
          </option>
          <option
            v-for="group in groups"
            :key="group.value"
            :value="group.value"
          >
            {{ group.label }} ({{ group.value }})
          </option>
        </select>
        <p
          v-else
          class="text-sm text-slate-500 dark:text-slate-400 italic py-2"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.NO_GROUPS') }}
        </p>
      </div>

      <!-- Message Template -->
      <MessageTemplateEditor
        v-model="messageTemplate"
        :variable-config="variableConfig"
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
