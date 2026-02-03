<script setup>
import { computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  rule: {
    type: Object,
    required: true,
  },
  whatsappUnofficialInboxes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['edit', 'delete']);

const senderInboxName = computed(() => {
  const inbox = props.whatsappUnofficialInboxes.find(
    i => i.id === props.rule.inbox_id
  );
  if (!inbox) return '';
  const phone = inbox.phone_number ? ` (${inbox.phone_number})` : '';
  return `${inbox.name}${phone}`;
});

const channelKeyMap = {
  website: 'INBOX_MGMT.CHANNELS.WEB_WIDGET',
  whatsapp: 'INBOX_MGMT.CHANNELS.WHATSAPP',
  whatsapp_unofficial: 'INBOX_MGMT.CHANNELS.WHATSAPP_UNOFFICIAL',
  api: 'INBOX_MGMT.CHANNELS.API',
  telegram: 'INBOX_MGMT.CHANNELS.TELEGRAM',
  instagram: 'INBOX_MGMT.CHANNELS.INSTAGRAM',
};

const interestKeyMap = {
  low: 'AGENT_MGMT.NOTIFICATION.INTEREST_LOW',
  medium: 'AGENT_MGMT.NOTIFICATION.INTEREST_MEDIUM',
  high: 'AGENT_MGMT.NOTIFICATION.INTEREST_HIGH',
};

const messageTypeKeyMap = {
  personal: 'AGENT_MGMT.NOTIFICATION.CARD_PERSONAL',
  group: 'AGENT_MGMT.NOTIFICATION.CARD_GROUP',
};

const interestColors = {
  low: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
  medium:
    'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
  high: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
};
</script>

<template>
  <div
    class="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-white dark:bg-transparent"
  >
    <div class="flex items-start justify-between">
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <h4
            class="text-sm font-semibold text-slate-900 dark:text-slate-25 truncate"
          >
            {{ rule.category }}
          </h4>
          <span
            v-if="rule.interest_level"
            class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
            :class="interestColors[rule.interest_level]"
          >
            {{ $t(interestKeyMap[rule.interest_level]) }}
          </span>
        </div>
        <p class="text-xs text-slate-500 dark:text-slate-400 mb-2">
          <span v-if="senderInboxName">
            {{ senderInboxName }}
            &middot;
          </span>
          {{
            $t(
              channelKeyMap[rule.receiver_channel_type] ||
                rule.receiver_channel_type
            )
          }}
          &middot;
          {{ rule.receiver_address }}
          &middot;
          {{ $t(messageTypeKeyMap[rule.message_type]) }}
        </p>
        <p
          class="text-sm text-slate-600 dark:text-slate-400 mb-0 line-clamp-2"
        >
          {{ rule.message_template }}
        </p>
      </div>
      <div class="flex items-center gap-1 ml-3 flex-shrink-0">
        <Button
          icon="i-lucide-pencil"
          size="xs"
          variant="ghost"
          color="slate"
          @click="emit('edit', rule.id)"
        />
        <Button
          icon="i-lucide-trash-2"
          size="xs"
          variant="ghost"
          color="ruby"
          @click="emit('delete', rule.id)"
        />
      </div>
    </div>
  </div>
</template>
