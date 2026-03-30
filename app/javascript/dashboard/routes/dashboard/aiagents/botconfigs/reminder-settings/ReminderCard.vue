<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

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

const emit = defineEmits(['edit', 'delete']);

const isExpanded = ref(false);
const isMessageExpanded = ref(false);
const messageRef = ref(null);
const isMessageOverflowing = ref(false);

const senderInbox = computed(() => {
  const inboxes =
    props.allInboxesByType[props.reminder.receiver_channel_type] || [];
  return inboxes.find(i => i.id === props.reminder.inbox_id);
});

const isDisconnected = computed(() => {
  if (!senderInbox.value) return true;
  const connectedInboxes =
    props.connectedInboxesByType[props.reminder.receiver_channel_type] || [];
  return !connectedInboxes.some(i => i.id === props.reminder.inbox_id);
});

const channelTypeLabel = computed(() => {
  const map = {
    whatsapp_unofficial: 'WhatsApp Go',
    whatsapp: 'WhatsApp',
    telegram: 'Telegram',
    instagram: 'Instagram',
  };
  return (
    map[props.reminder.receiver_channel_type] ||
    props.reminder.receiver_channel_type
  );
});

const nextOccurrenceFormatted = computed(() => {
  if (!props.reminder.next_occurrence_at) return '';
  const date = new Date(props.reminder.next_occurrence_at);
  return date.toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
});

const isCompleted = computed(() => {
  return props.reminder.enabled && !props.reminder.next_occurrence_at;
});

const receiverDisplayName = computed(() => {
  return props.reminder.receiver_name || props.reminder.receiver_address;
});

const isCustomRecurrence = computed(() => {
  return props.reminder.recurrence_rule?.preset === 'custom';
});

const hasRecurrence = computed(() => !!props.reminder.recurrence_rule);

const recurrenceLabel = computed(() => {
  return (
    props.reminder.recurrence_summary ||
    t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_NONE')
  );
});

const cardContainerClasses = computed(() => {
  if (isCompleted.value) {
    return 'border border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900/30';
  }
  if (!props.reminder.enabled) {
    return 'border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-900/50';
  }
  return 'border border-gray-200 dark:border-gray-700 bg-white dark:bg-transparent';
});

const headerBgClasses = computed(() => {
  if (!props.reminder.enabled && !isCompleted.value) {
    return 'bg-gray-100 dark:bg-gray-800/70';
  }
  return 'bg-gray-50 dark:bg-gray-800/50';
});

const bellIconClasses = computed(() => {
  if (isCompleted.value) {
    return 'i-lucide-bell-ring size-5 text-blue-500 dark:text-blue-400';
  }
  if (!props.reminder.enabled) {
    return 'i-lucide-bell-off size-5 text-gray-400 dark:text-gray-500';
  }
  return 'i-lucide-bell size-5 text-green-500 dark:text-green-400';
});

const lastSentFormatted = computed(() => {
  if (!props.reminder.last_sent_at) return '';
  return new Date(props.reminder.last_sent_at).toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
});

const sentCountText = computed(() => {
  const count = props.reminder.occurrence_count;
  if (!count || count <= 0) return '';
  if (count === 1) {
    return t('AGENT_MGMT.REMINDER.MANAGEMENT.SENT_COUNT_ONE', { count });
  }
  return t('AGENT_MGMT.REMINDER.MANAGEMENT.SENT_COUNT_OTHER', { count });
});

const checkMessageOverflow = () => {
  if (messageRef.value) {
    isMessageOverflowing.value =
      messageRef.value.scrollHeight > messageRef.value.clientHeight;
  }
};

watch(isExpanded, val => {
  if (val) {
    nextTick(() => checkMessageOverflow());
  }
});

onMounted(() => {
  nextTick(() => checkMessageOverflow());
});
</script>

