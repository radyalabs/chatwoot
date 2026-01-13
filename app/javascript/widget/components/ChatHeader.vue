<script>
import availabilityMixin from 'widget/mixins/availability';
import nextAvailabilityTime from 'widget/mixins/nextAvailabilityTime';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import HeaderActions from './HeaderActions.vue';
import routerMixin from 'widget/mixins/routerMixin';
import { IFrameHelper } from 'widget/helpers/utils';
import { useDarkMode } from 'widget/composables/useDarkMode';
import { mapGetters } from 'vuex';

export default {
  name: 'ChatHeader',
  components: {
    FluentIcon,
    HeaderActions,
  },
  mixins: [nextAvailabilityTime, availabilityMixin, routerMixin],
  props: {
    avatarUrl: {
      type: String,
      default: '',
    },
    title: {
      type: String,
      default: '',
    },
    showPopoutButton: {
      type: Boolean,
      default: false,
    },
    showBackButton: {
      type: Boolean,
      default: false,
    },
    availableAgents: {
      type: Array,
      default: () => {},
    },
  },
  data() {
    return {
      isLoading: false,
      isMobileDevice: false,
    };
  },
  setup() {
    const { getThemeClass } = useDarkMode();
    return { getThemeClass };
  },
  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
    }),
    computedAvatarUrl() {
      if (this.avatarUrl) return this.avatarUrl.replace('0.0.0.0', '127.0.0.1');
      const url = window.chatwootWebChannel?.avatarUrl || '';
      return url.replace('0.0.0.0', '127.0.0.1');
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
  },
  methods: {
    onBackButtonClick() {
      try {
        if (this.$store && this.$store.state && this.$store.state.conversation) {
          this.$store.state.conversation.__list_loaded__ = false;
        }
      } catch (e) {
        // ignore if state shape differs
        console.warn('[ChatHeader] failed to reset __list_loaded__ flag', e);
      }

      // navigate back to conversation list
      this.replaceRoute('conversation-list');
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
  <header
    class="flex justify-between w-full px-5 py-4"
    :style="{ backgroundColor: widgetColor }"
  >
    <div class="flex items-center">
      <button
        v-if="showBackButton"
        class="px-2 -ml-3"
        @click="onBackButtonClick"
      >
        <FluentIcon
          icon="chevron-left"
          size="24"
          :class="getThemeClass('text-white', 'dark:text-slate-50')"
        />
      </button>
      <img
        v-if="avatarUrl"
        class="w-8 h-8 mr-3 rounded-full"
        :src="avatarUrl"
        alt="avatar"
      />
      <div class="flex flex-col justify-center ml-2">
        <div
          class="text-base font-medium leading-4"
          :class="getThemeClass('text-white', 'dark:text-slate-50')"
        >
          <span v-dompurify-html="title" class="mr-1" />
          <div class="text-xs text-white mt-1 font-medium">
            Online
          </div>
        </div>
      </div>
    </div> 
    <div v-if="isMobileDevice" class="flex items-center">
      <button 
        class="text-white/80 hover:text-white transition p-1 rounded-full hover:bg-white/10 ml-2"
        @click="closeWidget"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>

  </header>
</template>