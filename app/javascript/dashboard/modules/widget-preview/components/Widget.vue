<script>
import InputRadioGroup from 'dashboard/routes/dashboard/settings/inbox/components/InputRadioGroup.vue';
import globalConfigMixin from 'shared/mixins/globalConfigMixin';
import { mapGetters } from 'vuex';

export default {
  name: 'Widget',
  components: {
    InputRadioGroup,
  },
  mixins: [globalConfigMixin],
  props: {
    welcomeHeading: {
      type: String,
      default: '',
    },
    welcomeTagline: {
      type: String,
      default: '',
    },
    websiteName: {
      type: String,
      required: true,
    },
    logo: {
      type: String,
      default: '',
    },
    isOnline: {
      type: Boolean,
      default: true,
    },
    replyTime: {
      type: String,
      default: '',
    },
    replyFast: {
      type: String,
      default: '',
    },
    color: {
      type: String,
      default: '',
    },
    widgetBubblePosition: {
      type: String,
      default: '',
    },
    widgetBubbleLauncherTitle: {
      type: String,
      default: '',
    },
    widgetBubbleType: {
      type: String,
      default: '',
    },
    hideBranding: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      widgetScreens: [
        {
          id: 'default',
          title: this.$t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_SCREEN.DEFAULT'),
          checked: true,
        },
        {
          id: 'chat',
          title: this.$t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_SCREEN.CHAT'),
          checked: false,
        },
      ],
      isDefaultScreen: true,
      isWidgetVisible: true,
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    getBubblePositionStyle() {
      return {
        justifyContent: this.widgetBubblePosition === 'left' ? 'start' : 'end',
      };
    },
    isBubbleExpanded() {
      return (
        !this.isWidgetVisible && this.widgetBubbleType === 'expanded_bubble'
      );
    },
    getWidgetBubbleLauncherTitle() {
      return this.isWidgetVisible || this.widgetBubbleType === 'standard'
        ? ' '
        : this.widgetBubbleLauncherTitle;
    },
    // Menghitung warna teks berdasarkan kecerahan background widget (simple logic)
    textColor() {
      // Default ke putih karena desain Home menggunakan background color penuh
      return 'text-white';
    }
  },
  methods: {
    handleScreenChange(item) {
      this.isDefaultScreen = item.id === 'default';
      // Update checked state
      this.widgetScreens = this.widgetScreens.map(screen => ({
        ...screen,
        checked: screen.id === item.id
      }));
    },
    toggleWidget() {
      this.isWidgetVisible = !this.isWidgetVisible;
      this.isDefaultScreen = true;
      // Reset radio button to default when closing/opening
      this.widgetScreens = this.widgetScreens.map(screen => ({
        ...screen,
        checked: screen.id === 'default'
      }));
    },
  },
};
</script>

