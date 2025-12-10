<script>
import TeamAvailability from 'widget/components/TeamAvailability.vue';
import ArticleHero from 'widget/components/ArticleHero.vue';
import ArticleCardSkeletonLoader from 'widget/components/ArticleCardSkeletonLoader.vue';
import { IFrameHelper } from 'widget/helpers/utils';
import { mapGetters } from 'vuex';
import { useDarkMode } from 'widget/composables/useDarkMode';
import routerMixin from 'widget/mixins/routerMixin';
import configMixin from 'widget/mixins/configMixin';

export default {
  name: 'Home',
  components: {
    ArticleHero,
    TeamAvailability,
    ArticleCardSkeletonLoader,
  },
  mixins: [configMixin, routerMixin],
  data() {
    return {
      isLoading: false,
      isMobileDevice: false,
    };
  },
  setup() {
    const { prefersDarkMode } = useDarkMode();
    return { prefersDarkMode };
  },
  computed: {
    ...mapGetters({
      availableAgents: 'agent/availableAgents',
      conversationSize: 'conversation/getConversationSize',
      unreadMessageCount: 'conversation/getUnreadMessageCount',
      popularArticles: 'article/popularArticles',
      articleUiFlags: 'article/uiFlags',
      widgetColor: 'appConfig/getWidgetColor',
    }),
    widgetLocale() {
      return this.$i18n.locale || 'en';
    },
    portal() {
      return window.chatwootWebChannel.portal;
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
    },  
    showArticles() {
      return (
        this.portal &&
        !this.articleUiFlags.isFetching &&
        this.popularArticles.length
      );
    },
    defaultLocale() {
      const widgetLocale = this.widgetLocale;
      const { allowed_locales: allowedLocales, default_locale: defaultLocale } =
        this.portal.config;

      // IMPORTANT: Variation strict locale matching, Follow iso_639_1_code
      // If the exact match of a locale is available in the list of portal locales, return it
      // Else return the default locale. Eg: `es` will not work if `es_ES` is available in the list
      if (allowedLocales.includes(widgetLocale)) {
        return widgetLocale;
      }
      return defaultLocale;
    },
  },
  mounted() {
    const ua = navigator.userAgent || navigator.vendor || window.opera;
    const isAndroidOrIos = /android|iphone|ipod|blackberry|iemobile|opera mini/i.test(ua);
    const isIpadOS = (ua.includes('Mac') && navigator.maxTouchPoints > 1);

    if (isAndroidOrIos || isIpadOS) {
        this.isMobileDevice = true;
    } else {
        this.isMobileDevice = false;
    }

    if (this.portal && this.popularArticles.length === 0) {
      const locale = this.defaultLocale;
      this.$store.dispatch('article/fetch', {
        slug: this.portal.slug,
        locale,
      });
    }
  },
  methods: {
    async onNewConversation() {
      try {
        this.isLoading = true;
        
        // Membuat percakapan baru dengan pesan awal default (misal "Halo")
        // Atau biarkan kosong jika backend mendukungnya
        const newConversationId = await this.createConversation({ 
          message: 'Halo', 
        });

        if (newConversationId) {
          // Load data percakapan agar siap ditampilkan
          await this.loadConversation(newConversationId);
          
          // Redirect langsung ke halaman chat
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
    },

    // Fungsi 2: Ke Halaman List
    goToConversationList() {
      this.$router.push({ name: 'conversation-list' });
    },
    openArticleInArticleViewer(link) {
      let linkToOpen = `${link}?show_plain_layout=true`;
      const isDark = this.prefersDarkMode;
      if (isDark) {
        linkToOpen = `${linkToOpen}&theme=dark`;
      }
      this.$router.push({
        name: 'article-viewer',
        query: { link: linkToOpen },
      });
    },
    viewAllArticles() {
      const locale = this.defaultLocale;
      const {
        portal: { slug },
      } = window.chatwootWebChannel;
      this.openArticleInArticleViewer(`/hc/${slug}/${locale}`);
    },
    closeWidget() {
      if (IFrameHelper.isIFrame()) {
        IFrameHelper.sendMessage({ event: 'closeWindow' });
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full w-full overflow-y-auto" :style="{ backgroundColor: widgetColor }">
    <div class="px-6 pt-10 pb-6 text-white text-center">
      <button 
        v-if="isMobileDevice"
        class="absolute top-4 right-4 text-white/80 hover:text-white transition p-1 rounded-full hover:bg-white/10"
        @click="closeWidget"
        aria-label="Close Widget"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
      <div v-if="avatarUrl" class="flex justify-center mb-4">
         <img 
           :src="avatarUrl" 
           alt="Logo" 
           class="w-12 h-12 rounded-full bg-white object-contain p-1" 
         />
      </div>
      <h1 class="text-2xl font-bold mb-2">{{ welcomeTitle }}</h1>
      <p class="text-sm opacity-90">{{ welcomeTagline }}</p>
    </div>

    <div class="flex-1 px-4 pb-4">
      
      <div 
        @click="onNewConversation"
        class="bg-white rounded-xl p-4 shadow-sm mb-4 cursor-pointer hover:bg-slate-50 transition flex justify-between items-center group relative overflow-hidden"
      >
        <div v-if="isLoading" class="absolute inset-0 bg-white/80 flex items-center justify-center z-10">
           <span class="animate-spin text-2xl text-slate-500">↻</span>
        </div>

        <div class="flex flex-col">
          <span class="font-bold text-slate-800 text-lg flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-green-500" viewBox="0 0 20 20" fill="currentColor">
              <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
            </svg>
            {{ $t('CONVERSATION_HISTORY.NEW') }}
          </span>
          <span class="text-xs text-slate-500 mt-1">
             {{ $t('CONVERSATION_HISTORY.NEW_DESC') }}
          </span>
        </div>
        
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-blue-500 group-hover:translate-x-1 transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </div>

      <div 
        @click="goToConversationList"
        class="bg-white rounded-xl p-4 shadow-sm cursor-pointer hover:bg-slate-50 transition flex justify-between items-center group"
      >
        <div class="flex flex-col">
          <span class="font-bold text-slate-800 text-lg flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            {{ $t('CONVERSATION_HISTORY.LATEST') }}
          </span>
        </div>

        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-blue-500 group-hover:translate-x-1 transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </div>

    </div>
  </div>
</template>
