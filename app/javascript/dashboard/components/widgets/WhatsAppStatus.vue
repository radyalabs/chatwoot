<script>
import WhatsAppUnofficialChannels from 'dashboard/api/WhatsAppUnofficialChannels';
import { createConsumer } from '@rails/actioncable';
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { useI18n } from 'vue-i18n';

export default {
  props: {
    inboxId: {
      type: [Number, String],
      required: true,
    },
    accountId: {
      type: [Number, String],
      required: true,
    },
    autoRefresh: {
      type: Boolean,
      default: false,
    },
    refreshInterval: {
      type: Number,
      default: 10000,
    },
  },
  emits: [
    'statusChanged',
    'statusError',
    'sessionDisconnected',
    'disconnectError',
    'sessionReconnected',
    'reconnectError',
  ],
  setup() {
    const { t } = useI18n();
    return { t };
  },
  data() {
    return {
      connectionStatus: 'checking',
      lastChecked: null,
      isLoading: false,
      isDisconnecting: false,
      isReconnecting: false,
      refreshTimer: null,
      subscription: null,
      showDisconnectConfirm: false,
      // QR Code state
      showQRCard: false,
      qrCodeData: null,
      qrCodeType: null,
      isLoadingQR: false,
      qrRefreshTimer: null,
      qrCountdownTimer: null,
      qrDuration: 60,
      qrCountdown: 60,
      statusPollingTimer: null,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      currentAccountId: 'getCurrentAccountId',
      currentUserId: 'getCurrentUserID',
    }),
    userPubsubToken() {
      return this.currentUser?.pubsub_token;
    },
    statusColor() {
      if (this.connectionStatus === 'connected') {
        return 'text-green-600 dark:text-green-400';
      }
      if (this.connectionStatus === 'checking') {
        return 'text-gray-600 dark:text-gray-400';
      }
      return 'text-red-600 dark:text-red-400';
    },
    statusText() {
      if (this.connectionStatus === 'connected') {
        return this.t('INBOX_MGMT.WHATSAPP_STATUS.STATUS.CONNECTED');
      }
      if (this.connectionStatus === 'checking') {
        return this.t('INBOX_MGMT.WHATSAPP_STATUS.STATUS.CHECKING');
      }
      return this.t('INBOX_MGMT.WHATSAPP_STATUS.STATUS.DISCONNECTED');
    },
    statusIcon() {
      if (this.connectionStatus === 'connected') {
        return 'check-circle';
      }
      if (this.connectionStatus === 'checking') {
        return 'refresh-cw';
      }
      return 'x-circle';
    },
    lastCheckedText() {
      if (!this.lastChecked) {
        return this.t('INBOX_MGMT.WHATSAPP_STATUS.NEVER_CHECKED');
      }
      const timeStr = this.lastChecked.toLocaleTimeString('id-ID');
      return `${this.t('INBOX_MGMT.WHATSAPP_STATUS.LAST_CHECKED')}: ${timeStr}`;
    },
    isConnected() {
      return this.connectionStatus === 'connected';
    },
    showDisconnectButton() {
      return this.isConnected && !this.showDisconnectConfirm && !this.showQRCard;
    },
    showReconnectButton() {
      return (
        !this.isConnected &&
        this.connectionStatus !== 'checking' &&
        !this.showQRCard
      );
    },
    qrCodeSrc() {
      if (!this.qrCodeData) return null;
      if (this.qrCodeType === 'url') {
        return this.qrCodeData;
      }
      return `data:image/png;base64,${this.qrCodeData}`;
    },
    qrCountdownText() {
      // Use $t for interpolation
      return this.$t('INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.QR_EXPIRES_IN', {
        seconds: this.qrCountdown,
      });
    },
  },
  async mounted() {
    await this.checkStatus(true);
    this.setupWebSocketSubscription();
    if (this.autoRefresh) {
      this.startAutoRefresh();
    }
  },
  beforeUnmount() {
    this.stopAutoRefresh();
    this.stopQRRefresh();
    this.stopQRCountdown();
    this.stopStatusPolling();
    this.disconnectWebSocket();
  },
  methods: {
    async checkStatus(realTime = false) {
      this.isLoading = true;
      try {
        const response = await WhatsAppUnofficialChannels.getConnectionStatus(
          this.inboxId,
          realTime
        );

        const status = response.data?.status || 'unknown';
        const connected = response.data?.connected || false;

        this.connectionStatus = connected ? 'connected' : status;
        this.lastChecked = new Date();

        // Hide QR card if connected
        if (connected) {
          this.hideQRCard(false); // Don't reset status, we already set it
        }

        this.$emit('statusChanged', {
          status: this.connectionStatus,
          connected,
          lastChecked: this.lastChecked,
        });
      } catch (error) {
        this.connectionStatus = 'disconnected';
        this.$emit('statusError', error);
      } finally {
        this.isLoading = false;
      }
    },

    showDisconnectConfirmation() {
      this.showDisconnectConfirm = true;
    },

    cancelDisconnect() {
      this.showDisconnectConfirm = false;
    },

    async confirmDisconnect() {
      this.showDisconnectConfirm = false;
      this.isDisconnecting = true;

      try {
        const response = await WhatsAppUnofficialChannels.disconnectSession(
          this.inboxId
        );

        if (response.data?.success) {
          this.connectionStatus = 'disconnected';
          const successMsg = this.t(
            'INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.DISCONNECT_SUCCESS'
          );
          useAlert(successMsg);
          this.$emit('sessionDisconnected', response.data);
        } else {
          const msg = response.data?.message || 'Failed to disconnect session';
          throw new Error(msg);
        }
      } catch (error) {
        const errorMsg = this.t(
          'INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.DISCONNECT_ERROR'
        );
        useAlert(errorMsg);
        this.$emit('disconnectError', error);
      } finally {
        this.isDisconnecting = false;
      }
    },

    async reconnectSession() {
      this.isReconnecting = true;

      try {
        const response = await WhatsAppUnofficialChannels.reconnectSession(
          this.inboxId
        );

        if (response.data?.success) {
          // If device was recreated and requires fresh QR scan
          if (response.data.requires_qr) {
            this.$emit('sessionReconnected', response.data);
            // Show QR card inline instead of redirecting
            await this.showQRCardAndFetch();
            return;
          }

          if (response.data.connected) {
            this.connectionStatus = 'connected';
            const successMsg = this.t(
              'INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.RECONNECT_SUCCESS'
            );
            useAlert(successMsg);
          } else {
            // Not connected yet, show QR card
            await this.showQRCardAndFetch();
            return;
          }
          this.$emit('sessionReconnected', response.data);
        } else {
          const msg = response.data?.message || 'Failed to reconnect session';
          throw new Error(msg);
        }
      } catch (error) {
        const errorMsg = this.t(
          'INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.RECONNECT_ERROR'
        );
        useAlert(errorMsg);
        this.$emit('reconnectError', error);
      } finally {
        this.isReconnecting = false;
      }
    },

    async showQRCardAndFetch() {
      this.showQRCard = true;
      await this.fetchQRCode();
      this.startQRCountdown();
      this.startStatusPolling();
    },

    async fetchQRCode() {
      this.isLoadingQR = true;
      try {
        const response = await WhatsAppUnofficialChannels.generateQR(
          this.inboxId
        );

        if (response.data?.success) {
          this.qrCodeData = response.data.qr_code;
          this.qrCodeType = response.data.qr_type || 'base64';
          this.qrDuration = response.data.qr_duration || 60;
          this.qrCountdown = this.qrDuration;
        } else if (response.data?.already_logged_in) {
          // Already connected, hide QR and update status
          this.connectionStatus = 'connected';
          this.hideQRCard(false); // Don't reset status, we just set it to connected
          const successMsg = this.t(
            'INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.RECONNECT_SUCCESS'
          );
          useAlert(successMsg);
        } else {
          throw new Error(response.data?.message || 'Failed to generate QR');
        }
      } catch (error) {
        // Don't show error for already logged in
        if (!error.message?.includes('already logged in')) {
          const errorMsg = this.t(
            'INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.QR_ERROR'
          );
          useAlert(errorMsg);
        }
      } finally {
        this.isLoadingQR = false;
      }
    },

    startQRCountdown() {
      this.stopQRCountdown();
      this.qrCountdown = this.qrDuration;

      this.qrCountdownTimer = setInterval(() => {
        if (!this.showQRCard || this.isConnected) {
          this.stopQRCountdown();
          return;
        }

        this.qrCountdown--;

        if (this.qrCountdown <= 0) {
          // Auto-refresh QR when countdown reaches 0
          this.fetchQRCode();
        }
      }, 1000);
    },

    stopQRCountdown() {
      if (this.qrCountdownTimer) {
        clearInterval(this.qrCountdownTimer);
        this.qrCountdownTimer = null;
      }
    },

    stopQRRefresh() {
      // Keep for backward compatibility, now handled by countdown
      this.stopQRCountdown();
    },

    hideQRCard(resetStatus = true) {
      this.showQRCard = false;
      this.qrCodeData = null;
      this.qrCodeType = null;
      this.stopQRCountdown();
      this.stopStatusPolling();
      // Reset status to disconnected when user cancels QR flow (not when connected via WebSocket)
      if (resetStatus && !this.isConnected) {
        this.connectionStatus = 'disconnected';
      }
    },

    startStatusPolling() {
      this.stopStatusPolling();

      // Poll status every 3 seconds while QR card is visible
      this.statusPollingTimer = setInterval(async () => {
        if (!this.showQRCard || this.isConnected) {
          this.stopStatusPolling();
          return;
        }

        try {
          const response = await WhatsAppUnofficialChannels.getConnectionStatus(
            this.inboxId,
            true // real_time = true for GOWA API check
          );

          if (response.data?.connected) {
            this.connectionStatus = 'connected';
            this.hideQRCard(false);
            useAlert(this.t('INBOX_MGMT.WHATSAPP_STATUS.ALERTS.CONNECTED'));
            this.stopStatusPolling();
          }
        } catch (error) {
          // Silently ignore polling errors
        }
      }, 3000);
    },

    stopStatusPolling() {
      if (this.statusPollingTimer) {
        clearInterval(this.statusPollingTimer);
        this.statusPollingTimer = null;
      }
    },

    setupWebSocketSubscription() {
      try {
        const pubsubToken = this.userPubsubToken;
        const cable = createConsumer();

        if (!pubsubToken || !this.currentUserId || !this.currentAccountId) {
          return;
        }

        this.subscription = cable.subscriptions.create(
          {
            channel: 'RoomChannel',
            pubsub_token: pubsubToken,
            user_id: this.currentUserId,
            account_id: this.currentAccountId,
          },
          {
            received: data => {
              if (data.event === 'whatsapp_status_changed') {
                const isForOurInbox =
                  data.inbox_id === parseInt(this.inboxId, 10) ||
                  (!data.inbox_id && data.phone_number);
                if (isForOurInbox) {
                  this.handleStatusUpdate(data);
                }
              }
            },
            connected: () => {},
            disconnected: () => {},
          }
        );
      } catch (error) {
        // WebSocket setup failed silently
      }
    },

    handleStatusUpdate(data) {
      const oldStatus = this.connectionStatus;

      if (
        data.type === 'session_ready' ||
        data.type === 'phone_validation_success' ||
        data.type === 'auto_reconnect'
      ) {
        this.connectionStatus = 'connected';
        this.hideQRCard(false); // Don't reset status, we just set it to connected

        if (oldStatus !== 'connected') {
          useAlert(this.t('INBOX_MGMT.WHATSAPP_STATUS.ALERTS.CONNECTED'));
        }
      } else if (data.type === 'session_mismatch') {
        this.connectionStatus = 'disconnected';
      } else if (data.type === 'session_failed') {
        this.connectionStatus = 'disconnected';
        this.hideQRCard(false); // Don't reset status, we just set it to disconnected
      } else if (data.type === 'auto_disconnect') {
        this.connectionStatus = 'disconnected';

        if (oldStatus === 'connected') {
          const noticeMsg = this.t(
            'INBOX_MGMT.WHATSAPP_STATUS.ALERTS.DISCONNECTED_NOTICE'
          );
          useAlert(noticeMsg);
        }
      } else if (data.status) {
        this.connectionStatus = data.connected ? 'connected' : 'disconnected';

        if (data.connected) {
          this.hideQRCard(false); // Don't reset status, we just set it to connected
          if (oldStatus !== 'connected') {
            useAlert(this.t('INBOX_MGMT.WHATSAPP_STATUS.ALERTS.CONNECTED'));
          }
        }
      }

      this.lastChecked = new Date();

      if (oldStatus !== this.connectionStatus) {
        this.$emit('statusChanged', {
          status: this.connectionStatus,
          connected: this.connectionStatus === 'connected',
          lastChecked: this.lastChecked,
        });
      }
    },

    disconnectWebSocket() {
      if (this.subscription) {
        this.subscription.unsubscribe();
        this.subscription = null;
      }
    },

    startAutoRefresh() {
      this.refreshTimer = setInterval(() => {
        this.checkStatus(true);
      }, this.refreshInterval);
    },

    stopAutoRefresh() {
      if (this.refreshTimer) {
        clearInterval(this.refreshTimer);
        this.refreshTimer = null;
      }
    },

    async forceRefresh() {
      await this.checkStatus(true);
    },
  },
};
</script>

