<script>
import { mapGetters } from 'vuex';
import { shouldBeUrl } from 'shared/helpers/Validators';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import SettingIntroBanner from 'dashboard/components/widgets/SettingIntroBanner.vue';
import SettingsSection from '../../../../components/SettingsSection.vue';
import inboxMixin from 'shared/mixins/inboxMixin';
import FacebookReauthorize from './facebook/Reauthorize.vue';
import MicrosoftReauthorize from './channels/microsoft/Reauthorize.vue';
import GoogleReauthorize from './channels/google/Reauthorize.vue';
import PreChatFormSettings from './PreChatForm/Settings.vue';
import WeeklyAvailability from './components/WeeklyAvailability.vue';
import GreetingsEditor from 'shared/components/GreetingsEditor.vue';
import CollaboratorsPage from './settingsPage/CollaboratorsPage.vue';
import WidgetBuilder from './WidgetBuilder.vue';
import BotConfiguration from './components/BotConfiguration.vue';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import SenderNameExamplePreview from './components/SenderNameExamplePreview.vue';
import WhatsAppStatus from 'dashboard/components/widgets/WhatsAppStatus.vue';

export default {
  components: {
    BotConfiguration,
    CollaboratorsPage,
    FacebookReauthorize,
    GreetingsEditor,
    PreChatFormSettings,
    SettingIntroBanner,
    SettingsSection,
    WeeklyAvailability,
    WidgetBuilder,
    SenderNameExamplePreview,
    MicrosoftReauthorize,
    GoogleReauthorize,
    WhatsAppStatus,
  },
  mixins: [inboxMixin],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      avatarFile: null,
      avatarUrl: '',
      greetingEnabled: true,
      greetingMessage: '',
      greetingImageFile: null, 
      greetingImageUrl: '',
      emailCollectEnabled: false,
      csatSurveyEnabled: false,
      senderNameType: 'friendly',
      businessName: '',
      locktoSingleConversation: false,
      allowMessagesAfterResolved: true,
      continuityViaEmail: true,
      selectedInboxName: '',
      channelWebsiteUrl: '',
      webhookUrl: '',
      channelWelcomeTitle: '',
      channelWelcomeTagline: '',
      selectedFeatureFlags: [],
      replyTime: '',
      selectedTabIndex: 0,
      selectedPortalSlug: '',
      showBusinessNameInput: false,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      uiFlags: 'inboxes/getUIFlags',
      portals: 'portals/allPortals',
    }),
    selectedTabKey() {
      return this.tabs[this.selectedTabIndex]?.key;
    },
    whatsAppAPIProviderName() {
      if (this.isAWhatsAppCloudChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD');
      }
      if (this.is360DialogWhatsAppChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.360_DIALOG');
      }
      if (this.isATwilioWhatsAppChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO');
      }
      return '';
    },
    tabs() {
      let visibleToAllChannelTabs = [
        {
          key: 'inbox_settings',
          name: this.$t('INBOX_MGMT.TABS.SETTINGS'),
        },
        {
          key: 'collaborators',
          name: this.$t('INBOX_MGMT.TABS.COLLABORATORS'),
        },
        {
          key: 'businesshours',
          name: this.$t('INBOX_MGMT.TABS.BUSINESS_HOURS'),
        },
      ];

      if (this.isAWebWidgetInbox) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'preChatForm',
            name: this.$t('INBOX_MGMT.TABS.PRE_CHAT_FORM'),
          },
          {
            key: 'widgetBuilder',
            name: this.$t('INBOX_MGMT.TABS.WIDGET_BUILDER'),
          },
        ];
      }

      if (
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.AGENT_BOTS
        ) &&
        !(this.isAnEmailChannel || this.isATwitterInbox)
      ) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'botConfiguration',
            name: this.$t('INBOX_MGMT.TABS.BOT_CONFIGURATION'),
          },
        ];
      }

      // Add WhatsApp Status tab for WhatsApp Unofficial channels
      if (this.isAWhatsAppUnofficialChannel) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'whatsapp_status',
            name: this.$t('INBOX_MGMT.WHATSAPP_STATUS.TITLE'),
          },
        ];
      }

      return visibleToAllChannelTabs;
    },
    currentInboxId() {
      return this.$route.params.inboxId;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.currentInboxId);
    },

    inboxName() {
      if (this.isATwilioSMSChannel || this.isATwilioWhatsAppChannel) {
        return `${this.inbox.name} (${
          this.inbox.messaging_service_sid || this.inbox.phone_number
        })`;
      }
      if (this.isAWhatsAppChannel) {
        return `${this.inbox.name} (${this.inbox.phone_number})`;
      }
      if (this.isAnEmailChannel) {
        return `${this.inbox.name} (${this.inbox.email})`;
      }
      return this.inbox.name;
    },
    canLocktoSingleConversation() {
      return (
        this.isASmsInbox ||
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAPIInbox
      );
    },
    inboxNameLabel() {
      if (this.isAWebWidgetInbox) {
        return this.$t('INBOX_MGMT.ADD.WEBSITE_NAME.LABEL');
      }
      return this.$t('INBOX_MGMT.ADD.CHANNEL_NAME.LABEL');
    },
    inboxNamePlaceHolder() {
      if (this.isAWebWidgetInbox) {
        return this.$t('INBOX_MGMT.ADD.WEBSITE_NAME.PLACEHOLDER');
      }
      return this.$t('INBOX_MGMT.ADD.CHANNEL_NAME.PLACEHOLDER');
    },
    textAreaChannels() {
      if (
        this.isATwilioChannel ||
        this.isATwitterInbox ||
        this.isAFacebookInbox ||
        this.isAWhatsAppChannel ||
        this.isAWhatsAppUnofficialChannel
      )
        return true;
      return false;
    },
    microsoftUnauthorized() {
      return this.isAMicrosoftInbox && this.inbox.reauthorization_required;
    },
    facebookUnauthorized() {
      return this.isAFacebookInbox && this.inbox.reauthorization_required;
    },
    googleUnauthorized() {
      const isLegacyInbox = ['imap.gmail.com', 'imap.google.com'].includes(
        this.inbox.imap_address
      );

      return (
        (this.isAGoogleInbox || isLegacyInbox) &&
        this.inbox.reauthorization_required
      );
    },
  },
  watch: {
    $route(to) {
      if (to.name === 'settings_inbox_show') {
        this.fetchInboxSettings();
      }
    },
  },
  mounted() {
    this.fetchInboxSettings();
    this.fetchPortals();
  },
  methods: {
    fetchPortals() {
      this.$store.dispatch('portals/index');
    },
    handleFeatureFlag(e) {
      this.selectedFeatureFlags = this.toggleInput(
        this.selectedFeatureFlags,
        e.target.value
      );
    },
    toggleInput(selected, current) {
      if (selected.includes(current)) {
        const newSelectedFlags = selected.filter(flag => flag !== current);
        return newSelectedFlags;
      }
      return [...selected, current];
    },
    onTabChange(selectedTabIndex) {
      this.selectedTabIndex = selectedTabIndex;
    },
    fetchInboxSettings() {
      this.selectedTabIndex = 0;
      this.selectedAgents = [];
      this.$store.dispatch('agents/get');
      this.$store.dispatch('teams/get');
      this.$store.dispatch('labels/get');
      this.$store.dispatch('inboxes/get').then(() => {
        this.avatarUrl = this.inbox.avatar_url;
        this.selectedInboxName = this.inbox.name;
        this.webhookUrl = this.inbox.webhook_url;
        this.greetingEnabled = this.inbox.greeting_enabled || false;
        this.greetingMessage = this.inbox.greeting_message || '';
        this.greetingImageUrl = this.inbox.greeting_image_url || '';
        this.emailCollectEnabled = this.inbox.enable_email_collect;
        this.csatSurveyEnabled = this.inbox.csat_survey_enabled;
        this.senderNameType = this.inbox.sender_name_type;
        this.businessName = this.inbox.business_name;
        this.allowMessagesAfterResolved =
          this.inbox.allow_messages_after_resolved;
        this.continuityViaEmail = this.inbox.continuity_via_email;
        this.channelWebsiteUrl = this.inbox.website_url;
        this.channelWelcomeTitle = this.inbox.welcome_title;
        this.channelWelcomeTagline = this.inbox.welcome_tagline;
        this.selectedFeatureFlags = this.inbox.selected_feature_flags || [];
        this.replyTime = this.inbox.reply_time;
        this.locktoSingleConversation = this.inbox.lock_to_single_conversation;
        this.selectedPortalSlug = this.inbox.help_center
          ? this.inbox.help_center.slug
          : '';
      });
    },
    handleGreetingImageUpload(event) {
      const file = event.target.files[0];
      if (!file) return;

      const validTypes = ['image/jpeg', 'image/png', 'image/jpg', 'image/gif'];
      if (!validTypes.includes(file.type)) {
        useAlert(this.$t('Format file harus JPG, PNG, atau GIF'));
        return;
      }
      
      if (file.size > 4 * 1024 * 1024) {
        useAlert(this.$t('Ukuran file terlalu besar (Maks 4MB)'));
        return;
      }

      this.greetingImageFile = file;
      this.greetingImageUrl = URL.createObjectURL(file);
    },

    deleteGreetingImage() {
      this.greetingImageFile = null;
      this.greetingImageUrl = '';
      if (this.$refs.greetingImageInput) {
        this.$refs.greetingImageInput.value = null;
      }
    },
    async updateInbox() {
      try {
        const payload = {
          id: this.currentInboxId,
          name: this.selectedInboxName,
          enable_email_collect: this.emailCollectEnabled,
          csat_survey_enabled: this.csatSurveyEnabled,
          allow_messages_after_resolved: this.allowMessagesAfterResolved,
          greeting_enabled: this.greetingEnabled,
          greeting_message: this.greetingMessage || '',
          portal_id: this.selectedPortalSlug
            ? this.portals.find(
                portal => portal.slug === this.selectedPortalSlug
              ).id
            : null,
          lock_to_single_conversation: this.locktoSingleConversation,
          sender_name_type: this.senderNameType,
          business_name: this.businessName || null,
          channel: {
            widget_color: this.inbox.widget_color,
            website_url: this.channelWebsiteUrl,
            webhook_url: this.webhookUrl,
            welcome_title: this.channelWelcomeTitle || '',
            welcome_tagline: this.channelWelcomeTagline || '',
            selectedFeatureFlags: this.selectedFeatureFlags,
            reply_time: this.replyTime || 'in_a_few_minutes',
            continuity_via_email: this.continuityViaEmail,
          },
        };
        if (this.greetingImageFile) {
          payload.greeting_image = this.greetingImageFile;
        } else if (this.greetingImageUrl === '' && this.inbox.greeting_image_url) {
          payload.delete_greeting_image = true;
        }

        if (this.avatarFile) {
          payload.avatar = this.avatarFile;
        }
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(error.message || this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    handleImageUpload({ file, url }) {
      this.avatarFile = file;
      this.avatarUrl = url;
    },
    async handleAvatarDelete() {
      try {
        await this.$store.dispatch(
          'inboxes/deleteInboxAvatar',
          this.currentInboxId
        );
        this.avatarFile = null;
        this.avatarUrl = '';
        useAlert(this.$t('INBOX_MGMT.DELETE.API.AVATAR_SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('INBOX_MGMT.DELETE.API.AVATAR_ERROR_MESSAGE')
        );
      }
    },
    toggleSenderNameType(key) {
      this.senderNameType = key;
    },
    onClickShowBusinessNameInput() {
      this.showBusinessNameInput = !this.showBusinessNameInput;
      if (this.showBusinessNameInput) {
        this.$nextTick(() => {
          this.$refs.businessNameInput.focus();
        });
      }
    },
    onWhatsAppStatusChanged(statusData) {
      // console.log('WhatsApp status changed:', statusData);
      // Handle status change if needed
    },
    onWhatsAppStatusError(error) {
      console.error('WhatsApp status error:', error);
      useAlert('Gagal memeriksa status WhatsApp');
    },
    onWhatsAppSessionRestarted(data) {
      // console.log('WhatsApp session restarted:', data);
      useAlert('Session WhatsApp berhasil direstart');
    },
    onWhatsAppRestartError(error) {
      console.error('WhatsApp restart error:', error);
      useAlert('Gagal restart session WhatsApp');
    },
  },
  validations: {
    webhookUrl: {
      shouldBeUrl,
    },
    selectedInboxName: {},
  },
};
</script>

<template>
  <div
    class="flex-grow flex-shrink w-full min-w-0 pl-0 pr-0 overflow-auto bg-white settings dark:bg-slate-800"
  >
    <SettingIntroBanner
      :header-image="inbox.avatarUrl"
      :header-title="inboxName"
    >
      <woot-tabs
        class="settings--tabs"
        :index="selectedTabIndex"
        :border="false"
        @change="onTabChange"
      >
        <woot-tabs-item
          v-for="(tab, index) in tabs"
          :key="tab.key"
          :index="index"
          :name="tab.name"
          :show-badge="false"
        />
      </woot-tabs>
    </SettingIntroBanner>
    <MicrosoftReauthorize v-if="microsoftUnauthorized" :inbox="inbox" />
    <FacebookReauthorize v-if="facebookUnauthorized" :inbox="inbox" />
    <GoogleReauthorize v-if="googleUnauthorized" :inbox="inbox" />

    <div v-if="selectedTabKey === 'inbox_settings'" class="mx-8">
      <SettingsSection
        :title="$t('INBOX_MGMT.SETTINGS_POPUP.INBOX_UPDATE_TITLE')"
        :sub-title="$t('INBOX_MGMT.SETTINGS_POPUP.INBOX_UPDATE_SUB_TEXT')"
        :show-border="false"
      >
        <woot-avatar-uploader
          :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_AVATAR.LABEL')"
          :src="avatarUrl"
          class="pb-4"
          delete-avatar
          @on-avatar-select="handleImageUpload"
          @on-avatar-delete="handleAvatarDelete"
        />
        <woot-input
          v-model="selectedInboxName"
          class="w-3/4 pb-4"
          :class="{ error: v$.selectedInboxName.$error }"
          :label="inboxNameLabel"
          :placeholder="inboxNamePlaceHolder"
          :error="
            v$.selectedInboxName.$error
              ? $t('INBOX_MGMT.ADD.CHANNEL_NAME.ERROR')
              : ''
          "
          @blur="v$.selectedInboxName.$touch"
        />
        <woot-input
          v-if="isAPIInbox"
          v-model="webhookUrl"
          class="w-3/4 pb-4"
          :class="{ error: v$.webhookUrl.$error }"
          :label="
            $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.LABEL')
          "
          :placeholder="
            $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.PLACEHOLDER')
          "
          :error="
            v$.webhookUrl.$error
              ? $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.ERROR')
              : ''
          "
          @blur="v$.webhookUrl.$touch"
        />
        <woot-input
          v-if="isAWebWidgetInbox"
          v-model="channelWebsiteUrl"
          class="w-3/4 pb-4"
          :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.LABEL')"
          :placeholder="
            $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.PLACEHOLDER')
          "
        />
        <woot-input
          v-if="isAWebWidgetInbox"
          v-model="channelWelcomeTitle"
          class="w-3/4 pb-4"
          :label="
            $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.LABEL')
          "
          :placeholder="
            $t(
              'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.PLACEHOLDER'
            )
          "
        />

        <woot-input
          v-if="isAWebWidgetInbox"
          v-model="channelWelcomeTagline"
          class="w-3/4 pb-4"
          :label="
            $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.LABEL')
          "
          :placeholder="
            $t(
              'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.PLACEHOLDER'
            )
          "
        />

        <label v-if="isAWebWidgetInbox" class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL') }}
          <woot-color-picker v-model="inbox.widget_color" />
        </label>

        <label v-if="isAWhatsAppChannel" class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.LABEL') }}
          <input v-model="whatsAppAPIProviderName" type="text" disabled />
        </label>

        <!-- <label class="w-3/4 pb-4">
          {{
            $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.LABEL')
          }}
          <select v-model="greetingEnabled">
            <option :value="true">
              {{
                $t(
                  'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.ENABLED'
                )
              }}
            </option>
            <option :value="false">
              {{
                $t(
                  'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.DISABLED'
                )
              }}
            </option>
          </select>
          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.HELP_TEXT'
              )
            }}
          </p>
        </label>
        <div v-if="greetingEnabled" class="pb-4">
          <GreetingsEditor
            v-model="greetingMessage"
            :label="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.LABEL'
              )
            "
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.PLACEHOLDER'
              )
            "
            :richtext="!textAreaChannels"
          />
          <div class="mb-4 w-3/4">
            <label class="block text-sm font-bold text-slate-800 dark:text-slate-200 mb-2">
              {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_IMAGE.TITLE') }}
            </label>

            <div v-if="greetingImageUrl" class="relative inline-block group">
              <img 
                :src="greetingImageUrl" 
                class="h-40 w-auto rounded-lg border border-slate-200 dark:border-slate-700 object-cover shadow-sm"
                alt="Greeting Preview" 
              />
              <button
                type="button"
                @click="deleteGreetingImage"
                class="absolute -top-2 -right-2 bg-red-500 hover:bg-red-600 text-white rounded-full p-1.5 shadow-md transition-all opacity-0 group-hover:opacity-100"
                title="Hapus gambar"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div v-else class="w-full">
              <label 
                for="greeting-image-upload" 
                class="flex flex-col items-center justify-center w-full h-32 border-2 border-dashed border-slate-300 dark:border-slate-600 rounded-lg cursor-pointer bg-slate-50 dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
              >
                <div class="flex flex-col items-center justify-center pt-5 pb-6">
                  <svg class="w-8 h-8 mb-2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                  <p class="mb-1 text-sm text-slate-500 dark:text-slate-400"><span class="font-semibold">{{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_IMAGE.DESC') }}</span></p>
                  <p class="text-xs text-slate-400">{{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_IMAGE.MAX_SIZE') }}</p>
                </div>
                <input 
                  ref="greetingImageInput"
                  id="greeting-image-upload" 
                  type="file" 
                  class="hidden" 
                  accept="image/png, image/jpeg, image/jpg, image/gif"
                  @change="handleGreetingImageUpload" 
                />
              </label>
            </div>
          </div>
        </div>
        <label v-if="isAWebWidgetInbox" class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.TITLE') }}
          <select v-model="replyTime">
            <option key="in_a_few_minutes" value="in_a_few_minutes">
              {{
                $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_FEW_MINUTES')
              }}
            </option>
            <option key="in_a_few_hours" value="in_a_few_hours">
              {{
                $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_FEW_HOURS')
              }}
            </option>
            <option key="in_a_day" value="in_a_day">
              {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_DAY') }}
            </option>
          </select>

          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.HELP_TEXT') }}
          </p>
        </label>

        <label v-if="isAWebWidgetInbox" class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX') }}
          <select v-model="emailCollectEnabled">
            <option :value="true">
              {{ $t('INBOX_MGMT.EDIT.EMAIL_COLLECT_BOX.ENABLED') }}
            </option>
            <option :value="false">
              {{ $t('INBOX_MGMT.EDIT.EMAIL_COLLECT_BOX.DISABLED') }}
            </option>
          </select>
          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{
              $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX_SUB_TEXT')
            }}
          </p>
        </label>

        <label class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CSAT') }}
          <select v-model="csatSurveyEnabled">
            <option :value="true">
              {{ $t('INBOX_MGMT.EDIT.ENABLE_CSAT.ENABLED') }}
            </option>
            <option :value="false">
              {{ $t('INBOX_MGMT.EDIT.ENABLE_CSAT.DISABLED') }}
            </option>
          </select>
          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{ $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CSAT_SUB_TEXT') }}
          </p>
        </label> -->

        <label v-if="isAWebWidgetInbox" class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED') }}
          <select v-model="allowMessagesAfterResolved">
            <option :value="true">
              {{ $t('INBOX_MGMT.EDIT.ALLOW_MESSAGES_AFTER_RESOLVED.ENABLED') }}
            </option>
            <option :value="false">
              {{ $t('INBOX_MGMT.EDIT.ALLOW_MESSAGES_AFTER_RESOLVED.DISABLED') }}
            </option>
          </select>
          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{
              $t(
                'INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED_SUB_TEXT'
              )
            }}
          </p>
        </label>

        <label v-if="isAWebWidgetInbox" class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL') }}
          <select v-model="continuityViaEmail">
            <option :value="true">
              {{ $t('INBOX_MGMT.EDIT.ENABLE_CONTINUITY_VIA_EMAIL.ENABLED') }}
            </option>
            <option :value="false">
              {{ $t('INBOX_MGMT.EDIT.ENABLE_CONTINUITY_VIA_EMAIL.DISABLED') }}
            </option>
          </select>
          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{
              $t(
                'INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL_SUB_TEXT'
              )
            }}
          </p>
        </label>
        <div class="w-3/4 pb-4">
          <label>
            {{ $t('INBOX_MGMT.HELP_CENTER.LABEL') }}
          </label>
          <select v-model="selectedPortalSlug" class="filter__question">
            <option value="">
              {{ $t('INBOX_MGMT.HELP_CENTER.PLACEHOLDER') }}
            </option>
            <option v-for="p in portals" :key="p.slug" :value="p.slug">
              {{ p.name }}
            </option>
          </select>
          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{ $t('INBOX_MGMT.HELP_CENTER.SUB_TEXT') }}
          </p>
        </div>
        <label v-if="canLocktoSingleConversation" class="w-3/4 pb-4">
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.LOCK_TO_SINGLE_CONVERSATION') }}
          <select v-model="locktoSingleConversation">
            <option :value="true">
              {{ $t('INBOX_MGMT.EDIT.LOCK_TO_SINGLE_CONVERSATION.ENABLED') }}
            </option>
            <option :value="false">
              {{ $t('INBOX_MGMT.EDIT.LOCK_TO_SINGLE_CONVERSATION.DISABLED') }}
            </option>
          </select>
          <p class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400">
            {{
              $t(
                'INBOX_MGMT.SETTINGS_POPUP.LOCK_TO_SINGLE_CONVERSATION_SUB_TEXT'
              )
            }}
          </p>
        </label>

        <label v-if="isAWebWidgetInbox">
          {{ $t('INBOX_MGMT.FEATURES.LABEL') }}
        </label>
        <div v-if="isAWebWidgetInbox" class="flex gap-2 pt-2 pb-4">
          <input
            v-model="selectedFeatureFlags"
            type="checkbox"
            value="attachments"
            @input="handleFeatureFlag"
          />
          <label for="attachments">
            {{ $t('INBOX_MGMT.FEATURES.DISPLAY_FILE_PICKER') }}
          </label>
        </div>
        <div v-if="isAWebWidgetInbox" class="flex gap-2 pb-4">
          <input
            v-model="selectedFeatureFlags"
            type="checkbox"
            value="emoji_picker"
            @input="handleFeatureFlag"
          />
          <label for="emoji_picker">
            {{ $t('INBOX_MGMT.FEATURES.DISPLAY_EMOJI_PICKER') }}
          </label>
        </div>
        <div v-if="isAWebWidgetInbox" class="flex gap-2 pb-4">
          <input
            v-model="selectedFeatureFlags"
            type="checkbox"
            value="end_conversation"
            @input="handleFeatureFlag"
          />
          <label for="end_conversation">
            {{ $t('INBOX_MGMT.FEATURES.ALLOW_END_CONVERSATION') }}
          </label>
        </div>
        <div v-if="isAWebWidgetInbox" class="flex gap-2 pb-4">
          <input
            v-model="selectedFeatureFlags"
            type="checkbox"
            value="use_inbox_avatar_for_bot"
            @input="handleFeatureFlag"
          />
          <label for="use_inbox_avatar_for_bot">
            {{ $t('INBOX_MGMT.FEATURES.USE_INBOX_AVATAR_FOR_BOT') }}
          </label>
        </div>
      </SettingsSection>
      <SettingsSection
        v-if="isAWebWidgetInbox || isAnEmailChannel"
        :title="$t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.TITLE')"
        :sub-title="$t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.SUB_TEXT')"
        :show-border="false"
      >
        <div class="w-3/4 pb-4">
          <SenderNameExamplePreview
            :sender-name-type="senderNameType"
            :business-name="businessName"
            @update="toggleSenderNameType"
          />
          <div class="flex flex-col items-start gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="primary"
              @click="onClickShowBusinessNameInput"
            >
              {{
                $t(
                  'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.BUTTON_TEXT'
                )
              }}
            </woot-button>
            <div v-if="showBusinessNameInput" class="flex gap-2 w-[80%]">
              <input
                ref="businessNameInput"
                v-model="businessName"
                :placeholder="
                  $t(
                    'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.PLACEHOLDER'
                  )
                "
                class="mb-0"
                type="text"
              />
              <woot-button color-scheme="primary" @click="updateInbox">
                {{
                  $t(
                    'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.SAVE_BUTTON_TEXT'
                  )
                }}
              </woot-button>
            </div>
          </div>
        </div>
      </SettingsSection>
      <SettingsSection :show-border="false">
        <woot-submit-button
          v-if="isAPIInbox"
          type="submit"
          :disabled="v$.webhookUrl.$invalid"
          :button-text="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
          :loading="uiFlags.isUpdating"
          @click="updateInbox"
        />
        <woot-submit-button
          v-else
          type="submit"
          :disabled="v$.$invalid"
          :button-text="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
          :loading="uiFlags.isUpdating"
          @click="updateInbox"
        />
      </SettingsSection>
    </div>

    <div v-if="selectedTabKey === 'collaborators'" class="mx-8">
      <CollaboratorsPage :inbox="inbox" />
    </div>
    <div v-if="selectedTabKey === 'preChatForm'">
      <PreChatFormSettings :inbox="inbox" />
    </div>
    <div v-if="selectedTabKey === 'businesshours'">
      <WeeklyAvailability :inbox="inbox" />
    </div>
    <div v-if="selectedTabKey === 'widgetBuilder'">
      <WidgetBuilder :inbox="inbox" />
    </div>
    <div v-if="selectedTabKey === 'botConfiguration'">
      <BotConfiguration :inbox="inbox" />
    </div>
    <div v-if="selectedTabKey === 'whatsapp_status'">
      <div class="p-8">
        <!-- WhatsApp Status Widget -->
        <WhatsAppStatus
          v-if="inbox"
          :inbox-id="inbox.id"
          :account-id="accountId"
          @status-changed="onWhatsAppStatusChanged"
          @status-error="onWhatsAppStatusError"
          @session-restarted="onWhatsAppSessionRestarted"
          @restart-error="onWhatsAppRestartError"
        />
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.settings--tabs {
  ::v-deep .tabs {
    @apply p-0;
  }
}
</style>