<template>
  <div>
    <div v-if="isWidgetVisible" class="flex flex-col items-center mb-4">
      <InputRadioGroup
        name="widget-screen"
        :items="widgetScreens"
        :action="handleScreenChange"
      />
    </div>

    <div
      v-if="isWidgetVisible"
      class="widget-wrapper relative flex flex-col justify-between rounded-xl shadow-xl overflow-hidden h-[550px] w-[340px] bg-slate-50 dark:bg-slate-800 font-inter"
    >
      
      <div 
        v-if="isDefaultScreen" 
        class="flex flex-col h-full w-full overflow-y-auto custom-scrollbar" 
        :style="{ backgroundColor: color }"
      >
        <div class="px-6 pt-10 pb-6 text-white text-center">
          <div v-if="logo" class="flex justify-center mb-4">
            <img 
              :src="logo" 
              alt="Logo" 
              class="w-12 h-12 rounded-full bg-white object-contain p-1 shadow-sm" 
            />
          </div>
          <h1 class="text-2xl font-bold mb-2 leading-tight">
            {{ welcomeHeading || 'Welcome' }}
          </h1>
          <p class="text-sm opacity-90 leading-relaxed">
            {{ welcomeTagline || 'How can we help you?' }}
          </p>
        </div>

        <div class="flex-1 px-4 pb-4 bg-transparent">
          
          <div 
            class="bg-white rounded-xl p-4 shadow-sm mb-3 cursor-default flex justify-between items-center group relative overflow-hidden"
          >
            <div class="flex flex-col">
              <span class="font-bold text-slate-800 text-lg flex items-center gap-2">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-green-500" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
                </svg>
                {{ $t('INBOX_MGMT.WIDGET_BUILDER.START_CONVERSATION') }}
              </span>
              <span class="text-xs text-slate-500 mt-1">
                 {{ $t('INBOX_MGMT.WIDGET_BUILDER.START_CONVERSATION_DESC') }}
              </span>
            </div>
            
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>

          <div 
            class="bg-white rounded-xl p-4 shadow-sm cursor-default flex justify-between items-center group"
          >
            <div class="flex flex-col">
              <span class="font-bold text-slate-800 text-lg flex items-center gap-2">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                {{ $t('INBOX_MGMT.WIDGET_BUILDER.PREV_CONVERSATION') }}
              </span>
            </div>

            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>

          <div class="py-4 flex justify-center mt-auto">
            <a v-if="!hideBranding" 
              class="items-center gap-1.5 text-white/80 cursor-default flex filter opacity-80 hover:opacity-100 text-xs font-medium"
            >
              <span class="text-xxs uppercase tracking-wider">Powered by</span>
              <img
                class="h-3 w-auto opacity-90 brightness-0 invert"
                :src="globalConfig.logoThumbnail"
                alt="Chatwoot"
              />
              <span class="font-bold">
                {{ globalConfig.installationName }}
              </span>
            </a>
          </div>

        </div>
      </div>

      <div v-else class="flex flex-col h-full bg-slate-50 dark:bg-slate-900">
        
        <div class="px-4 py-3 shadow-sm flex items-center gap-3" :style="{ background: color }">
           <div class="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center text-white">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
           </div>
           <div class="flex flex-col">
              <span class="font-bold text-white text-sm">{{ websiteName }}</span>
              <span class="text-xs text-white/80 flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-green-400"></span>
                {{ isOnline ? 'Online' : 'Offline' }}
              </span>
           </div>
        </div>

        <div class="flex-1 p-4 overflow-y-auto space-y-4">
          <div class="flex gap-2">
            <div v-if="logo" class="flex-shrink-0">
               <img :src="logo" class="w-6 h-6 rounded-full object-cover" />
            </div>
            <div v-else class="flex-shrink-0 w-6 h-6 rounded-full bg-slate-200 flex items-center justify-center">
               <span class="text-xs text-slate-500">B</span>
            </div>
            <div class="bg-white dark:bg-slate-800 p-3 rounded-tr-xl rounded-br-xl rounded-bl-xl shadow-sm max-w-[85%]">
              <p class="text-sm text-slate-700 dark:text-slate-100">
                {{ $t('INBOX_MGMT.WIDGET_BUILDER.WELCOME_MESSAGE') }}
              </p>
              <span class="text-[10px] text-slate-400 mt-1 block">10:00 AM</span>
            </div>
          </div>

          <div class="flex gap-2 justify-end">
             <div class="p-3 rounded-tl-xl rounded-bl-xl rounded-br-xl shadow-sm max-w-[85%] text-white" :style="{ backgroundColor: color }">
              <p class="text-sm">
                {{ $t('INBOX_MGMT.WIDGET_BUILDER.USER_QUESTION') }}
              </p>
              <span class="text-[10px] text-white/70 mt-1 block text-right">10:02 AM</span>
            </div>
          </div>
        </div>

        <div class="px-4 py-3 bg-white dark:bg-slate-800 border-t border-slate-100 dark:border-slate-700">
           <div class="relative">
             <input 
                disabled
                type="text" 
                placeholder="Type your message..." 
                class="w-full bg-slate-50 dark:bg-slate-700 border-none rounded-full py-2.5 px-4 text-sm text-slate-600 focus:outline-none cursor-default"
             />
             <button class="absolute right-2 top-1/2 -translate-y-1/2 p-1.5 text-slate-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 rotate-90" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
             </button>
           </div>
           <div class="flex justify-center mt-2" v-if="!hideBranding">
              <span class="text-[10px] text-slate-400 flex items-center gap-1">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
                </svg>
                Secured by {{ globalConfig.installationName }}
              </span>
           </div>
        </div>
      </div>

    </div>

    <div class="flex mt-4 w-[340px]" :style="getBubblePositionStyle">
      <button
        class="relative flex items-center justify-center rounded-full cursor-pointer shadow-lg hover:shadow-xl transition-all duration-200 transform hover:scale-105"
        :style="{ background: color }"
        :class="
          isBubbleExpanded
            ? 'w-auto font-medium text-base text-white dark:text-white h-14 px-6'
            : 'w-16 h-16'
        "
        @click="toggleWidget"
      >
        <img
          v-if="!isWidgetVisible"
          src="~dashboard/assets/images/bubble-logo.svg"
          alt=""
          draggable="false"
          class="w-8 h-8 mx-auto filter drop-shadow-sm"
        />
        <div v-if="isBubbleExpanded" class="ltr:pl-2.5 rtl:pr-2.5">
          {{ getWidgetBubbleLauncherTitle }}
        </div>
        <div v-if="isWidgetVisible" class="relative">
          <div class="absolute w-0.5 h-8 rotate-45 -translate-y-1/2 bg-white rounded-full" />
          <div
            class="absolute w-0.5 h-8 -rotate-45 -translate-y-1/2 bg-white rounded-full"
          />
        </div>
      </button>
    </div>
  </div>
</template>

<style scoped>
/* Custom scrollbar untuk area widget agar terlihat rapi */
.custom-scrollbar::-webkit-scrollbar {
  width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 4px;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}
</style>