<template>
  <div
    class="whatsapp-status-widget p-4 border rounded-lg bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700"
  >
    <!-- Status Header -->
    <div class="flex items-center justify-between mb-3">
      <div class="flex items-center space-x-2">
        <svg
          class="w-5 h-5"
          :class="statusColor"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            v-if="statusIcon === 'check-circle'"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
          <path
            v-else-if="statusIcon === 'x-circle'"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
          <path
            v-else-if="statusIcon === 'clock'"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
          />
          <path
            v-else-if="statusIcon === 'refresh-cw'"
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0V9a8 8 0 1115.356 2M15 15v5h-.582M4.582 15A8.001 8.001 0 0019.418 15M19.418 15V15a8 8 0 11-15.356-2"
          />
          <path
            v-else
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <span class="font-medium text-gray-900 dark:text-slate-100">
          {{ t('INBOX_MGMT.WHATSAPP_STATUS.TITLE') }}
        </span>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center space-x-2">
        <!-- Disconnect Button - show when connected -->
        <button
          v-if="showDisconnectButton"
          :disabled="isDisconnecting"
          class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-white bg-red-600 border border-red-600 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="showDisconnectConfirmation"
        >
          <span v-if="isDisconnecting">
            {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.LOADING') }}
          </span>
          <span v-else>
            {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.DISCONNECT') }}
          </span>
        </button>

        <!-- Reconnect Button - show when disconnected -->
        <button
          v-if="showReconnectButton"
          :disabled="isReconnecting"
          class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="reconnectSession"
        >
          <span v-if="isReconnecting">
            {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.LOADING') }}
          </span>
          <span v-else>
            {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.RECONNECT') }}
          </span>
        </button>

        <!-- Refresh Button -->
        <button
          v-if="!showQRCard"
          :disabled="isLoading"
          :title="t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.REFRESH')"
          class="p-1.5 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 disabled:opacity-50 border border-gray-300 dark:border-gray-600 rounded-md"
          @click="forceRefresh"
        >
          <svg
            class="w-4 h-4"
            :class="{ 'animate-spin': isLoading }"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0V9a8 8 0 1115.356 2M15 15v5h-.582M4.582 15A8.001 8.001 0 0019.418 15M19.418 15V15a8 8 0 11-15.356-2"
            />
          </svg>
        </button>
      </div>
    </div>

    <!-- Status Info -->
    <div class="flex items-center justify-between">
      <div>
        <div class="flex items-center space-x-2">
          <!-- Connection Status Circle -->
          <div
            class="w-3 h-3 rounded-full border border-white shadow-sm"
            :class="{
              'bg-green-500': isConnected,
              'bg-red-500': connectionStatus === 'disconnected',
              'bg-gray-500': connectionStatus === 'checking',
            }"
          />
          <span :class="statusColor" class="font-medium">{{ statusText }}</span>
          <div
            v-if="isLoading || isDisconnecting || isReconnecting"
            class="w-3 h-3 border-2 border-green-500 border-t-transparent rounded-full animate-spin"
          />
        </div>
        <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
          {{ lastCheckedText }}
        </div>
      </div>
    </div>

    <!-- Disconnect Confirmation Card -->
    <div
      v-if="showDisconnectConfirm"
      class="mt-3 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg"
    >
      <div class="flex items-start space-x-3">
        <div class="flex-shrink-0">
          <svg
            class="w-5 h-5 text-red-600 dark:text-red-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
        </div>
        <div class="flex-1">
          <p class="text-sm font-medium text-red-800 dark:text-red-200">
            {{ t('INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.DISCONNECT_CONFIRM') }}
          </p>
          <div class="mt-3 flex space-x-3">
            <button
              :disabled="isDisconnecting"
              class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-white bg-red-600 border border-red-600 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="confirmDisconnect"
            >
              <span v-if="isDisconnecting">
                {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.LOADING') }}
              </span>
              <span v-else>
                {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.DISCONNECT') }}
              </span>
            </button>
            <button
              :disabled="isDisconnecting"
              class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="cancelDisconnect"
            >
              {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.CANCEL') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- QR Code Card -->
    <div
      v-else-if="showQRCard"
      class="mt-3 p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg"
    >
      <div class="flex flex-col items-center">
        <div class="flex items-center justify-between w-full mb-3">
          <p class="text-sm font-medium text-blue-800 dark:text-blue-200">
            {{ t('INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.QR_SCAN_INSTRUCTION') }}
          </p>
          <button
            class="p-1 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
            @click="hideQRCard"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <!-- QR Code Display -->
        <div
          class="w-64 h-64 bg-white rounded-lg flex items-center justify-center border border-gray-200"
        >
          <div
            v-if="isLoadingQR"
            class="flex flex-col items-center space-y-2"
          >
            <div
              class="w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full animate-spin"
            />
            <span class="text-sm text-gray-500">
              {{ t('INBOX_MGMT.WHATSAPP_STATUS.BUTTONS.LOADING') }}
            </span>
          </div>
          <img
            v-else-if="qrCodeSrc"
            :src="qrCodeSrc"
            alt="WhatsApp QR Code"
            class="w-full h-full object-contain p-2"
          />
          <div
            v-else
            class="flex flex-col items-center space-y-2 text-gray-400"
          >
            <svg
              class="w-12 h-12"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"
              />
            </svg>
            <span class="text-sm">
              {{ t('INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.QR_ERROR') }}
            </span>
          </div>
        </div>

        <!-- QR Countdown Timer -->
        <div
          v-if="qrCodeSrc && !isLoadingQR"
          class="mt-3 text-sm text-gray-500 dark:text-gray-400"
        >
          {{ qrCountdownText }}
        </div>
      </div>
    </div>

    <!-- Connection Guide -->
    <div
      v-else-if="connectionStatus === 'disconnected'"
      class="mt-3 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded"
    >
      <p class="text-sm text-red-700 dark:text-red-300">
        {{ t('INBOX_MGMT.WHATSAPP_STATUS.MESSAGES.DISCONNECTED_GUIDE') }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.animate-spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
