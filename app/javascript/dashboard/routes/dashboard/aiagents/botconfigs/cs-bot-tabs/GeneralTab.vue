<!-- eslint-disable no-console -->
<script setup>
import { ref, reactive, onMounted, computed, watch, inject } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

// Google Sheets Auth Flow for Tickets
import googleSheetsExportAPI from '../../../../../api/googleSheetsExport';
// ✅ Add this line to fix the "aiAgents is not defined" error
import aiAgents from '../../../../../api/aiAgents';
import idleConfigsAPI from '../../../../../api/idleConfigs';
import NotificationSettings from '../notification-settings/NotificationSettings.vue';

// ✅ Inject emit function from parent CSBotView
const emitUpdate = inject('emitUpdate', () => {});

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
  config: {
    type: Object,
    required: true,
  },
  googleSheetsAuth: {
    type: Object,
    required: true,
  },
});

// temperature bot
const creativityLevel = ref(0.3);
const creativityOptions = computed(() => [
  { label: t('AGENT_MGMT.CREATIVITY.DETERMINISTIC'), value: 0 },
  { label: t('AGENT_MGMT.CREATIVITY.CONSERVATIVE'), value: 0.1 },
  { label: t('AGENT_MGMT.CREATIVITY.NATURAL'), value: 0.3 },
  { label: t('AGENT_MGMT.CREATIVITY.INNOVATIVE'), value: 0.5 },
  { label: t('AGENT_MGMT.CREATIVITY.VISIONARY'), value: 0.7 },
]);

// idle time
const idleConfig = reactive({
  duration: window.chatwootConfig?.idleConversationDuration || 30,        
});

console.log('=== googleSheetsAuth in GeneralTab.vue', props.googleSheetsAuth);
const { t } = useI18n();
// Watch for props.data and extract ticket system settings
watch(
  () => props.data,
  newData => {
    if (!newData?.display_flow_data) return;

    const flowData = newData.display_flow_data;
    const agentIndex = flowData.enabled_agents.indexOf('customer_service');

    // If customer_service agent isn't in the flow, skip
    if (agentIndex === -1) {
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketSystemActive = false;
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketCreateWhen = 'always';
      return;
    }

    const agentData = flowData.agents_config?.[agentIndex];
    const config = agentData?.configurations;

    // Map backend value to UI
    const ticketSystem = config?.ticket_system;
    if (ticketSystem === 'always') {
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketSystemActive = true;
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketCreateWhen = 'always';
    } else if (ticketSystem === 'conditional') {
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketSystemActive = true;
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketCreateWhen = 'bot_fail';
    } else {
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketSystemActive = false;
      // Optionally keep last value or reset
      // eslint-disable-next-line vue/no-mutating-props
      props.config.ticketCreateWhen = 'always';
    }

    if (agentData && agentData.temperature !== undefined) {
      creativityLevel.value = agentData.temperature;
    }

    // Load idle config from API
    loadIdleConfig();
  },
  { immediate: true }  // ← Runs as soon as component mounts
);

const isSaving = ref(false);

// Local notification state (separate from parent's Google Sheets auth)
const notification = ref(null);

// Helper function to get agent ID by type
function getAgentIdByType(type) {
  const flowData = props.data?.display_flow_data;
  if (!flowData?.agents_config) return null;
  
  const agent = flowData.agents_config.find(config => config.type === type);
  return agent?.agent_id || null;
}

const agentId = computed(() => {
  return getAgentIdByType('customer_service');
});

const csCategories = computed(() => {
  const flowData = props.data?.flow_data;
  if (!flowData?.agents_config) return [];
  const agentIndex = flowData.enabled_agents?.indexOf('customer_service');
  if (agentIndex === -1 || agentIndex === undefined) return [];
  const categoryConfig = flowData.agents_config[agentIndex]?.configurations?.category;
  return Array.isArray(categoryConfig) ? categoryConfig : [];
});

