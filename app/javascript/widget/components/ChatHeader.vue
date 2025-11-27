<script>
import availabilityMixin from 'widget/mixins/availability';
import nextAvailabilityTime from 'widget/mixins/nextAvailabilityTime';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import HeaderActions from './HeaderActions.vue';
import routerMixin from 'widget/mixins/routerMixin';
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
  setup() {
    const { getThemeClass } = useDarkMode();
    return { getThemeClass };
  },
  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
    })
    // isOnline() {
    //   const { workingHoursEnabled } = this.channelConfig;
    //   const anyAgentOnline = this.availableAgents.length > 0;

    //   if (workingHoursEnabled) {
    //     return this.isInBetweenTheWorkingHours;
    //   }
    //   return anyAgentOnline;
    // },
  },
  methods: {
    onBackButtonClick() {
      this.replaceRoute('conversation-list');
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
  </header>
</template>
