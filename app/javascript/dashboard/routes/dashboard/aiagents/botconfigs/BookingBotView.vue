<script setup>
import { ref, reactive, onMounted, computed, watch, provide } from 'vue';
import googleSheetsExportAPI from '../../../../api/googleSheetsExport';
import FileKnowledgeSources from '../knowledge-sources/FileKnowledgeSources.vue';
import aiAgents from '../../../../api/aiAgents';
import remindersAPI from '../../../../api/reminders';
import idleConfigsAPI from '../../../../api/idleConfigs';
import QnaKnowledgeSources from '../knowledge-sources/QnaKnowledgeSources.vue'
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import CustomNumberingTab from './cs-bot-tabs/CustomNumberingTab.vue';

const { t } = useI18n();

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
  googleSheetsAuth: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['update:data']);
provide('emitUpdate', () => emit('update:data'));

// Tab management
const activeIndex = ref(0);
const tabs = computed(() => [
  {
    key: '0',
    index: 0,
    name: t('AGENT_MGMT.BOOKING_BOT.GENERAL_TAB'),
    icon: 'i-lucide-settings',
  },
  {
    key: '1',
    index: 1,
    name: t('AGENT_MGMT.BOOKING_BOT.FILE_TAB'),
    icon: 'i-lucide-folder',
  },
  {
    key: '2',
    index: 2,
    name: 'QnA',
    icon: 'i-lucide-help-circle',
  },
  {
    key: '3',
    index: 3,
    name: 'Penomoran Otomatis',
    icon: 'i-lucide-notebook-tabs',
  },
]);

// follow-up
const followUpConfig = reactive({
  enabled: false,
  delay: 60,
  message: ''
});

// follow-up options
const followUpTimeOptions = computed(() => [
  { label: t('AGENT_MGMT.REMINDER.TIME_OPTIONS.30_MINUTES'), value: 30 },
  { label: t('AGENT_MGMT.REMINDER.TIME_OPTIONS.1_HOUR'), value: 60 },
  { label: t('AGENT_MGMT.REMINDER.TIME_OPTIONS.2_HOURS'), value: 120 },
  { label: t('AGENT_MGMT.REMINDER.TIME_OPTIONS.4_HOURS'), value: 240 },
  { label: t('AGENT_MGMT.REMINDER.TIME_OPTIONS.24_HOURS'), value: 1440 },
]);

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
  duration: 30,        
});

// Steps: 'auth', 'connected', 'sheetConfig'
const step = computed(() => props.googleSheetsAuth.step);
const loading = computed(() => props.googleSheetsAuth.loading);
const account = computed(() => props.googleSheetsAuth.account);
const sheets = computed(() => props.googleSheetsAuth.spreadsheetUrls.booking);
const notification = ref(null);
const authError = computed(() => props.googleSheetsAuth.error);

// Booking-specific computed properties for better template logic
const bookingStep = computed(() => {
  // If we have booking sheets configured but no URLs, show 'connected' to display Create Sheets button
  if (props.googleSheetsAuth.step === 'sheetConfig' && 
      (!sheets.value.input || !sheets.value.output)) {
    return 'connected';
  }
  return props.googleSheetsAuth.step;
});

const bookingAuthError = computed(() => {
  const error = props.googleSheetsAuth.error;
  if (!error) return null;
  
  // Only show auth-related errors for booking agent
  const authKeywords = ['authentication', 'expired', 'invalid', 'unauthorized', 'token', 'permission'];
  const isAuthError = authKeywords.some(keyword => 
    error.toLowerCase().includes(keyword)
  );
  
  return isAuthError ? 'Your Google authentication has expired. Please re-authenticate to continue.' : null;
});

watch(bookingAuthError, (newError) => {
  if (newError) {
    notification.value = { message: t('AGENT_MGMT.AUTH_ERROR'), type: 'error' };
  } else {
    notification.value = null;
  }
}, { immediate: true });

watch(
  () => props.data,
  (newData) => {
    // Cek apakah data sudah valid dan memiliki display_flow_data
    if (newData && newData.display_flow_data) {
      loadSavedConfiguration();
      // Load idle config from API
      loadIdleConfig();
    }
  },
  { deep: true, immediate: true }
);