const csPriorities = computed(() => {
  const flowData = props.data?.flow_data;
  if (!flowData?.agents_config) return [];
  const agentIndex = flowData.enabled_agents?.indexOf('customer_service');
  if (agentIndex === -1 || agentIndex === undefined) return [];
  const priorityConfig = flowData.agents_config[agentIndex]?.configurations?.priority;
  return Array.isArray(priorityConfig) ? priorityConfig : [];
});

const csVariableConfig = computed(() => ({
  helpKey: 'AGENT_MGMT.CSBOT.NOTIFICATION.TEMPLATE_HELP',
  variables: [
    {
      labelKey: 'AGENT_MGMT.NOTIFICATION.VAR_CONTENT_SUMMARY',
      value: '{{content_summary}}',
      example: `No. Tiket: TK-001/01/2026\nNama Pelanggan: Budi Santoso\nKontak: 62812345678901\nChannel: WhatsApp\nJudul: Masalah pembayaran\nKategori: Billing\nPrioritas: High\nStatus: Open\nDeskripsi: Pelanggan mengalami masalah saat melakukan pembayaran`,
    },
  ],
}));

// Load idle config from API
async function loadIdleConfig() {
  if (!props.data?.id) return;
  try {
    const response = await idleConfigsAPI.getConfig(props.data.id);
    if (response.data) {
      idleConfig.duration = response.data.duration || 30;
    }
  } catch (error) {
    console.error('Failed to load idle config:', error);
  }
}

// Load idle config when component mounts
onMounted(() => {
  loadIdleConfig();
});

// Computed properties based on parent's Google Sheets auth state
const ticketStep = computed(() => props.googleSheetsAuth.step);
const ticketLoading = computed(() => props.googleSheetsAuth.loading);
const ticketAccount = computed(() => props.googleSheetsAuth.account);
const ticketSheets = computed(() => ({
  output: props.googleSheetsAuth.spreadsheetUrls.customer_service.output || ''
}));
const ticketAuthError = computed(() => props.googleSheetsAuth.error);

watch(ticketAuthError, (newError) => {
  if (newError) {
    notification.value = { message: t('AGENT_MGMT.AUTH_ERROR'), type: 'error' };
  }
  else {
    notification.value = null;
  }
}, { immediate: true });

const showRegenerateModal = ref(false);
const isRegenerating = ref(false);

function openRegenerateModal() {
  showRegenerateModal.value = true;
}

async function regenerateSheetsInput() {
  showRegenerateModal.value = false;

  try {
    isRegenerating.value = true;
    const flowData = props.data.display_flow_data;

    const payload = {
      account_id: parseInt(flowData.account_id, 10),
      agent_id: agentId.value,
      type: 'customer_service',
    };

    // Memanggil API wrapper yang baru kita perbaiki
    const response = await googleSheetsExportAPI.regenerateSpreadsheet(payload);

    if (response.data && response.data.input_spreadsheet_url) {
        props.googleSheetsAuth.spreadsheetUrls.customer_service.input = response.data.input_spreadsheet_url;

        if (response.data.output_spreadsheet_url) {
            props.googleSheetsAuth.spreadsheetUrls.customer_service.output = response.data.output_spreadsheet_url;
        }

        showNotification('Input spreadsheet berhasil dibuat ulang!', 'success');
    } else {
        throw new Error("Respon server tidak memiliki URL spreadsheet baru.");
    }

  } catch (error) {
    console.error('Failed to regenerate sheet:', error);
    showNotification('Gagal membuat ulang spreadsheet. Silakan coba lagi.', 'error');
  } finally {
    isRegenerating.value = false;
  }
}


function retryAuthentication() {
  connectGoogle();
  ticketAuthError.value = null;
}

function showNotification(message, type = 'success') {
  notification.value = { message, type }
  setTimeout(() => {
    notification.value = null
  }, 3000)
}

