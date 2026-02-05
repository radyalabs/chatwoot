<script setup>
import { computed, ref, onMounted, nextTick, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const props = defineProps({
  rule: {
    type: Object,
    required: true,
  },
  whatsappUnofficialInboxes: {
    type: Array,
    default: () => [],
  },
  whatsappGroups: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['edit', 'delete']);

// Sender inbox info
const senderInbox = computed(() => {
  return props.whatsappUnofficialInboxes.find(
    i => i.id === props.rule.inbox_id
  );
});

const senderInboxName = computed(() => {
  if (!senderInbox.value) return '';
  return senderInbox.value.name;
});

const senderPhoneNumber = computed(() => {
  if (!senderInbox.value) return '';
  return senderInbox.value.phone_number || '';
});

// Receiver display name: prefer stored receiver_name, fallback to receiver_address
const receiverDisplayName = computed(() => {
  return props.rule.receiver_name || props.rule.receiver_address;
});

// Receiver type label
const receiverTypeLabel = computed(() => {
  if (props.rule.message_type === 'group') {
    return t('AGENT_MGMT.NOTIFICATION.MESSAGE_TYPE_GROUP');
  }
  return t('AGENT_MGMT.NOTIFICATION.MESSAGE_TYPE_PERSONAL');
});

// Format message with highlighted variables
const formattedMessage = computed(() => {
  if (!props.rule.message_template) return '';
  return props.rule.message_template.replace(
    /\{\{(\w+)\}\}/g,
    '<span class="inline-block px-1.5 py-0.5 mx-0.5 bg-woot-100 dark:bg-woot-900/30 border border-woot-300 dark:border-woot-600 rounded text-xs font-mono text-woot-700 dark:text-woot-300">$1</span>'
  );
});

// Expand/collapse state for message preview
const isExpanded = ref(false);
const messageRef = ref(null);
const isOverflowing = ref(false);

const checkOverflow = () => {
  if (messageRef.value) {
    isOverflowing.value =
      messageRef.value.scrollHeight > messageRef.value.clientHeight;
  }
};

const toggleExpand = () => {
  isExpanded.value = !isExpanded.value;
};

// Check overflow on mount
onMounted(() => {
  nextTick(() => checkOverflow());
});

// Re-check overflow when message template changes
watch(
  () => props.rule.message_template,
  () => {
    isExpanded.value = false;
    nextTick(() => checkOverflow());
  }
);

const interestKeyMap = {
  low: 'AGENT_MGMT.NOTIFICATION.INTEREST_LOW',
  medium: 'AGENT_MGMT.NOTIFICATION.INTEREST_MEDIUM',
  high: 'AGENT_MGMT.NOTIFICATION.INTEREST_HIGH',
};

const interestColors = {
  low: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
  medium:
    'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
  high: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
};
</script>

<template>
  <div
    class="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-white dark:bg-transparent"
  >
    <!-- Header: Category + Interest Badge + Actions -->
    <div class="flex items-start justify-between gap-3 mb-4">
      <!-- Title Group -->
      <div class="flex items-center gap-3 flex-1 min-w-0">
        <div class="flex items-center gap-2 flex-1 min-w-0">
          <span class="i-lucide-bell text-slate-400 dark:text-slate-500 size-5 flex-shrink-0" />
          <span class="text-sm text-slate-500 dark:text-slate-400">
            {{ $t('AGENT_MGMT.NOTIFICATION.CARD_CATEGORY_LABEL') }}:
          </span>
          <span
            class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate"
            :title="rule.category"
          >
            {{ rule.category }}
          </span>
        </div>

        <!-- Interest Badge -->
        <span
          v-if="rule.interest_level"
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-medium flex-shrink-0"
          :class="interestColors[rule.interest_level]"
          :title="$t('AGENT_MGMT.NOTIFICATION.CARD_INTEREST_HELPER')"
        >
          <span class="text-inherit opacity-70">
            {{ $t('AGENT_MGMT.NOTIFICATION.CARD_INTEREST_LABEL') }}:
          </span>
          {{ $t(interestKeyMap[rule.interest_level]) }}
        </span>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center gap-2 flex-shrink-0">
        <Button
          icon="i-lucide-pencil"
          size="sm"
          variant="faint"
          color="slate"
          :aria-label="$t('AGENT_MGMT.NOTIFICATION.CARD_EDIT')"
          @click="emit('edit', rule.id)"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.CARD_EDIT') }}
        </Button>
        <Button
          icon="i-lucide-trash-2"
          size="sm"
          variant="ghost"
          color="ruby"
          :aria-label="$t('AGENT_MGMT.NOTIFICATION.CARD_DELETE')"
          @click="emit('delete', rule.id)"
        >
          {{ $t('AGENT_MGMT.NOTIFICATION.CARD_DELETE') }}
        </Button>
      </div>
    </div>

    <!-- Divider -->
    <div class="border-t border-gray-200 dark:border-gray-700 mb-4" />

    <!-- Sender & Receiver Section (Two Columns) -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
      <!-- Sender -->
      <div>
        <div class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-2 flex items-center gap-1.5">
          <span class="i-lucide-send text-slate-400 dark:text-slate-500 size-3.5" />
          {{ $t('AGENT_MGMT.NOTIFICATION.CARD_SENT_FROM') }}
        </div>
        <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
          <div class="flex items-center gap-2 mb-1">
            <span class="i-lucide-smartphone text-slate-500 dark:text-slate-400 size-4" />
            <span class="text-sm font-medium text-slate-800 dark:text-slate-200 truncate" :title="senderInboxName">
              {{ senderInboxName || '-' }}
            </span>
          </div>
          <div class="text-xs text-slate-500 dark:text-slate-400 ml-6">
            WhatsApp
          </div>
          <div
            v-if="senderPhoneNumber"
            class="text-xs text-slate-500 dark:text-slate-400 ml-6 font-mono"
          >
            {{ senderPhoneNumber }}
          </div>
        </div>
      </div>

      <!-- Receiver -->
      <div>
        <div class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-2 flex items-center gap-1.5">
          <span class="i-lucide-inbox text-slate-400 dark:text-slate-500 size-3.5" />
          {{ $t('AGENT_MGMT.NOTIFICATION.CARD_SEND_TO') }}
        </div>
        <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
          <div class="flex items-center gap-2 mb-1">
            <span
              :class="rule.message_type === 'group' ? 'i-lucide-users' : 'i-lucide-user'"
              class="text-slate-500 dark:text-slate-400 size-4"
            />
            <span class="text-sm font-medium text-slate-800 dark:text-slate-200 truncate" :title="receiverDisplayName">
              {{ receiverDisplayName }}
            </span>
          </div>
          <div class="text-xs text-slate-500 dark:text-slate-400 ml-6">
            {{ receiverTypeLabel }}
          </div>
          <div
            v-if="rule.message_type === 'group'"
            class="text-xs text-slate-500 dark:text-slate-400 ml-6 font-mono truncate"
            :title="rule.receiver_address"
          >
            {{ rule.receiver_address }}
          </div>
        </div>
      </div>
    </div>

    <!-- Message Preview Section -->
    <div>
      <div class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-2 flex items-center gap-1.5">
        <span class="i-lucide-message-square text-slate-400 dark:text-slate-500 size-3.5" />
        {{ $t('AGENT_MGMT.NOTIFICATION.CARD_MESSAGE_LABEL') }}
      </div>
      <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
        <!-- eslint-disable-next-line vue/no-v-html -->
        <p
          ref="messageRef"
          class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap break-words mb-0"
          :class="{ 'line-clamp-4': !isExpanded }"
          v-html="formattedMessage"
        />
        <!-- Toggle Button -->
        <button
          v-if="isOverflowing || isExpanded"
          type="button"
          class="mt-2 text-sm font-medium text-woot-500 dark:text-woot-400 hover:text-woot-600 dark:hover:text-woot-300 focus:outline-none focus:underline"
          :aria-expanded="isExpanded"
          @click="toggleExpand"
        >
          {{
            isExpanded
              ? $t('AGENT_MGMT.NOTIFICATION.SHOW_LESS')
              : $t('AGENT_MGMT.NOTIFICATION.SHOW_MORE')
          }}
        </button>
      </div>
    </div>
  </div>
</template>