function loadSavedConfiguration() {
  const flowData = props.data?.display_flow_data;

  if (flowData?.agents_config) {
    const agent_index = flowData.enabled_agents.indexOf('booking');

    if (agent_index !== -1) {
      const agentData = flowData.agents_config[agent_index];
      const config = agentData.configurations;

      if (agentData.temperature !== undefined) {
        creativityLevel.value = agentData.temperature;
      }

      // Load konfigurasi umum
      if (config?.minimum_duration) {
        minDuration.value = config.minimum_duration;
      }

      // Load konfigurasi Follow Up
      if (config?.follow_up) {
        followUpConfig.enabled = config.follow_up.enabled || false;
        followUpConfig.delay = config.follow_up.delay || 60;
        followUpConfig.message = config.follow_up.message || '';
      }

    }
  }
}

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
      type: 'booking',
    };

    // Memanggil API wrapper yang baru kita perbaiki
    const response = await googleSheetsExportAPI.regenerateSpreadsheet(payload);

    if (response.data && response.data.input_spreadsheet_url) {
        props.googleSheetsAuth.spreadsheetUrls.booking.input = response.data.input_spreadsheet_url;

        if (response.data.output_spreadsheet_url) {
            props.googleSheetsAuth.spreadsheetUrls.booking.output = response.data.output_spreadsheet_url;
        }

        showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.REGENERATE_SUCCESS'), 'success');
    } else {
        throw new Error("Respon server tidak memiliki URL spreadsheet baru.");
    }

  } catch (error) {
    console.error('Failed to regenerate sheet:', error);
    showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.REGENERATE_ERROR'), 'error');
  } finally {
    isRegenerating.value = false;
  }
}

function retryAuthentication() {
  connectGoogle();
}

function disconnectGoogle() {
  // TODO: Implement disconnect logic
  console.log('Disconnect Google account clicked');
  googleSheetsExportAPI.disconnectAccount()
    .then(() => {
      props.googleSheetsAuth.step = 'auth';
      props.googleSheetsAuth.account = null;
      props.googleSheetsAuth.spreadsheetUrls.booking = { input: null, output: null };
      props.googleSheetsAuth.error = null;
      showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.DISCONNECT_SUCCESS'), 'success');
    })
    .catch((error) => {
      console.error('Failed to disconnect Google account:', error);
      showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.DISCONNECT_ERROR'), 'error');
    });
}

async function createSheets() {
  try {

    props.googleSheetsAuth.loading = true;
    
    const flowData = props.data.display_flow_data;
    const payload = {
      account_id: parseInt(flowData.account_id, 10),
      agent_id: agentId.value,
      type: 'booking',
    };
    

    const response = await googleSheetsExportAPI.createSpreadsheet(payload);
    
    if (response.data.input_spreadsheet_url && response.data.output_spreadsheet_url) {
      // Update parent's auth state
      props.googleSheetsAuth.spreadsheetUrls.booking.input = response.data.input_spreadsheet_url;
      props.googleSheetsAuth.spreadsheetUrls.booking.output = response.data.output_spreadsheet_url;
      props.googleSheetsAuth.step = 'sheetConfig';
      
      showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.CREATE_SHEETS_SUCCESS'), 'success');

    } else {
      throw new Error('Missing spreadsheet URLs in response');
    }
  } catch (error) {
    console.error('🚨 Failed to create booking sheets:', error);
    showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.CREATE_SHEETS_ERROR'), 'error');
  } finally {
    props.googleSheetsAuth.loading = false;
  }
}

// Reminder Message
const followUpTextarea = ref(null);
const cursorPosition = ref(0);
const showVariableDropdown = ref(false);