async function connectGoogle() {
  try {
    // Use parent's loading state
    props.googleSheetsAuth.loading = true;
    const response = await googleSheetsExportAPI.getAuthorizationUrl();
    if (response.data.authorization_url) {
      showNotification('Opening Google authentication in a new tab...', 'info');
      window.location.href = response.data.authorization_url;
      // window.open(response.data.authorization_url, '_blank', 'noopener,noreferrer')
    } else {
      showNotification(
        'Failed to get authorization URL. Please check backend logs.',
        'error'
      );
    }
  } catch (error) {
    console.error('Google auth error:', error)
  } finally {
    props.googleSheetsAuth.loading = false;
  }
}

function disconnectGoogle() {
  // TODO: Implement disconnect logic
  console.log('Disconnect Google account clicked');
  googleSheetsExportAPI.disconnectAccount()
    .then(() => {
      // Clear parent's auth state
      props.googleSheetsAuth.account = null;
      props.googleSheetsAuth.step = 'auth';
      props.googleSheetsAuth.spreadsheetUrls.customer_service.output = '';
      props.googleSheetsAuth.error = null;
      showNotification('Google account disconnected successfully.', 'success');
    })
    .catch(error => {
      console.error('Failed to disconnect Google account:', error);
      showNotification(
        'Failed to disconnect Google account. Please try again.',
        'error'
      );
    });
}

async function createTicketSheet() {
  try {
    props.googleSheetsAuth.loading = true;
    console.log(JSON.stringify(props.data));
    
    const flowData = props.data.display_flow_data;
    const payload = {
      account_id: parseInt(flowData.account_id, 10),
      agent_id: agentId.value,
      type: 'tickets',
    };
    
    const response = await googleSheetsExportAPI.createSpreadsheet(payload);
    
    // Update parent's auth state
    props.googleSheetsAuth.spreadsheetUrls.customer_service.output = response.data.spreadsheet_url;
    props.googleSheetsAuth.step = 'sheetConfig';
    
    showNotification('Ticket output sheet created successfully!', 'success')
  } catch (error) {
    console.error('Failed to create ticket sheet:', error)
    showNotification(
      'Failed to create ticket sheet. Please try again.',
      'error'
    );
  } finally {
    props.googleSheetsAuth.loading = false;
  }
}

