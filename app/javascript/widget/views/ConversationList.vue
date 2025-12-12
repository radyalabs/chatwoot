<template>
  <div class="flex flex-col h-full w-full relative overflow-hidden" :style="{ backgroundColor: widgetColor }">
    
    <div class="pt-6 pb-8 px-4 text-white text-center relative shrink-0">
      
      <button 
        class="absolute top-5 left-4 text-white/80 hover:text-white transition p-1 rounded-full hover:bg-white/10"
        @click="goBack"
        title="Back to Home"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      <button
        v-if="isMobileDevice"
        class="absolute top-5 right-4 text-white/80 hover:text-white transition p-1 rounded-full hover:bg-white/10" 
        @click="closeWidget"
        title="Close Widget"
      >
        <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>

      <div class="flex justify-center items-center mb-3 mt-1">
        <div class="relative">
           <img 
             v-if="avatarUrl" 
             :src="avatarUrl" 
             class="w-12 h-12 rounded-full border-2 border-white/20 bg-white object-contain p-0.5 z-10 relative" 
           />
           <div class="absolute top-0 -left-6 w-10 h-10 rounded-full bg-white/10 z-0"></div>
           <div class="absolute top-0 -right-6 w-10 h-10 rounded-full bg-white/10 z-0"></div>
        </div>
      </div>

      <h1 class="text-lg font-bold">{{ $t('CONVERSATION_HISTORY.TITLE') }}</h1>
    </div>

    <div class="flex-1 bg-white rounded-t-3xl shadow-[0_-5px_15px_rgba(0,0,0,0.1)] flex flex-col overflow-hidden w-full mx-auto relative z-10">
      
      <div class="shrink-0 pt-6 px-6">
        <div 
          class="bg-slate-50 rounded-xl p-4 mb-6 flex justify-between items-center cursor-pointer hover:bg-slate-100 transition shadow-sm border border-slate-100"
          @click="onNewConversation"
        >
          <div>
            <p class="text-sm font-bold text-slate-800">{{ $t('CONVERSATION_HISTORY.NEW') }}</p>
            <p class="text-xs text-slate-500 mt-0.5">{{ $t('CONVERSATION_HISTORY.NEW_DESC') }}</p>
          </div>

          <div class="w-8 h-8 rounded-full flex items-center justify-center shadow-sm" :style="{ backgroundColor: widgetColor }">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-white" fill="none" 
              viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </div>

        <div class="flex items-center pt-2">
          <div class="h-px bg-slate-100 flex-1"></div>
          <span class="pl-4 text-xs text-slate-400 font-bold uppercase tracking-wider">{{ $t('CONVERSATION_HISTORY.RECENT') }}</span>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto custom-scrollbar px-2 pb-4">
        
        <div v-if="isLoading" class="flex flex-col items-center justify-center py-10 text-slate-400">
           <span class="animate-spin text-2xl mb-2">↻</span>
        </div>

        <div v-else-if="conversationsList.length === 0" class="text-center py-8 text-slate-400">
           <p class="text-sm">{{ $t('CONVERSATION_HISTORY.NEW_USER') }}</p>
        </div>

        <div v-else class="space-y-2 mt-1 px-2">
          <div 
             v-for="chat in conversationsList" 
             :key="chat.id"
             @click="openChat(chat.id)"
             class="flex items-center gap-4 p-3 rounded-xl hover:bg-slate-50 cursor-pointer transition relative group"
           >
            <div class="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center shrink-0 text-slate-400 group-hover:bg-white group-hover:shadow-sm transition">
                <!-- <svg class="h-6 w-6" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
                </svg> -->
              <img 
                :src="getChatAvatar(chat)" 
                alt="Avatar"
                class="w-full h-full object-cover"
              />
            </div>

            <div class="flex-1 min-w-0">
               <div class="flex justify-between items-center mb-1">
                  <h4 class="text-sm font-bold text-slate-800">Assistant</h4>
                  <span class="text-[10px] text-slate-400">{{ formatTime(chat.timestamp) }}</span>
               </div>
               
               <p class="text-sm text-slate-500 line-clamp-1">
                  {{ getLastMessageText(chat) }}
               </p>
            </div>

            <div v-if="chat.unread_count > 0" class="absolute right-3 top-8">
               <span class="bg-green-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full ring-2 ring-white">
                  {{ chat.unread_count }}
               </span>
            </div>
          </div>
        </div>

      </div>

    </div>
  </div>
</template>

<script>
import { mapActions, mapGetters } from 'vuex';
import { IFrameHelper } from 'widget/helpers/utils';

export default {
  name: 'ConversationList',
  data() {
    return {
      isLoading: false,
      isMobileDevice: false,
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
    avatarUrl() {
      const url = window.chatwootWebChannel?.avatarUrl || '';
      return url.replace('0.0.0.0', '127.0.0.1');
    }
  },
  methods: {
    ...mapActions('conversation', ['fetchAllConversations', 'loadConversation', 'createConversation']),

    closeWidget() {
      if (IFrameHelper.isIFrame()) {
        IFrameHelper.sendMessage({ event: 'closeWindow' });
      }
    },

    goBack() {
      this.$router.push({ name: 'home' });
    },
    
    formatTime(timestamp) {
      if (!timestamp) return '';
      const date = new Date(timestamp * 1000);
      const now = new Date();

      const isToday = date.toDateString() === now.toDateString();

      if (isToday) {
        return new Intl.DateTimeFormat('id-ID', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: false
        }).format(date);
      } else {
        return new Intl.DateTimeFormat('id-ID', {
          day: 'numeric',
          month: 'short'
        }).format(date);
      }
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

    getChatAvatar(chat) {
      return '/assets/images/chatwoot_bot.png';
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

    const ua = navigator.userAgent || navigator.vendor || window.opera;
    const isAndroidOrIos = /android|iphone|ipod|blackberry|iemobile|opera mini/i.test(ua);
    const isIpadOS = (ua.includes('Mac') && navigator.maxTouchPoints > 1);

    if (isAndroidOrIos || isIpadOS) {
        this.isMobileDevice = true;
    } else {
        this.isMobileDevice = false;
    }

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