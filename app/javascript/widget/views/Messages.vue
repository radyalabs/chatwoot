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
  data() {
    return {
      pollingInterval: null,
    };
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
        this.stopPolling();
        if (newId && newId !== 'new') {
          await this.fetchSpecificConversation(newId);
          this.startPolling();
        }
      },
    },
  },

  methods: {
    ...mapActions('conversation', ['loadConversation','setUserLastSeen', 'syncLatestMessages']),
    ...mapActions('conversationAttributes', ['getAttributes']),

    async fetchSpecificConversation(id) {
      await this.loadConversation(id);
      await this.getAttributes(id);
      this.setUserLastSeen();
    },
    startPolling() {
      // Cek pesan baru setiap 4 detik
      this.pollingInterval = setInterval(() => {
        if (this.conversationId && this.conversationId !== 'new') {
          this.syncLatestMessages();
        }
      }, 4000);
    },

    stopPolling() {
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
        this.pollingInterval = null;
      }
    },
  },

  mounted() {
    if (this.conversationId && this.conversationId !== 'new') {
      this.startPolling();
    }
  },

  beforeUnmount() { // Gunakan beforeDestroy jika Vue 2
    this.stopPolling();
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