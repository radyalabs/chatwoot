<template>
  <div class="flex flex-col h-full bg-white">

    <!-- HEADER -->
    <div class="p-4 text-white" :style="{ backgroundColor: widgetColor }">
      <h1 class="text-lg">Messages</h1>
    </div>

    <div class="flex-1 overflow-y-auto custom-scrollbar p-4 shadow-sm">

      <!-- NEW CHAT LABEL -->
      <p class="text-lg text-slate-700 mb-2">Mulai Percakapan Baru</p>

      <!-- START NEW CHAT BOX -->
      <div 
        class="bg-slate-50 rounded-xl p-4 mb-6 flex justify-between items-center cursor-pointer hover:bg-slate-100 transition"
        @click="onNewConversation"
      >
        <div>
          <p class="text-slate-800">Buat Percakapan</p>
          <p class="text-xs text-slate-500">Mulai Percakapan dengan Asisten Kami</p>
        </div>

        <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-white" fill="none" 
            viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M9 5l7 7-7 7" />
          </svg>
        </div>
      </div>

      <!-- RECENT LABEL -->
      <p class="text-lg text-slate-700 mb-2">Percakapan Sebelumnya</p>

      <!-- LOADING -->
      <div v-if="isLoading" class="flex flex-col items-center justify-center h-48 text-slate-400">
        <span class="animate-spin text-2xl mb-2">↻</span>
        <span class="text-sm">Loading...</span>
      </div>

      <!-- NO DATA -->
      <div v-else-if="conversationsList.length === 0" class="text-center py-10 text-slate-500">
        <p>No conversations yet.</p>
      </div>

      <!-- RECENT LIST -->
      <div v-else>
        <div 
          v-for="chat in conversationsList"
          :key="chat.id"
          @click="openChat(chat.id)"
          class="flex items-center justify-between py-3 shadow-sm rounded-xl cursor-pointer hover:bg-slate-50 px-1"
        >
          
          <!-- LEFT: Last message preview -->
          <div class="flex-1 pr-3 px-3">
            <p class="text-sm text-slate-800 line-clamp-2">
              {{ getLastMessageText(chat) }}
            </p>

            <p class="text-xs text-slate-400">
              {{ formatTime(chat.timestamp) }}
            </p>

            <!-- <p class="text-xs text-slate-400 flex items-center gap-1">
              {{ formatTimestamp(chat.timestamp) }}
              · 
              <span :class="statusColor(chat.status)">
                {{ getStatusLabel(chat.status) }}
              </span>
            </p> -->
          </div>

          <!-- RIGHT: unread bubble -->
          <div v-if="chat.unread_count > 0">
            <span class="bg-green-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full">
              {{ chat.unread_count }}
            </span>
          </div>

          <!-- Arrow -->
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-slate-400" fill="none" 
            viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M9 5l7 7-7 7" />
          </svg>

        </div>
      </div>

    </div>
  </div>
</template>

<script>
import { mapActions, mapGetters } from 'vuex';

export default {
  name: 'ConversationList',
  data() {
    return {
      isLoading: false,
    };
  },
  computed: {
    ...mapGetters({
      getConversationsList: 'conversation/getConversationsList',
      widgetColor: 'appConfig/getWidgetColor',
    }),
    conversationsList() {
      return this.getConversationsList;
    }
  },
  methods: {
    ...mapActions('conversation', ['fetchAllConversations', 'loadConversation', 'createConversation']),
    
    formatTime(timestamp) {
      if (!timestamp) return '';
      const date = new Date(timestamp * 1000);
      return date.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
    },

    getLastMessageText(chat) {
      const msg = chat.last_message;

      if (!msg) {
        return this.$t('LAST_MESSAGE.NEW_MESSAGE');
      }

      const lower = msg.toLowerCase();

      const activityMap = [
        { match: 'conversation was marked resolved', key: 'LAST_MESSAGE.CONVERSATION_RESOLVED' },
        { match: 'conversation was reopened', key: 'LAST_MESSAGE.CONVERSATION_REOPENED' },
        { match: 'agent joined the conversation', key: 'LAST_MESSAGE.AGENT_JOINED' },
        { match: 'agent left the conversation', key: 'LAST_MESSAGE.AGENT_LEFT' },
        { match: 'user joined the conversation', key: 'LAST_MESSAGE.USER_JOINED' },
        { match: 'user left the conversation', key: 'LAST_MESSAGE.USER_LEFT' }
      ];

      const detected = activityMap.find(item => lower.includes(item.match));

      if (detected) {
        return this.$t(detected.key);
      }
      return msg;
    },

    async openChat(id) {
      this.$router.push({
        name: 'conversation-chat',
        params: { conversationId: id }
      });
    },

    async onNewConversation() {
      try {
        this.isLoading = true;
        const newConversationId = await this.createConversation({ 
          message: 'Halo',
          // Jika backend Anda butuh status custom, tambahkan di sini
        });
        this.fetchAllConversations();

        if (newConversationId) {
          await this.loadConversation(newConversationId);
          this.$router.push({ 
            name: 'conversation-chat', 
            params: { conversationId: newConversationId } 
          });
        }

      } catch (error) {
        console.error("Gagal membuat percakapan:", error);
      } finally {
        this.isLoading = false;
      }
    }
  },
  async mounted() {
    this.isLoading = true;
    await this.fetchAllConversations();
    this.isLoading = false;
  }
};
</script>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
  width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background-color: #cbd5e1;
  border-radius: 4px;
}
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>