const AVAILABLE_VARIABLES = computed(() => [
  { label: t('AGENT_MGMT.REMINDER.VARIABLES.CUSTOMER_NAME'), value: '{{nama_pelanggan}}', mock: 'Budi Santoso' },
  { label: t('AGENT_MGMT.REMINDER.VARIABLES.BOOKING.DATE'), value: '{{tanggal_booking}}', mock: '25 Des 2025' },
  { label: t('AGENT_MGMT.REMINDER.VARIABLES.BOOKING.TIME'), value: '{{waktu_booking}}', mock: '14:00 WIB' },
  { label: t('AGENT_MGMT.REMINDER.VARIABLES.SERVICE_NAME'), value: '{{nama_layanan}}', mock: 'Konsultasi Premium' },
  { label: t('AGENT_MGMT.REMINDER.VARIABLES.BOOKING.LOCATION'), value: '{{lokasi}}', mock: 'Klinik Pratama' },
]);

const messagePreview = computed(() => {
  let text = followUpConfig.message || '';
  AVAILABLE_VARIABLES.value.forEach(variable => {
    text = text.replaceAll(variable.value, `<span class="font-bold text-slate-800 dark:text-slate-100">${variable.mock}</span>`);
  });
  return text.replace(/\n/g, '<br>');
});

const updateCursorPosition = () => {
  if (followUpTextarea.value) {
    cursorPosition.value = followUpTextarea.value.selectionStart;
  }
};

const insertVariable = (variableValue) => {
  const currentMessage = followUpConfig.message || '';
  const insertAt = cursorPosition.value;
  
  followUpConfig.message = currentMessage.substring(0, insertAt) + variableValue + currentMessage.substring(insertAt);
  
  cursorPosition.value = insertAt + variableValue.length; 
  showVariableDropdown.value = false;
  
  if(followUpTextarea.value) {
    followUpTextarea.value.focus();
    setTimeout(() => {
        followUpTextarea.value.setSelectionRange(cursorPosition.value, cursorPosition.value);
    }, 0);
  }
};

// Save state
const isSaving = ref(false);
const minDuration = ref('');

// New fields for resource and location columns
const resourceColumn = ref(['resource', 'resource2', 'resource3']);
const locationColumn = ref(['location']);
const syncingColumns = ref(false);


// Helper function to get agent ID by type
function getAgentIdByType(type) {
  const flowData = props.data?.display_flow_data;
  if (!flowData?.agents_config) return null;
  
  const agent = flowData.agents_config.find(config => config.type === type);
  return agent?.agent_id || null;
}

function getCollectionNameByAgentType(type) {
  const flowData = props.data?.display_flow_data;
  if (!flowData?.agents_config) return null;

  const agent = flowData.agents_config.find(config => config.type === type);
  return agent?.collection_name || null;
}

const agentId = computed(() => {
  return getAgentIdByType('booking');
});

const collectionName = computed(() => {
  return getCollectionNameByAgentType('booking');
});

async function connectGoogle() {
  try {
    props.googleSheetsAuth.loading = true;
    const response = await googleSheetsExportAPI.getAuthorizationUrl();
    if (response.data.authorization_url) {
      showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.REDIRECT_AUTH'), 'info');
      window.location.href = response.data.authorization_url;
    } else {
      showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.AUTH_URL_ERROR'), 'error');
    }
  } catch (error) {
    showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.AUTH_FAILED'), 'error');
  } finally {
    props.googleSheetsAuth.loading = false;
  }
}

function showNotification(message, type = 'success') {
  notification.value = { message, type };
  setTimeout(() => {
    notification.value = null;
  }, 3000);
}

