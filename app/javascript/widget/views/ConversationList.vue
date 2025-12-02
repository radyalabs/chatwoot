<template>
  <div class="flex flex-col h-full bg-white overflow-hidden">

    <!-- HEADER -->
    <div class="p-4 text-white flex justify-between items-center shadow-md z-10 shrink-0" :style="{ backgroundColor: widgetColor }">
      <h1 class="text-lg">{{ $t('CONVERSATION_HISTORY.TITLE') }}</h1>
      <img 
        v-if="avatarUrl"
        :src="avatarUrl" 
        alt="Logo" 
        class="w-8 h-8 rounded-full bg-white object-contain p-0.5"
      />
    </div>

    <div class="px-4 pt-4 pb-0 shrink-0 z-10 bg-white border-b border-slate-50">
      <!-- WELCOME MESSAGE -->
      <div v-if="welcomeTagline" class="mb-8 mt-2">
        <h2 v-if="welcomeTitle" class="text-2xl font-bold text-slate-800 mb-1">
          {{ welcomeTitle }}
        </h2>
        <p class="text-slate-600 leading-relaxed text-xs line-clamp-2">
          {{ welcomeTagline }}
        </p>
      </div>
      <!-- NEW CHAT LABEL -->
      <p class="text-sm text-slate-700 mb-2">{{ $t('CONVERSATION_HISTORY.START') }}</p>
      <!-- START NEW CHAT BOX -->
      <div 
        class="bg-slate-50 rounded-xl p-4 mb-6 flex justify-between items-center cursor-pointer hover:bg-slate-100 transition"
        @click="onNewConversation"
      >
        <div>
          <p class="text-sm text-slate-800">{{ $t('CONVERSATION_HISTORY.NEW') }}</p>
          <p class="text-xs text-slate-500">{{ $t('CONVERSATION_HISTORY.NEW_DESC') }}</p>
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
      <p class="text-sm text-slate-700 mb-2">{{ $t('CONVERSATION_HISTORY.LATEST') }}</p>
    </div>

    <div class="flex-1 overflow-y-auto custom-scrollbar px-4 py-2 shadow-sm">

      <!-- LOADING -->
      <div v-if="isLoading" class="flex flex-col items-center justify-center h-48 text-slate-400">
        <span class="animate-spin text-2xl mb-2">↻</span>
        <span class="text-sm">Loading...</span>
      </div>

      <!-- NO DATA -->
      <div v-else-if="conversationsList.length === 0" class="text-center py-10 text-slate-500">
        <p class="text-sm">{{ $t('CONVERSATION_HISTORY.NEW_USER') }}</p>
      </div>

      <!-- RECENT LIST -->
      <div v-else>
        <div 
          v-for="chat in conversationsList"
          :key="chat.id"
          @click="openChat(chat.id)"
          class="flex items-center justify-between py-1 shadow-sm rounded-xl cursor-pointer hover:bg-slate-50 px-1 h-20"
        >
          
          <!-- LEFT: Last message preview -->
          <div class="flex-1 pr-3 px-3">
            <p class="text-sm text-slate-800 line-clamp-2">
              {{ getLastMessageText(chat) }}
            </p>

            <div class="flex items-center gap-4">
              <span class="text-xs text-slate-400">
                {{ formatTime(chat.timestamp) }}
              </span>

              <span 
                class="text-[10px] px-1.5 py-0.5 rounded border capitalize"
                :class="getStatusClasses(chat.status)"
              >
                {{ getStatusLabel(chat.status) }}
              </span>
            </div>
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
    },
    welcomeTagline() {
      return window.chatwootWebChannel?.welcomeTagline || '';
    },
    welcomeTitle() {
      return window.chatwootWebChannel?.welcomeTitle || '';
    },
    avatarUrl() {
      const url = window.chatwootWebChannel?.avatarUrl || '';
      return url.replace('0.0.0.0', '127.0.0.1');
    }
  },
  methods: {
    ...mapActions('conversation', ['fetchAllConversations', 'loadConversation', 'createConversation']),
    
    formatTime(timestamp) {
      if (!timestamp) return '';
      const date = new Date(timestamp * 1000);

      return new Intl.DateTimeFormat('id-ID', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false // Pakai format 24 jam (14:00), ubah ke true jika ingin AM/PM
      }).format(date);
    },

    getStatusLabel(status) {
      const map = {
        open: 'Berjalan',
        resolved: 'Selesai',
        pending: 'Menunggu',
        snoozed: 'Ditunda'
      };
      return map[status] || status;
    },

    getStatusClasses(status) {
      if (status === 'open') {
        return 'bg-green-50 text-green-600 border-green-200';
      }
      if (status === 'resolved') {
        return 'bg-slate-100 text-slate-500 border-slate-200';
      }
      if (status === 'pending') {
        return 'bg-yellow-50 text-yellow-600 border-yellow-200';
      }
      return 'bg-gray-50 text-gray-500 border-gray-200';
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
    console.log('[ConversationList] mounted');

    // clear selected conversation
    this.$store.commit('conversation/clearSelectedConversation');

    if (this.$store.state.conversation.__list_loaded__) {
      console.log('[ConversationList] skip fetchAllConversations (already loaded)');
      return;
    }

    console.log('[ConversationList] fetching conversations...');
    this.isLoading = true;

    await this.fetchAllConversations();

    this.$store.state.conversation.__list_loaded__ = true;

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