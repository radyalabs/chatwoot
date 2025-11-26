<script>
import { mapActions, mapGetters } from 'vuex';
import ChatFooter from '../components/ChatFooter.vue';
import ConversationWrap from '../components/ConversationWrap.vue';

export default {
  name: 'Messages',
  components: { ChatFooter, ConversationWrap },
  props: {
    conversationId: {
      type: [String, Number],
      default: null,
    },
  },
  computed: {
    ...mapGetters({
      groupedMessages: 'conversation/getGroupedConversation',
    }),
  },

  watch: {
    conversationId: {
      immediate: true,
      async handler(newId) {
        if (newId && newId !== 'new') {
          await this.fetchSpecificConversation(newId);
        }
      },
    },
  },

  methods: {
    ...mapActions('conversation', ['loadConversation','setUserLastSeen']),

    async fetchSpecificConversation(id) {
      await this.loadConversation(id);
      this.setUserLastSeen();
    },
  },

  mounted() {
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 overflow-hidden rounded-b-lg bg-slate-25 dark:bg-slate-800"
  >
    <div class="flex flex-1 overflow-auto">
      <ConversationWrap :key="conversationId" :grouped-messages="groupedMessages" />
    </div>
    <ChatFooter class="px-5" />
  </div>
</template>