async function syncScheduleColumns() {
  try {
    syncingColumns.value = true;
    showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.SYNC_START'), 'info');

    let flowData = JSON.parse(JSON.stringify(props.data.flow_data)); 
    let displayFlowData = JSON.parse(JSON.stringify(props.data.display_flow_data));
    const payload = {
      account_id: parseInt(flowData.account_id, 10),
      agent_id: agentId.value,
      type: 'booking',
      collection_name: collectionName.value,
      configurations: {
        resource_column: "Service Name*",
        location_column: "Service Category",
        date_column: "Available Days*",
        start_time_column: "Start Time*",
        end_time_column: "End Time"            
      }
    }
    const result = await googleSheetsExportAPI.syncSpreadsheet(payload);

    const agent_index = flowData.enabled_agents.indexOf('booking');

    if (result.data && result.data.data) {
      flowData.agents_config[agent_index].configurations.resource_names =
        result.data.data.unique_resource_names;
      flowData.agents_config[agent_index].configurations.location_names =
        result.data.data.unique_location_names;
      flowData.agents_config[agent_index].configurations.resource_types =
        result.data.data.unique_resource_types;

      displayFlowData.agents_config[agent_index].configurations.resource_names =
        result.data.data.unique_resource_names;
      displayFlowData.agents_config[agent_index].configurations.location_names =
        result.data.data.unique_location_names;
      displayFlowData.agents_config[agent_index].configurations.resource_types =
        result.data.data.unique_resource_types;
    }

    const updatePayload = {
      flow_data: flowData,
      display_flow_data: displayFlowData,
    };

    await aiAgents.updateAgent(props.data.id, updatePayload);
    
    emit('update:data');
    showNotification(t('AGENT_MGMT.BOOKING_BOT.ALERTS.SYNC_SUCCESS'), 'success');
  } catch (error) {
    console.error('Failed to sync schedule columns:', error);
    const errorMessage = error.response?.data?.message || t('AGENT_MGMT.BOOKING_BOT.ALERTS.SYNC_ERROR_DEFAULT');
    showNotification(errorMessage, 'error');
  } finally {
    syncingColumns.value = false;
  }
}

