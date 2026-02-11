<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const props = defineProps({
  reminder: {
    type: Object,
    required: true,
  },
  allInboxesByType: {
    type: Object,
    default: () => ({}),
  },
  connectedInboxesByType: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['edit', 'delete', 'toggle']);

const isExpanded = ref(false);

const senderInbox = computed(() => {
  const inboxes = props.allInboxesByType[props.reminder.receiver_channel_type] || [];
  return inboxes.find(i => i.id === props.reminder.inbox_id);
});

const isDisconnected = computed(() => {
  if (!senderInbox.value) return true;
  const connectedInboxes = props.connectedInboxesByType[props.reminder.receiver_channel_type] || [];
  return !connectedInboxes.some(i => i.id === props.reminder.inbox_id);
});

const channelTypeLabel = computed(() => {
  const map = {
    whatsapp_unofficial: 'WhatsApp Go',
    whatsapp: 'WhatsApp',
    telegram: 'Telegram',
    instagram: 'Instagram',
  };
  return map[props.reminder.receiver_channel_type] || props.reminder.receiver_channel_type;
});

const nextOccurrenceFormatted = computed(() => {
  if (!props.reminder.next_occurrence_at) return 'N/A';
  const date = new Date(props.reminder.next_occurrence_at);
  return date.toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
});

const statusBadge = computed(() => {
  if (!props.reminder.enabled) {
    return { text: t('AGENT_MGMT.SALESBOT.REMINDER.DISABLED'), class: 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400' };
  }
  if (!props.reminder.next_occurrence_at) {
    return { text: 'Completed', class: 'bg-blue-100 text-blue-600 dark:bg-blue-900 dark:text-blue-400' };
  }
  return { text: t('AGENT_MGMT.SALESBOT.REMINDER.ENABLED'), class: 'bg-green-100 text-green-600 dark:bg-green-900 dark:text-green-400' };
});
</script>

<template>
  <div
    class="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden transition-all duration-200"
    :class="{ 'opacity-60': !reminder.enabled }"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between px-4 py-3 bg-gray-50 dark:bg-gray-800/50 cursor-pointer"
      @click="isExpanded = !isExpanded"
    >
      <div class="flex items-center gap-3 min-w-0">
        <span class="i-lucide-bell w-4 h-4 text-gray-500 dark:text-gray-400 shrink-0" />
        <div class="min-w-0">
          <h4 class="text-sm font-medium text-gray-900 dark:text-gray-100 truncate">
            {{ reminder.title }}
          </h4>
          <p class="text-xs text-gray-500 dark:text-gray-400">
            {{ reminder.recurrence_summary || 'One-time' }}
            <span v-if="reminder.next_occurrence_at">
              &middot; {{ t('AGENT_MGMT.SALESBOT.REMINDER.NEXT_OCCURRENCE') }}: {{ nextOccurrenceFormatted }}
            </span>
          </p>
        </div>
      </div>

      <div class="flex items-center gap-2 shrink-0">
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-full"
          :class="statusBadge.class"
        >
          {{ statusBadge.text }}
        </span>
        <button
          class="p-1.5 text-sm text-woot-600 hover:bg-woot-50 dark:hover:bg-woot-900/20 rounded-lg transition-colors"
          :title="'Edit'"
          @click.stop="emit('edit', reminder.id)"
        >
          <span class="i-lucide-pencil w-4 h-4" />
        </button>
        <button
          class="p-1.5 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
          :title="'Delete'"
          @click.stop="emit('delete', reminder.id)"
        >
          <span class="i-lucide-trash-2 w-4 h-4" />
        </button>
        <button
          class="p-1.5 text-gray-400 hover:text-gray-600 transition-colors"
          @click.stop="isExpanded = !isExpanded"
        >
          <span
            class="w-4 h-4 transition-transform duration-200"
            :class="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
          />
        </button>
      </div>
    </div>

    <!-- Expanded Content -->
    <div v-if="isExpanded" class="px-4 py-3 space-y-3 bg-white dark:bg-gray-900">
      <!-- Disconnected warning -->
      <div
        v-if="isDisconnected"
        class="flex items-center gap-2 px-3 py-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg"
      >
        <span class="i-lucide-alert-triangle w-4 h-4 text-amber-500 shrink-0" />
        <span class="text-xs text-amber-700 dark:text-amber-400">
          {{ $t('AGENT_MGMT.NOTIFICATION.INBOX_DISCONNECTED_WARNING') }}
        </span>
      </div>

      <!-- Description -->
      <div v-if="reminder.description" class="text-sm text-gray-600 dark:text-gray-400">
        {{ reminder.description }}
      </div>

      <!-- Sender/Receiver Info -->
      <div class="grid grid-cols-2 gap-4">
        <div>
          <p class="text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Sent from</p>
          <p class="text-sm text-gray-900 dark:text-gray-100">
            {{ senderInbox?.name || 'Unknown inbox' }}
          </p>
          <p class="text-xs text-gray-500">
            {{ channelTypeLabel }}
            <span v-if="senderInbox?.phone_number">
              &middot; {{ senderInbox.phone_number }}
            </span>
          </p>
        </div>
        <div>
          <p class="text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Notify to</p>
          <p class="text-sm text-gray-900 dark:text-gray-100">
            {{ reminder.receiver_name || reminder.receiver_address }}
          </p>
          <p class="text-xs text-gray-500">
            {{ reminder.message_type === 'group' ? 'Group Message' : 'Personal Message' }}
            <span v-if="reminder.receiver_name && reminder.receiver_name !== reminder.receiver_address">
              &middot; {{ reminder.receiver_address }}
            </span>
          </p>
        </div>
      </div>

      <!-- Message Preview -->
      <div>
        <p class="text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Message</p>
        <div class="p-2.5 bg-gray-50 dark:bg-gray-800 rounded-lg text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap break-words max-h-32 overflow-y-auto">
          {{ reminder.message_template }}
        </div>
      </div>

      <!-- Schedule Details -->
      <div class="flex items-center gap-4 text-xs text-gray-500 dark:text-gray-400">
        <span v-if="reminder.occurrence_count > 0">
          Sent {{ reminder.occurrence_count }} time{{ reminder.occurrence_count > 1 ? 's' : '' }}
        </span>
        <span v-if="reminder.last_sent_at">
          Last sent: {{ new Date(reminder.last_sent_at).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' }) }}
        </span>
      </div>

      <!-- Enable/Disable Toggle -->
      <div class="flex items-center justify-between pt-2 border-t border-gray-100 dark:border-gray-800">
        <span class="text-sm text-gray-600 dark:text-gray-400">
          {{ reminder.enabled ? t('AGENT_MGMT.SALESBOT.REMINDER.ENABLED') : t('AGENT_MGMT.SALESBOT.REMINDER.DISABLED') }}
        </span>
        <button
          class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors"
          :class="reminder.enabled ? 'bg-woot-500' : 'bg-gray-300 dark:bg-gray-600'"
          @click="emit('toggle', reminder.id, !reminder.enabled)"
        >
          <span
            class="inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform"
            :class="reminder.enabled ? 'translate-x-4.5' : 'translate-x-0.5'"
          />
        </button>
      </div>
    </div>
  </div>
</template>