<template>
  <div
    class="rounded-lg overflow-hidden transition-all duration-200"
    :class="cardContainerClasses"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between px-4 py-3 cursor-pointer"
      :class="headerBgClasses"
      @click="isExpanded = !isExpanded"
    >
      <!-- Left: Icon + Info -->
      <div class="flex items-center gap-3 min-w-0 flex-1">
        <span class="shrink-0" :class="bellIconClasses" />
        <div class="min-w-0 flex-1">
          <h4
            class="text-sm font-semibold text-slate-900 dark:text-slate-100 truncate"
          >
            {{ reminder.title }}
          </h4>
          <div
            class="flex items-center gap-1.5 mt-0.5 text-xs text-slate-500 dark:text-slate-400 min-w-0"
          >
            <span class="truncate shrink-[2]">
              {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.CARD_SEND_TO') }}:
              {{ receiverDisplayName }}
            </span>
            <span class="shrink-0">&middot;</span>
            <span
              class="i-lucide-repeat size-3 shrink-0"
              :class="
                hasRecurrence
                  ? 'text-slate-400 dark:text-slate-500'
                  : 'text-slate-300 dark:text-slate-600'
              "
            />
            <span
              v-if="isCustomRecurrence"
              class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold leading-none shrink-0 bg-indigo-50 dark:bg-indigo-600/40 text-slate-900 dark:text-slate-100"
            >
              {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.REPEAT_CUSTOM') }}
            </span>
            <span
              class="truncate shrink-[1]"
              :class="
                hasRecurrence
                  ? 'text-slate-400 dark:text-slate-400'
                  : 'text-slate-400 dark:text-slate-500'
              "
            >
              {{ recurrenceLabel }}
            </span>
          </div>
          <p
            v-if="reminder.next_occurrence_at && reminder.enabled"
            class="text-xs text-slate-400 dark:text-slate-500 mt-0.5"
          >
            {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.NEXT_OCCURRENCE') }}:
            {{ nextOccurrenceFormatted }}
          </p>
        </div>
      </div>

      <!-- Right: Toggle + Actions -->
      <div class="flex items-center gap-2 shrink-0 ml-3">
        <!-- Completed badge -->
        <span
          v-if="isCompleted"
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-medium bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400"
        >
          <span class="i-lucide-check-circle size-3.5" />
          {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.COMPLETED') }}
        </span>

        <Button
          icon="i-lucide-pencil"
          size="sm"
          variant="faded"
          color="slate"
          :aria-label="$t('AGENT_MGMT.NOTIFICATION.CARD_EDIT')"
          @click.stop="emit('edit', reminder.id)"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.CARD_EDIT') }}
        </Button>
        <Button
          icon="i-lucide-trash-2"
          size="sm"
          variant="ghost"
          color="ruby"
          :aria-label="$t('AGENT_MGMT.NOTIFICATION.CARD_DELETE')"
          @click.stop="emit('delete', reminder.id)"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.CARD_DELETE') }}
        </Button>

        <button
          type="button"
          class="p-1.5 rounded-md text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
          :aria-expanded="isExpanded"
          @click.stop="isExpanded = !isExpanded"
        >
          <span
            class="i-lucide-chevron-down size-4 block transition-transform duration-200"
            :class="{ 'rotate-180': isExpanded }"
          />
        </button>
      </div>
    </div>

    <!-- Expanded Content -->
    <div v-show="isExpanded">
      <div class="border-t border-gray-200 dark:border-gray-700" />

      <div class="px-4 py-3 space-y-4">
        <!-- Disconnected warning -->
        <div
          v-if="isDisconnected"
          class="flex items-center gap-2 px-3 py-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg"
        >
          <span
            class="i-lucide-triangle-alert size-4 text-slate-600 dark:text-slate-300 shrink-0"
          />
          <span class="text-xs text-slate-600 dark:text-slate-300">
            {{ $t('AGENT_MGMT.NOTIFICATION.INBOX_DISCONNECTED_WARNING') }}
          </span>
        </div>

        <!-- Note -->
        <div v-if="reminder.description">
          <div
            class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-2 flex items-center gap-1.5"
          >
            <span
              class="i-lucide-sticky-note text-slate-400 dark:text-slate-500 size-3.5"
            />
            {{ $t('AGENT_MGMT.REMINDER.MANAGEMENT.NOTE_LABEL') }}
          </div>
          <div
            class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700"
          >
            <p
              class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap break-words mb-0"
            >
              {{ reminder.description }}
            </p>
          </div>
        </div>

        <!-- Sender Info -->
        <div class="flex flex-col">
          <div
            class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-2 flex items-center gap-1.5"
          >
            <span
              class="i-lucide-send text-slate-400 dark:text-slate-500 size-3.5"
            />
            {{ $t('AGENT_MGMT.NOTIFICATION.CARD_SENT_FROM') }}
          </div>
          <div
            class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700"
          >
            <div class="flex items-center gap-2 mb-1">
              <span
                class="i-lucide-smartphone text-slate-500 dark:text-slate-400 size-4"
              />
              <span
                class="text-sm font-medium text-slate-800 dark:text-slate-200 truncate"
                :title="senderInbox?.name"
              >
                {{
                  senderInbox?.name ||
                  t('AGENT_MGMT.REMINDER.MANAGEMENT.UNKNOWN_INBOX')
                }}
              </span>
            </div>
            <div class="text-xs text-slate-500 dark:text-slate-400 ml-6">
              {{ channelTypeLabel }}
            </div>
            <div
              v-if="senderInbox?.phone_number"
              class="text-xs text-slate-500 dark:text-slate-400 ml-6 font-mono"
            >
              {{ senderInbox.phone_number }}
            </div>
          </div>
        </div>

        <!-- Message Preview -->
        <div>
          <div
            class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-2 flex items-center gap-1.5"
          >
            <span
              class="i-lucide-message-square text-slate-400 dark:text-slate-500 size-3.5"
            />
            {{ $t('AGENT_MGMT.NOTIFICATION.CARD_MESSAGE_LABEL') }}
          </div>
          <div
            class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700"
          >
            <p
              ref="messageRef"
              class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap break-words mb-0"
              :class="{ 'line-clamp-4': !isMessageExpanded }"
            >
              {{ reminder.message_template }}
            </p>
            <button
              v-if="isMessageOverflowing || isMessageExpanded"
              type="button"
              class="mt-2 text-sm font-medium text-woot-500 dark:text-woot-400 hover:text-woot-600 dark:hover:text-woot-300 focus:outline-none focus:underline"
              :aria-expanded="isMessageExpanded"
              @click="isMessageExpanded = !isMessageExpanded"
            >
              {{
                isMessageExpanded
                  ? $t('AGENT_MGMT.NOTIFICATION.SHOW_LESS')
                  : $t('AGENT_MGMT.NOTIFICATION.SHOW_MORE')
              }}
            </button>
          </div>
        </div>

        <!-- Schedule Details -->
        <div
          v-if="reminder.occurrence_count > 0 || reminder.last_sent_at"
          class="flex items-center gap-4 text-xs text-slate-500 dark:text-slate-400"
        >
          <span v-if="sentCountText">{{ sentCountText }}</span>
          <span v-if="lastSentFormatted">
            {{ t('AGENT_MGMT.REMINDER.MANAGEMENT.LAST_SENT') }}:
            {{ lastSentFormatted }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