async function save() {
  if (isSaving.value) return; // Prevent multiple calls
  const configData = {
    minDuration: minDuration.value,
    follow_up: {
      enabled: followUpConfig.enabled,
      delay: followUpConfig.delay,
      message: followUpConfig.message
    }
  };
  try {
    isSaving.value = true;
    let flowData = JSON.parse(JSON.stringify(props.data.flow_data));
    let displayFlowData = JSON.parse(JSON.stringify(props.data.display_flow_data));
    const agent_index = flowData.enabled_agents.indexOf('booking');

    if (agent_index === -1) {
      useAlert(t('AGENT_MGMT.WEBSITE_SETTINGS.AGENT_NOT_FOUND'))
      return;
    }

    flowData.agents_config[agent_index].temperature = creativityLevel.value;
    displayFlowData.agents_config[agent_index].temperature = creativityLevel.value;

    flowData.agents_config[agent_index].configurations.minimum_duration =
      configData.minDuration;
    displayFlowData.agents_config[agent_index].configurations.minimum_duration =
      configData.minDuration;

    flowData.agents_config[agent_index].configurations.follow_up = configData.follow_up;
    displayFlowData.agents_config[agent_index].configurations.follow_up = configData.follow_up;

    const payload = {
      flow_data: flowData,
      display_flow_data: displayFlowData,
    };

    await Promise.all([
      aiAgents.updateAgent(props.data.id, payload),
      remindersAPI.updateConfig(props.data.id, {
        enabled: followUpConfig.enabled,
        minutes_before_booking: followUpConfig.delay,
        message_template: followUpConfig.message
      }),
      idleConfigsAPI.updateConfig(props.data.id, {
        duration: idleConfig.duration,
      })
    ]);
    emit('update:data');

    useAlert(t('AGENT_MGMT.CSBOT.TICKET.SAVE_SUCCESS'));
  } catch (e) {
    console.error('Save error:', e);
    useAlert(t('AGENT_MGMT.CSBOT.TICKET.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
}

// async function save() {
//   try {
//     isSaving.value = true;

//     // TODO: API call to save booking bot configuration
//     const configData = {
//       selectedTemplate: selectedTemplate.value,
//       minDuration: minDuration.value,
//       resourceColumns: resourceColumn.value,
//       locationColumns: locationColumn.value,
//       sheets: { ...sheets }
//     };
//     // eslint-disable-next-line no-console
//     console.log('configData:', configData);
//     await new Promise(resolve => setTimeout(resolve, 1000));
//     useAlert(t('AGENT_MGMT.BOOKING_BOT.SAVE_SUCCESS'));
//   } catch (e) {
//     useAlert(t('AGENT_MGMT.BOOKING_BOT.SAVE_ERROR'));
//     // eslint-disable-next-line no-console
//     console.error('Save error:', e);
//   } finally {
//     isSaving.value = false;
//   }
// }

// Load configuration data on mount
onMounted(async () => {
  loadSavedConfiguration();
  loadIdleConfig();
});
</script>

<template>
  <div class="w-full">
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
    
    <div class="pb-4">
      <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-25 mb-1">
        {{ $t('AGENT_MGMT.BOOKING_BOT.HEADER') }}
      </h2>
      <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
        {{ $t('AGENT_MGMT.BOOKING_BOT.HEADER_DESC') }}
      </p>
      <div class="border-b border-gray-200 dark:border-gray-700"></div>
    </div>
    
    <div class="space-y-6">
      <!-- Sidebar Navigation -->
      <div class="flex flex-row justify-stretch gap-2">
        <!-- Custom Tabs with SVG Icons -->
        <div class="flex flex-col gap-1 min-w-[200px] mr-4">
          <div
            v-for="tab in tabs"
            :key="tab.key"
            class="flex items-center gap-3 px-4 py-3 cursor-pointer rounded-lg transition-all duration-200 hover:bg-gray-50 dark:hover:bg-gray-800/50"
            :class="{
              'bg-woot-50 border-l-4 border-woot-500 text-woot-600 dark:bg-woot-900/50 dark:border-woot-400 dark:text-woot-400': tab.index === activeIndex,
              'text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-200': tab.index !== activeIndex,
            }"
            @click="activeIndex = tab.index"
          >
            <span
              :class="[
                tab.icon,
                'w-5 h-5 transition-all duration-200',
                {
                  'text-woot-600 dark:text-woot-400': tab.index === activeIndex,
                  'text-gray-500 dark:text-gray-400': tab.index !== activeIndex,
                }
              ]"
            />
            <span class="text-sm">{{ tab.name }}</span>
          </div>
        </div>

        <!-- General Tab Content -->
        <div v-show="activeIndex === 0" class="w-full">
          <div class="flex flex-row gap-4">
            <div class="flex-1 min-w-0 flex flex-col justify-stretch">
              <!-- Step 1: Google Auth -->
              <div v-if="bookingStep === 'auth'" class="w-full mx-auto">
                <div>
                  <label class="block font-medium mb-1">{{ $t('AGENT_MGMT.BOOKING_BOT.AUTH_LABEL') }}</label>
                  <p class="text-gray-600 dark:text-gray-400 mb-4">
                    {{ $t('AGENT_MGMT.BOOKING_BOT.AUTH_DESC') }}
                  </p>
                  <button
                    @click="connectGoogle"
                    class="inline-flex items-center space-x-3 bg-green-600 hover:bg-green-700 dark:bg-green-400 dark:hover:bg-green-500 text-white px-6 py-3 rounded-lg font-medium transition-colors"
                  >
                    <span>{{ $t('AGENT_MGMT.BOOKING_BOT.AUTH_BTN') }}</span>
                  </button>
                </div>
              </div>

              <!-- Step 2: Connected Confirmation -->
              <div v-else-if="bookingStep === 'connected'" class="py-8">
                <div class="text-center mb-8">
                  <div class="w-16 h-16 bg-green-100 dark:bg-green-800 rounded-full flex items-center justify-center mx-auto mb-4">
                    <svg class="w-8 h-8 text-green-600 dark:text-green-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd"/>
                    </svg>
                  </div>
                  <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-25 mb-2">{{ $t('AGENT_MGMT.BOOKING_BOT.CONNECTED_HEADER') }}</h3>
                  <p class="text-gray-600 dark:text-gray-400">{{ $t('AGENT_MGMT.BOOKING_BOT.CONNECTED_DESC') }}</p>
                  <p class="mt-2 text-sm text-gray-500">{{ account?.email }}</p>
                  <div class="flex flex-row centered justify-center align-center gap-4">

                    <button
                    class="mt-4 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                    @click="createSheets"
                    :disabled="loading"
                  >
                    <span v-if="loading">{{ $t('AGENT_MGMT.BOOKING_BOT.CREATE_SHEETS_LOADING') }}</span>
                    <span v-else>{{ $t('AGENT_MGMT.BOOKING_BOT.CREATE_SHEETS_BTN') }}</span>
                  </button>
                  
                  <button
                    class="mt-4 px-4 inline-flex items-center space-x-2 border-2 border-red-600 hover:border-red-700 dark:border-red-400 dark:hover:border-red-500 text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-red-50 dark:hover:bg-red-900/20"
                    @click="disconnectGoogle"
                    :disabled="loading"
                    >
                    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-ban">
                      <path d="M4.929 4.929 19.07 19.071"/>
                      <circle cx="12" cy="12" r="10"/>
                    </svg>
                    <span>{{ $t('AGENT_MGMT.BOOKING_BOT.DISC_BTN') }}</span>
                  </button>
                </div>
                  <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">
                    {{ $t('AGENT_MGMT.BOOKING_BOT.OR_RETRY_BTN') }}
                  </p>                
                </div>
              </div>

              <!-- Step 3: Sheet Configuration -->
              <div v-else-if="bookingStep === 'sheetConfig'">
                <div class="space-y-6">
                  <!-- Input Sheet Section - Schedule Data -->
                  <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-6 mb-6 border border-blue-200 dark:border-blue-800">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <div class="flex items-center mb-3">
                          <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
                            <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="currentColor" viewBox="0 0 20 20">
                              <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z"/>
                            </svg>
                          </div>
                          <div>
                            <h3 class="font-medium text-slate-900 dark:text-slate-25">
                              {{ $t('AGENT_MGMT.BOOKING_BOT.INPUT_SHEET_LABEL') }}
                            </h3>
                            <p class="text-sm text-slate-600 dark:text-slate-400">
                              {{ $t('AGENT_MGMT.BOOKING_BOT.INPUT_SHEET_DESC') }}
                            </p>
                          </div>
                        </div>
                      </div>
                      <div v-if="!ticketAuthError" class="flex flex-col gap-2">
                        <a 
                          :href="sheets.input" 
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

                    <!-- Schedule Column Sync Section -->
                    <div class="border-t border-blue-200 dark:border-blue-700 pt-6">
                      <div class="mb-4">
                        <h4 class="text-md font-medium text-slate-900 dark:text-slate-25 mb-2">{{ $t('AGENT_MGMT.BOOKING_BOT.SCHEDULE_CONFIGURATION') }}</h4>
                        <p class="text-sm text-blue-700 dark:text-blue-300">
                          {{ $t('AGENT_MGMT.BOOKING_BOT.SCHEDULE_CONFIGURATION_DESC') }}
                        </p>
                      </div>
                      
                      <!-- Minimum Duration Field -->
                        <div class="mb-6 flex flex-col md:flex-row md:items-start md:gap-6">
                          <div class="flex-1">
                            <label class="block text-sm font-medium mb-1 text-slate-900 dark:text-slate-25">{{ $t('AGENT_MGMT.BOOKING_BOT.MIN_DURATION_LABEL') }}</label>
                            <input 
                              type="number" 
                              min="0"
                              placeholder="30"
                              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                              v-model="minDuration" 
                            />
                          </div>
                        </div>

                      <!-- Sync Button for Resource and Location Lists -->
                      <div class="flex items-center justify-between gap-2">
                        <div>
                          <div v-if="!bookingAuthError">
                            <button
                            @click="syncScheduleColumns"
                            :disabled="syncingColumns"
                            class="h-full px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center gap-2 h-10 inline-flex items-center space-x-2 px-4 py-2 rounded-md font-small "
                            >
                            <svg v-if="syncingColumns" class="animate-spin -ml-1 mr-2 h-4 w-4" fill="none" viewBox="0 0 24 24">
                              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25"/>
                              <path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" class="opacity-75"/>
                            </svg>
                            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                            </svg>
                            {{ syncingColumns ? 'Syncing...' : $t('AGENT_MGMT.BOOKING_BOT.SYNC_BUTTON') }}
                          </button>
                        </div>
                      </div>

                      <div class="text-red-600 text-sm flex items-center gap-2">
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
                        :disabled="loading"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-ban-icon lucide-ban"><path d="M4.929 4.929 19.07 19.071"/><circle cx="12" cy="12" r="10"/></svg>
                          <span>{{ $t('AGENT_MGMT.BOOKING_BOT.DISC_BTN') }}</span>
                      </button>
                    </div>
                  </div>
                    </div>
                  </div>

                  <!-- Output Sheet Section - Booking Results -->
                  <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-6 mb-6 border border-blue-200 dark:border-blue-800">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center">
                        <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
                          <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z"/>
                          </svg>
                        </div>
                        <div>
                          <h4 class="font-medium text-slate-900 dark:text-slate-25">{{ $t('AGENT_MGMT.BOOKING_BOT.OUTPUT_SHEET_LABEL') }}</h4>
                          <p class="text-sm text-slate-600 dark:text-slate-400">{{ $t('AGENT_MGMT.BOOKING_BOT.OUTPUT_SHEET_DESC') }}</p>
                        </div>
                      </div>
                      <div v-if="!ticketAuthError">
                        <a 
                          :href="sheets.output" 
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
                  </div>
                  <div class="border border-gray-200 dark:border-gray-700 rounded-lg mb-6 bg-white dark:bg-transparent">
                    <div class="flex items-center justify-between p-6">
                      <div class="flex items-center">
                        <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center mr-3">
                          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5 text-green-600 dark:text-green-400">
                            <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
                            <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
                            <path d="M4 2C2.8 3.7 2 5.7 2 8" />
                            <path d="M22 8c0-2.3-.8-4.3-2-6" />
                          </svg>
                        </div>
                        <div>
                          <h3 class="font-medium text-slate-900 dark:text-slate-25">{{ $t('AGENT_MGMT.REMINDER.TITLE') }}</h3>
                          <p class="text-sm text-gray-500 mt-1">{{ $t('AGENT_MGMT.REMINDER.DESC') }}</p>
                        </div>
                      </div>
                      
                      <label class="inline-flex items-center cursor-pointer">
                        <input type="checkbox" v-model="followUpConfig.enabled" class="sr-only peer">
                        <div class="border solid w-11 h-6 bg-gray-200 rounded-full peer peer-checked:bg-green-500 relative after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full">
                        </div>
                      </label>
                    </div>
                    
                    <div 
                      v-if="followUpConfig.enabled" 
                      class="border-t border-gray-200 dark:border-gray-700 p-6 space-y-4 transition-all duration-200 ease-in-out"
                    >
                      <div>
                        <label class="block text-sm font-medium mb-1 text-slate-900 dark:text-slate-25">
                          {{ $t('AGENT_MGMT.REMINDER.TIME') }}
                        </label>
                        <div class="flex items-center gap-3">
                          <select 
                            v-model="followUpConfig.delay"
                            class="text-center w-24 mb-0 p-2 text-sm border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed dark:bg-slate-900 dark:border-slate-700 dark:text-white"
                          > 
                            <option 
                              class="bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100" 
                              v-for="opt in followUpTimeOptions" 
                              :key="opt.value" 
                              :value="opt.value"
                            >
                              {{ opt.label }}
                            </option>
                          </select>                   
                          
                          <span class="text-gray-500 text-sm">
                            {{ $t('AGENT_MGMT.REMINDER.TIME_DETAIL') }}
                          </span>
                        </div>
                        <p class="text-xs text-gray-500 mt-1 italic">{{ $t('AGENT_MGMT.REMINDER.TIME_DESC') }}</p>
                      </div>
                      <div>
                        <div class="flex justify-between items-end mb-1">
                          <label class="block text-sm font-medium text-slate-900 dark:text-slate-25">
                            {{ $t('AGENT_MGMT.REMINDER.MSG') }}
                          </label>

                          <div class="relative">
                            <button 
                              @click="showVariableDropdown = !showVariableDropdown"
                              type="button"
                              class="text-xs font-medium text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 flex items-center gap-1 px-2 py-1 rounded hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors"
                            >
                              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14"/><path d="M5 12h14"/></svg>
                              {{ $t('AGENT_MGMT.REMINDER.MSG_VARIABLE') }}
                            </button>

                            <div 
                              v-if="showVariableDropdown"
                              class="absolute right-0 top-full mt-1 z-20 w-48 bg-white dark:bg-slate-800 rounded-lg shadow-xl border border-gray-200 dark:border-gray-700 py-1"
                            >
                              <button
                                v-for="(item, index) in AVAILABLE_VARIABLES"
                                :key="index"
                                @click="insertVariable(item.value)"
                                class="w-full text-left px-4 py-2 text-xs text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-slate-700 transition-colors"
                              >
                                {{ item.label }}
                              </button>
                            </div>
                            <div v-if="showVariableDropdown" @click="showVariableDropdown = false" class="fixed inset-0 z-10 cursor-default"></div>
                          </div>
                        </div>

                        <textarea 
                          ref="followUpTextarea"
                          v-model="followUpConfig.message"
                          @click="updateCursorPosition"
                          @keyup="updateCursorPosition"
                          @blur="updateCursorPosition"
                          rows="4"
                          placeholder="Halo kak, terima kasih sudah melakukan booking. Apakah ada kendala atau pertanyaan lain?"
                          class="border-n-weak dark:border-n-weak hover:border-n-slate-6 dark:hover:border-n-slate-6 disabled:border-n-weak dark:disabled:border-n-weak focus:border-n-brand dark:focus:border-n-brand block w-full reset-base text-sm !px-3 !py-2.5 !mb-0 border rounded-lg bg-n-alpha-black2 file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-n-slate-10 dark:placeholder:text-n-slate-10 disabled:cursor-not-allowed disabled:opacity-50 text-n-slate-12 transition-all duration-500 ease-in-out"
                        ></textarea>
                        
                        <p class="text-xs text-gray-500 mt-1 italic">{{ $t('AGENT_MGMT.REMINDER.MSG_DESC') }}</p>

                        <div class="mt-3 bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded border border-gray-300 dark:border-slate-800 p-3">
                          <p class="text-[10px] uppercase tracking-wider font-bold text-slate-500 mb-1">{{ $t('AGENT_MGMT.REMINDER.MSG_EXAMPLE') }}</p>
                          <div class="text-sm text-slate-700 dark:text-slate-300 leading-relaxed">
                            <span v-if="!followUpConfig.message" class="text-slate-400 italic opacity-70">Belum ada pesan yang ditulis...</span>
                            <span v-else v-html="messagePreview"></span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
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
                          class="w-full mb-0 p-2 text-sm border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed dark:bg-slate-900 dark:border-slate-700 dark:text-white"
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
                        <div class="flex items-center gap-3">
                          <div class="w-16">
                            <input 
                              type="number" 
                              min="1"
                              v-model="idleConfig.duration"
                              class="text-center px-2 py-2 text-sm font-medium border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-green-500 focus:border-transparent transition-colors"
                              placeholder="30" 
                            />
                          </div>
                          <span class="text-slate-600 dark:text-slate-400 text-sm">
                            {{ $t('AGENT_MGMT.EOBOT.IDLE_TIME_DESC') }}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            
            <div v-if="bookingStep === 'sheetConfig'" class="w-[240px] flex flex-col gap-3">
              <div class="sticky bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm">
                <div class="flex items-center gap-3 mb-4">
                  <div class="w-10 h-10 flex-shrink-0 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">                    <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                    {{ $t('AGENT_MGMT.BOOKING_BOT.SAVE_BTN') }}
                  </span>
                </Button>
              </div>
            </div>
          </div>
        </div>

        <!-- File Tab Content -->
        <div v-show="activeIndex === 1" class="w-full min-w-0">
          <FileKnowledgeSources
            :data="data" 
            context="booking"
          />
        </div>

        <!-- QnA Tab Content -->
        <div v-show="activeIndex === 2" class="w-full min-w-0">
          <QnaKnowledgeSources :data="data" context="booking" />
        </div>

        <!-- Custom Numbering Content -->
        <div v-show="activeIndex === 3" class="w-full">
          <CustomNumberingTab :data="data" numbering-key="booking" />
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