async function save() {
  if (isSaving.value) return; // Prevent multiple calls
  let ticketSystem = 'off';
  if (props.config.ticketSystemActive) {
    if (props.config.ticketCreateWhen === 'always') {
      ticketSystem = 'always';
    } else if (props.config.ticketCreateWhen === 'bot_fail') {
      ticketSystem = 'conditional';
    }
  }
  try {
    isSaving.value = true;
    // Use translated flow_data, not display_flow_data (Indonesian)
    let flowData = JSON.parse(JSON.stringify(props.data.flow_data)); 
    let displayFlowData = JSON.parse(JSON.stringify(props.data.display_flow_data)); 
    // console.log(flowData)
    const agent_index = flowData.enabled_agents.indexOf('customer_service');
    flowData.agents_config[agent_index].configurations.ticket_system =
      ticketSystem;
    flowData.agents_config[agent_index].temperature = creativityLevel.value;
    
    displayFlowData.agents_config[agent_index].configurations.ticket_system = ticketSystem;
    displayFlowData.agents_config[agent_index].temperature = creativityLevel.value;

    const payload = {
      flow_data: flowData,
      display_flow_data: displayFlowData,
    };
    // ✅ Properly await the API call
    await Promise.all([
      aiAgents.updateAgent(props.data.id, payload),
      idleConfigsAPI.updateConfig(props.data.id, {
        duration: idleConfig.duration
      })
    ]);

    // ✅ Trigger parent data refresh
    emitUpdate();

    // ✅ Show success console.log after success
    useAlert(t('AGENT_MGMT.CSBOT.TICKET.SAVE_SUCCESS'));
  } catch (e) {
    console.error('Save error:', e);
    useAlert(t('AGENT_MGMT.CSBOT.TICKET.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
}

console.log("ticketAuthError inside GeneralTab.vue:", ticketAuthError)
console.log("is ticketAuthError value inside GeneralTab.vue:", !ticketAuthError)
console.log("is ticketAuthError value inside GeneralTab.vue:", ticketAuthError.value)
console.log("is ticketAuthError value inside GeneralTab.vue:", !ticketAuthError.value)
</script>

<template>
  <div class="w-full">
    <!-- Notification -->
    <div v-if="notification"
      :class="['fixed top-4 right-4 z-50 px-6 py-4 rounded-lg shadow-lg transition-all duration-300',
        notification.type === 'success' ? 'bg-green-500 text-white' :
        notification.type === 'error' ? 'bg-red-500 text-white' :
        notification.type === 'info' ? 'bg-blue-500 text-white' :
        'bg-gray-500 text-white']">
      <div class="flex items-center space-x-2">
        <span>{{ notification.message }}</span>
      </div>
    </div>
    
    <div class="flex flex-row gap-4">
    <div class="flex-1 min-w-0 flex flex-col justify-stretch gap-6">
      <div class="space-y-4">

        
        <!-- Sistem Tiket Toggle -->
        <div class="mb-6">
          <label class="block font-medium mb-2">{{ $t('AGENT_MGMT.CSBOT.TICKET.SYSTEM_TITLE') }}</label>
          <p class="text-sm text-gray-500 mb-3">{{ $t('AGENT_MGMT.CSBOT.TICKET.SYSTEM_DESC') }}</p>
          <label class="inline-flex items-center cursor-pointer">
            <input type="checkbox" v-model="config.ticketSystemActive" class="sr-only peer">
            <div
              class="border solid w-11 h-6 bg-gray-200 rounded-full peer peer-checked:bg-green-500 relative after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full">
            </div>
            <span class="ml-3 text-sm text-slate-700 dark:text-slate-300">
              {{ config.ticketSystemActive ? $t('AGENT_MGMT.CSBOT.TICKET.ACTIVE') : $t('AGENT_MGMT.CSBOT.TICKET.INACTIVE') }}
            </span>
          </label>
        </div>

        <!-- Kapan tiket dibuat -->
        <div v-if="config.ticketSystemActive" class="mb-6">
          <label class="block font-medium mb-2">{{ $t('AGENT_MGMT.CSBOT.TICKET.CREATE_WHEN') }}</label>
          <p class="text-sm text-gray-500 mb-3">{{ $t('AGENT_MGMT.CSBOT.TICKET.CREATE_WHEN_DESC') }}</p>
          <select 
            v-model="config.ticketCreateWhen" 
            class="w-full mb-0 p-2 text-sm  border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed"
          >
            <option value="always">{{ $t('AGENT_MGMT.CSBOT.TICKET.CREATE_ALWAYS') }}</option>
            <option value="bot_fail">{{ $t('AGENT_MGMT.CSBOT.TICKET.CREATE_ON_FAIL') }}</option>
          </select>
        </div>

        <!-- Google Sheets Integration -->
        <div v-if="config.ticketSystemActive" class="mb-6">
          <h4 class="text-md font-medium text-slate-900 dark:text-slate-25 mb-3">{{ $t('AGENT_MGMT.CSBOT.COMMON.GOOGLE_SHEETS_TITLE') }}</h4>
          <p class="text-sm text-gray-500 mb-4">{{ $t('AGENT_MGMT.CSBOT.COMMON.CONNECT_SHEETS_DESC') }}</p>

          <!-- Loading State -->
          <div v-if="ticketLoading" class="flex flex-col items-center justify-center py-16 gap-4">
            <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-green-600"></div>
            <p class="text-sm text-slate-500 dark:text-slate-400">{{ $t('AGENT_MGMT.COMMON.LOADING') }}</p>
          </div>
          
          <!-- Google Sheets Auth Flow -->
          <div v-else-if="ticketStep === 'auth'" class="mb-6">
            <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-6 border border-blue-200 dark:border-blue-800">
              <div class="flex items-center gap-3 mb-3">
                <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
                    <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z"/>
                    </svg>
                  </div>
                <div>
                  <h5 class="text-sm font-medium text-blue-900 dark:text-blue-100">{{ $t('AGENT_MGMT.CSBOT.COMMON.GOOGLE_SHEETS_AUTH_TITLE') }}</h5>
                  <p class="text-xs text-blue-700 dark:text-blue-300">{{ $t('AGENT_MGMT.CSBOT.COMMON.GOOGLE_SHEETS_AUTH_DESC') }}</p>
                </div>
              </div>
              
              <button
                @click="connectGoogle"
                class="inline-flex items-center space-x-3 bg-green-600 hover:bg-green-700 dark:bg-green-400 dark:hover:bg-green-500 text-white px-6 py-3 rounded-lg font-medium transition-colors"
                :disabled="ticketLoading"
              >
                <svg v-if="ticketLoading" class="animate-spin -ml-1 mr-2 h-4 w-4" fill="none" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25"/>
                  <path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" class="opacity-75"/>
                </svg>
                <svg v-else class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                </svg>
                <span>{{ ticketLoading ? 'Connecting...' : 'Connect Google Account' }}</span>
              </button>
            </div>
          </div>

          <!-- Connected State -->
          <!-- <div v-else-if="ticketStep === 'autsh'" class="mb-6">
            <div class="dark:from-green-900/20 dark:to-emerald-900/20 rounded-lg p-6 border border-gray-200 dark:border-gray-700">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class="w-8 h-8 bg-green-100 dark:bg-green-900/50 rounded-lg flex items-center justify-center">
                    <svg class="w-4 h-4 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                  <div>
                    <h5 class="text-sm font-medium text-green-900 dark:text-green-100">Google Account Connected</h5>
                    <p class="text-xs text-green-700 dark:text-green-300">{{ ticketAccount?.email || 'Connected successfully' }}</p>
                  </div>
                </div>
                
                <div class="flex gap-2 align-center content-center">
                  <template v-if="true">
                    <button
                      class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                      @click="createTicketSheet"
                      :disabled="ticketLoading"
                    >
                      <span v-if="ticketLoading">{{ $t('AGENT_MGMT.BOOKING_BOT.CREATE_SHEETS_LOADING') }}</span>
                      <span v-else>{{ $t('AGENT_MGMT.BOOKING_BOT.CREATE_SHEETS_BTN') }}</span>
                    </button>
                  </template>
                  <template v-else>
                    <div class="text-red-600 text-sm flex items-center gap-2 content-center">
                      <button
                        class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                        @click="retryAuthentication"
                        :disabled="ticketLoading"
                      >
                        <span v-if="ticketLoading">{{ $t('AGENT_MGMT.BOOKING_BOT.RETRY_AUTH_LOADING') }}</span>
                        <span v-else>{{ $t('AGENT_MGMT.BOOKING_BOT.RETRY_AUTH_BTN') }}</span>
                      </button>
                    </div>
                  </template>
                  <div class="gap-2 items-center">

                    <button
                    @click="disconnectGoogle"
                    class="inline-flex items-center space-x-2 border-2 border-red-600 hover:border-red-700 dark:border-red-400 dark:hover:border-red-500 text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-red-50 dark:hover:bg-red-900/20"
                    :disabled="ticketLoading"
                    >
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-ban-icon lucide-ban"><path d="M4.929 4.929 19.07 19.071"/><circle cx="12" cy="12" r="10"/></svg>
                    <span>{{ $t('AGENT_MGMT.BOOKING_BOT.DISC_BTN') }}</span>
                  </button>
                </div>
                </div>
              </div>
            </div>
          </div> -->

            <!-- Connected State -->
              <div v-else-if="ticketStep === 'connected'" class="mb-6">
                <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-6 border border-blue-200 dark:border-blue-800">
                  <div class="flex flex-col gap-4">
                  <!-- Top section: Account info -->
                  <div class="flex items-center">
                    <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
                    <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                    </div>
                    <div>
                    <h5 class="text-sm font-medium text-blue-900 dark:text-blue-100">Google Account Connected</h5>
                    <p class="text-xs text-blue-700 dark:text-blue-300">{{ ticketAccount?.email || 'Connected successfully' }}</p>
                    </div>
                  </div>

                  <!-- Separator line -->
                  <div class="border-t border-blue-200 dark:border-blue-700"></div>

                  <!-- Bottom section: Action buttons -->
                  <div class="flex items-center justify-end gap-2">
                    <template v-if="!ticketAuthError || !ticketAuthError.value">
                    <button
                      class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                      @click="createTicketSheet"
                      :disabled="ticketLoading"
                    >
                      <span v-if="ticketLoading">{{ $t('AGENT_MGMT.BOOKING_BOT.CREATE_SHEETS_LOADING') }}</span>
                      <span v-else>{{ $t('AGENT_MGMT.BOOKING_BOT.CREATE_SHEETS_BTN') }}</span>
                    </button>
                    </template>
                    <template v-else>
                    <button
                      class="inline-flex items-center space-x-2 border-2 border-green-600 hover:border-green-700 dark:border-green-600 text-green-600 hover:text-green-700 dark:text-green-400 dark:hover:text-green-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-green-50 dark:hover:bg-green-900/20"
                      @click="retryAuthentication"
                      :disabled="ticketLoading"
                    >
                      <span v-if="ticketLoading">{{ $t('AGENT_MGMT.BOOKING_BOT.RETRY_AUTH_LOADING') }}</span>
                      <span v-else>{{ $t('AGENT_MGMT.BOOKING_BOT.RETRY_AUTH_BTN') }}</span>
                    </button>
                    </template>

                    <button
                    @click="disconnectGoogle"
                    class="inline-flex items-center space-x-2 border-2 border-red-600 hover:border-red-700 dark:border-red-400 dark:hover:border-red-500 text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-red-50 dark:hover:bg-red-900/20"
                    :disabled="ticketLoading"
                    >
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-ban-icon lucide-ban"><path d="M4.929 4.929 19.07 19.071"/><circle cx="12" cy="12" r="10"/></svg>
                    <span>{{ $t('AGENT_MGMT.BOOKING_BOT.DISC_BTN') }}</span>
                    </button>
                  </div>
                  </div>
                </div>
                </div>

            <!-- Sheet Configuration -->
            <div v-else-if="ticketStep === 'sheetConfig'" class="mb-6">
            <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-6 border border-blue-200 dark:border-blue-800">
              <div class="flex flex-col gap-4">
              <!-- Top section: Account info and open sheet button -->
              <div class="flex items-center justify-between">
                <div class="flex items-center">
                <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
                  <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z"/>
                  </svg>
                </div>
                <div>
                  <h5 class="text-sm font-medium text-slate-900 dark:text-slate-100">Google Account Connected</h5>
                  <p class="text-xs text-slate-600 dark:text-slate-300">{{ ticketAccount?.email || 'Connected successfully' }}</p>
                </div>
                </div>
                
                <div v-if="ticketAuthError === null || !ticketAuthError.value">
                <a 
                  :href="ticketSheets.output" 
                  target="_blank" 
                  class="inline-flex items-center space-x-2 border-2 border-green-600 hover:border-green-700 dark:border-green-600 text-green-600 hover:text-green-700 dark:text-green-400 dark:hover:text-green-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-green-50 dark:hover:bg-green-900/20"
                >
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                  {{ $t('AGENT_MGMT.BOOKING_BOT.OPEN_SHEET_BTN') }}
                </a>
                </div>
              </div>

              <!-- Separator line -->
              <div class="border-t border-blue-200 dark:border-blue-700"></div>

              <!-- Bottom section: Action buttons -->
              <div class="flex items-center justify-end gap-2">
                <button
                @click="openRegenerateModal"
                class="btn-retryauth inline-flex items-center space-x-2 px-4 py-2 rounded-md font-medium transition-colors bg-transparent"
                :disabled="isRegenerating"
                >
                  <span v-if="isRegenerating">{{ $t('AGENT_MGMT.BOOKING_BOT.RETRY_AUTH_LOADING') }}</span>
                  <span v-else>{{ t('AGENT_MGMT.BOOKING_BOT.RETRY_AUTH_BTN') }}</span>
                </button>
                
                <button
                @click="disconnectGoogle"
                class="inline-flex items-center space-x-2 border-2 border-red-600 hover:border-red-700 dark:border-red-400 dark:hover:border-red-500 text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-red-50 dark:hover:bg-red-900/20"
                :disabled="ticketLoading"
                >
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-ban"><path d="M4.929 4.929 19.07 19.071"/><circle cx="12" cy="12" r="10"/></svg>
                <span>{{ $t('AGENT_MGMT.BOOKING_BOT.DISC_BTN') }}</span>
                </button>
              </div>
              </div>
            </div>
            </div>
        </div>

        <!-- Notification Settings (only when ticket system is active) -->
        <NotificationSettings
          v-if="config.ticketSystemActive && data?.id"
          :ai-agent-id="data.id"
          :categories="csCategories"
          :priorities="csPriorities"
          title-key="AGENT_MGMT.CSBOT.NOTIFICATION.TITLE"
          desc-key="AGENT_MGMT.CSBOT.NOTIFICATION.DESC"
          :variable-config="csVariableConfig"
          is-customer-service-bot
        />

        <div class="border border-gray-200 dark:border-gray-700 rounded-lg mb-6 bg-white dark:bg-transparent">
          <div class="flex items-start justify-between p-6">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5 text-green-600 dark:text-green-400">
                  <path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/>
                </svg>
              </div>
              <div>
                <h3 class="font-medium text-slate-900 dark:text-slate-25">Tingkat Kreativitas</h3>
                <p class="text-sm text-gray-500 mt-1">Tentukan seberapa kreatif bot dalam merespons percakapan</p>
              </div>
            </div>
          </div>
          
          <div class="border-t border-gray-200 dark:border-gray-700 p-6">
            <label class="block text-sm font-medium mb-1 text-slate-900 dark:text-slate-25">Skala Kreativitas</label>
            <div class="relative">
              <select 
                v-model="creativityLevel" 
                class="w-full mb-0 p-2 text-sm border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed"
              >
                <option class="bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100" v-for="opt in creativityOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
              <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-500 dark:text-gray-400">
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </div>
            </div>
          </div>
        </div>
        <div class="border border-gray-200 dark:border-gray-700 rounded-lg mb-6 bg-white dark:bg-transparent">
          <div class="flex items-center p-6">
            <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5 text-green-600 dark:text-green-400">
                <circle cx="12" cy="12" r="10"/>
                <polyline points="12 6 12 12 16 14"/>
              </svg>
            </div>
            <div>
              <h3 class="font-medium text-slate-900 dark:text-slate-25">{{ $t('AGENT_MGMT.EOBOT.IDLE_STATE') }}</h3>
              <p class="text-sm text-gray-500 mt-1">{{ $t('AGENT_MGMT.EOBOT.IDLE_STATE_DESC') }}</p>
            </div>
          </div>
          
          <div class="border-t border-gray-200 dark:border-gray-700 p-6">
            <div>
              <label class="block text-sm font-medium mb-2 text-slate-900 dark:text-slate-25">
                {{ $t('AGENT_MGMT.EOBOT.IDLE_TIME') }}
              </label>
              <select
                v-model="idleConfig.duration"
                class="text-center w-24 mb-0 p-2 text-sm border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed dark:bg-slate-900 dark:border-slate-700 dark:text-white"
              >
                <option :value="5">{{ $t('AGENT_MGMT.EOBOT.IDLE_TIME_OPTION_5_MIN') }}</option>
                <option :value="10">{{ $t('AGENT_MGMT.EOBOT.IDLE_TIME_OPTION_10_MIN') }}</option>
                <option :value="30">{{ $t('AGENT_MGMT.EOBOT.IDLE_TIME_OPTION_30_MIN') }}</option>
                <option :value="60">{{ $t('AGENT_MGMT.EOBOT.IDLE_TIME_OPTION_1_HOUR') }}</option>
                <option :value="120">{{ $t('AGENT_MGMT.EOBOT.IDLE_TIME_OPTION_2_HOURS') }}</option>
                <option :value="1440">{{ $t('AGENT_MGMT.EOBOT.IDLE_TIME_OPTION_24_HOURS') }}</option>
              </select>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="w-[240px] flex flex-col gap-3">
      <div class="sticky top-4 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm">
        <div class="flex items-center gap-3 mb-4">
          <div class="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
            </svg>
          </div>
          <div>
            <h3 class="font-semibold text-slate-700 dark:text-slate-300">{{ $t('AGENT_MGMT.BOOKING_BOT.CONFIGURE') }}</h3>
            <p class="text-sm text-slate-500 dark:text-slate-400">{{ $t('AGENT_MGMT.BOOKING_BOT.CONFIGURE_DESC') }}</p>
          </div>
        </div>
        
        <Button
          class="w-full"
          :is-loading="isSaving"
          :disabled="isSaving"
          @click="() => save()"
        >
          <span class="flex items-center gap-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
            </svg>
            {{ $t('AGENT_MGMT.CSBOT.TICKET.SAVE_BUTTON') }}
          </span>
        </Button>

      </div>
      </div>
    </div>
  </div>
  <div v-if="showRegenerateModal" class="fixed inset-0 z-[60] flex items-center justify-center p-4 sm:p-6" role="dialog">
    <div class="fixed inset-0 bg-slate-900/50 transition-opacity" @click="showRegenerateModal = false"></div>

    <div class="relative w-full max-w-md transform overflow-hidden rounded-xl bg-white dark:bg-slate-800 p-6 text-left shadow-xl transition-all border border-slate-200 dark:border-slate-700">
      
      <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-orange-100 dark:bg-orange-900/20 mb-4">
        <svg class="h-6 w-6 text-orange-600 dark:text-orange-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
        </svg>
      </div>

      <div class="text-center">
        <h3 class="text-lg font-semibold leading-6 text-slate-900 dark:text-white" id="modal-title">
          {{ $t('AGENT_MGMT.EOBOT.REGENERATE_SHEETS') }}
        </h3>
        <div class="mt-2">
          <p class="text-sm text-slate-500 dark:text-slate-400">
            {{ $t('AGENT_MGMT.EOBOT.REGENERATE_SHEETS_DESC') }}
          </p>
        </div>
      </div>

      <div class="mt-6 flex flex-col sm:flex-row-reverse gap-3">
        <button 
          type="button" 
          class="inline-flex w-full justify-center bg-green-600 text-white rounded-md hover:bg-green-700 px-3 py-2 text-sm font-semibold shadow-sm sm:w-auto transition-colors"
          @click="regenerateSheetsInput"
        >
          {{ $t('AGENT_MGMT.EOBOT.REGENERATE_SHEETS_BTN') }}
        </button>
        <button 
          type="button" 
          class="inline-flex w-full justify-center rounded-lg bg-white dark:bg-transparent px-3 py-2 text-sm font-semibold text-slate-900 dark:text-slate-300 shadow-sm ring-1 ring-inset ring-slate-300 dark:ring-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 sm:w-auto transition-colors"
          @click="showRegenerateModal = false"
        >
          {{ $t('AGENT_MGMT.EOBOT.REGENERATE_SHEETS_CANCEL') }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.btn-retryauth {
    border: 2px solid #B0B1BC !important;
    color: #B0B1BC !important;
}

.btn-retryauth:hover {       
    background-color: rgba(176, 177, 188, 0.1) !important; 
}

.dark .btn-retryauth:hover {
    background-color: rgba(176, 177, 188, 0.1) !important; 
}
</style>