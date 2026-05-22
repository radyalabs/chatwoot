<script setup>
import { computed, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import aiAgents from '../../../../api/aiAgents';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
// import * as XLSX from 'xlsx'; // Commented out Excel support
const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
  // Context untuk membedakan booking vs cs
  context: {
    type: String,
    default: 'general',
    validator: (value) => ['booking', 'cs', 'sales', 'general', 'lead_generation'].includes(value)
  }
});

const { t } = useI18n();

const files = ref([]);

// Filter files berdasarkan prefix di nama file
const contextFiles = computed(() => {
  if (props.context === 'general') {
    return files.value;
  }
  
  // Filter berdasarkan prefix [BOOKING] atau [CS] di nama file
  const prefix = `[${props.context.toUpperCase()}]`;
  return files.value.filter(file => {
    const fileName = file.file_name || '';
    return fileName.startsWith(prefix);
  });
});

const collectionName = computed(() => {
  if (!props.data?.display_flow_data?.agents_config) return null;
  
  const agents = props.data.display_flow_data.agents_config;
  
  // For general context, return the first agent's collection_name
  if (props.context === 'general') {
    return agents[0]?.collection_name || null;
  }
  
  const targetType = props.context;
  if (!targetType) return null;
  
  // Find agent by type
  const agent = agents.find(agent => agent.type === targetType);
  return agent?.collection_name || null;
});

const detectedCharacters = computed(() =>
  contextFiles.value.reduce((p, i) => p + i.total_chars, 0)
);

const isFetching = ref(false);
async function fetchKnowledge() {
  try {
    isFetching.value = true;
    const data = await aiAgents.getKnowledgeSources(props.data.id);
    files.value = data.data?.knowledge_source_files || [];
  } catch (e) {
    useAlert('Gagal mendapatkan data');
  } finally {
    isFetching.value = false;
  }
}

watch(
  () => props.data,
  v => {
    if (!v) return;
    fetchKnowledge();
  },
  { immediate: true, deep: true }
);

const showDeleteModal = ref();
const deleteModalData = ref();

function deleteFile(data) {
  deleteModalData.value = contextFiles.value.find(v => v.id === data.id);
  showDeleteModal.value = true;
}

const deleteLoadingIds = ref({});

async function deleteData() {
  const dataId = deleteModalData.value.id;
  const collection_name = collectionName.value; // Change this line
  
  try {
    showDeleteModal.value = false;
    deleteLoadingIds.value[dataId] = true;
    await aiAgents.deleteKnowledgeFile(props.data.id, dataId, collection_name);
    files.value = files.value.filter(v => v.id !== dataId);
    fetchKnowledge();
    useAlert('Berhasil hapus data');
  } catch (e) {
    useAlert('Gagal hapus data');
  } finally {
    deleteLoadingIds.value[dataId] = false;
  }
}

const newFiles = ref([]);

function inputFile() {
  return document.getElementById(`${props.context}-inputfile`);
}

function openPicker() {
  const input = inputFile();
  if (!input) {
    console.error(`Input element not found for context: ${props.context}`);
    return;
  }
  input.click();
}

function onInputChanged(event) {
  if (!event.target.files || !event.target.files.length) return;
  addFile(event.target.files[0]);
  event.target.value = '';
}

function addFile(file) {
  // Validasi
  if (!file.name.endsWith('.pdf') && !file.name.endsWith('.docx')) {
    useAlert('Only PDF and DOCX files are allowed');
    return;
  }
  
  if (file.size > 20971520) {
    useAlert(t('CONVERSATION.UPLOAD_MAX_REACHED'));
    return;
  }
  
  // Tambahkan context metadata ke file object
  file._contextType = props.context;
  
  newFiles.value.push(file);
}

const isSaving = ref(false);
const isDeletingAny = computed(() => Object.values(deleteLoadingIds.value).some(Boolean));

async function save() {
  if (!newFiles.value.length) return;
  const collection_name = collectionName.value; // Change this line

  try {
    isSaving.value = true;

    for (const file of newFiles.value) {
      const formData = new FormData();
      
      // KUNCI: Rename file dengan prefix context SEBELUM upload
      // Backend akan simpan dengan nama ini
      const prefix = props.context !== 'general' ? `[${props.context.toUpperCase()}] ` : '';
      const newFileName = `${prefix}${file.name}`;
      
      // Create new File object with modified name
      const renamedFile = new File([file], newFileName, {
        type: file.type,
        lastModified: file.lastModified,
      });
      
      formData.append('file', renamedFile);
      formData.append('collection_name', collection_name); // Tambahkan collection_name ke formData
      await aiAgents.addKnowledgeFile(props.data.id, formData);
    }

    newFiles.value = [];
    fetchKnowledge();
    useAlert('Berhasil simpan data');
  } catch (e) {
    console.error('Error saving files:', e);
    useAlert('Gagal simpan data');
  } finally {
    isSaving.value = false;
  }
}

const handleDragOver = () => {
}

const handleDragLeave = () => {
}

const handleDrop = (event) => {
  const droppedFiles = event.dataTransfer?.files;
  if (!droppedFiles || !droppedFiles.length || droppedFiles.length > 1) return;
  addFile(droppedFiles.item(0));
};

const isButtonDisabled = computed(() => {
  return isSaving.value || !newFiles.value.length;
});

const contextLabel = computed(() => {
  switch(props.context) {
    case 'booking': return 'Booking Bot';
    case 'cs': return 'CS Bot';
    case 'sales': return 'Sales Bot';
    case 'lead_generation': return 'Lead Generation Bot';
    default: return 'General';
  }
});

// Preview how filename will look after upload
const formattedFileName = (fileName) => {
  if (props.context === 'general') return fileName;
  return `[${props.context.toUpperCase()}] ${fileName}`;
};

async function previewFile(item) {
  try {
    const res = await aiAgents.previewKnowledgeFile(
      props.data.id,
      item.id
    );

    window.open(res.data.url, '_blank');
  } catch (e) {
    useAlert('File preview failed');
  }
}
</script>

<template>
  <div class="flex flex-row gap-4">
    <div class="flex-1 min-w-0 flex flex-col justify-stretch gap-4">      
      <div v-if="isFetching" class="text-center py-8">
        <span class="spinner" />
        <p class="text-sm text-gray-500 mt-2">Loading files...</p>
      </div>
      
      <div
        class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg px-5 py-10 flex items-center justify-center cursor-pointer hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/10 transition-all"
        :class="{ 'opacity-50 pointer-events-none cursor-not-allowed': isSaving || isDeletingAny }"
        @click="openPicker"
        @dragover.prevent="handleDragOver"
        @dragleave="handleDragLeave"
        @drop.prevent="handleDrop"
      >
        <input
          :id="`${context}-inputfile`"
          type="file"
          class="hidden"
          accept=".pdf, .docx"
          :disabled="isSaving || isDeletingAny"
          @change="onInputChanged"
        />
        <div class="text-center">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
          <span class="text-gray-700 dark:text-gray-300"> {{ $t("CONVERSATION.PLACEHOLDER_UPLOAD.PART_1") }} </span>
          <br />
          <span class="text-gray-500 dark:text-gray-400 text-sm"> {{ $t("CONVERSATION.PLACEHOLDER_UPLOAD.PART_2") }} </span>
        </div>
      </div>

      <!-- Saved Files Section -->
      <div class="bg-gray-50 dark:bg-gray-800/50 rounded-lg p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-medium text-gray-900 dark:text-gray-100 flex items-center gap-2">
            <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            {{ $t("CONVERSATION.PLACEHOLDER_UPLOAD.PART_3") }}
          </h3>
          <span class="px-2 py-1 bg-gray-200 dark:bg-gray-700 text-xs font-medium rounded-full">
            {{ contextFiles.length }}
          </span>
        </div>
        
        <div v-if="contextFiles.length === 0" class="text-center py-6 text-gray-500 dark:text-gray-400 text-sm">
          <svg class="w-8 h-8 mx-auto mb-2 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>
          </svg>
          Belum ada file untuk {{ contextLabel }}
        </div>
        
        <div v-else class="space-y-2">
          <div
            v-for="(item, index) in contextFiles"
            :key="index"
            class="flex items-center gap-3 p-2 dark:bg-gray-700 rounded border border-gray-200 dark:border-gray-600 hover:border-blue-300 dark:hover:border-blue-600 transition-colors"
          >
            <svg class="w-4 h-4 text-blue-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            <span 
              class="flex-1 text-sm truncate cursor-pointer text-gray-900 hover:underline dark:text-gray-100"
              @click="previewFile(item)"
            >
              {{ item.file_name }}
            </span>
            <span class="text-xs font-medium text-gray-600 dark:text-gray-400 whitespace-nowrap">{{ item.total_chars }} {{ $t("AGENT_MGMT.BOOKING_BOT.CHAR") }}</span>
            <Button
              variant="ghost"
              color="ruby"
              size="sm"
              icon="i-lucide-trash"
              :is-loading="deleteLoadingIds[item.id]"
              :disabled="deleteLoadingIds[item.id] || isSaving || isDeletingAny"
              @click="() => deleteFile(item)"
            />
          </div>
        </div>
      </div>

      <!-- Pending Upload Section -->
      <div v-if="newFiles.length > 0" class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-700 rounded-lg p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-medium text-yellow-900 dark:text-yellow-100 flex items-center gap-2">
            <svg class="w-5 h-5 text-yellow-600 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            {{ $t("CONVERSATION.PLACEHOLDER_UPLOAD.PART_4") }}
          </h3>
          <span class="px-2 py-1 bg-yellow-200 dark:bg-yellow-800 text-yellow-900 dark:text-yellow-100 text-xs font-medium rounded-full">
            {{ newFiles.length }} pending
          </span>
        </div>
        
        <div class="space-y-2">
          <div
            v-for="(item, index) in newFiles"
            :key="index"
            class="flex items-center gap-3 p-2 bg-white dark:bg-gray-700 rounded border border-yellow-300 dark:border-yellow-600"
          >
            <svg class="w-4 h-4 text-yellow-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
            </svg>
            <div class="flex-1 min-w-0">
              <div class="text-sm text-gray-900 dark:text-gray-100 truncate font-medium">
                {{ formattedFileName(item.name) }}
              </div>
              <div class="text-xs text-gray-500 dark:text-gray-400">
                {{ (item.size / 1024).toFixed(2) }} KB
              </div>
            </div>
            <Button
              variant="ghost"
              color="ruby"
              size="sm"
              icon="i-lucide-trash"
              :disabled="isSaving || isDeletingAny"
              @click="() => newFiles.splice(index, 1)"
            />
          </div>
        </div>
      </div>

      <woot-delete-modal
        v-if="showDeleteModal"
        v-model:show="showDeleteModal"
        :on-close="() => { showDeleteModal = false; }"
        :on-confirm="() => deleteData()"
        title="Apakah kamu akan menghapus data ini?"
        message="Kamu tidak akan mengembalikan data ini"
        :confirm-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')"
        :reject-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')"
      />
    </div>
    
    <!-- Sidebar -->
    <div class="w-[240px] flex flex-col gap-3">
      <div class="sticky top-4 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm">
        <div class="flex items-center gap-3 mb-4">
          <div class="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center flex-shrink-0">
            <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
          <div class="min-w-0">
            <h3 class="font-semibold text-slate-700 dark:text-slate-300 truncate">{{ contextLabel }}</h3>
            <p class="text-sm text-slate-500 dark:text-slate-400">{{ contextFiles.length }} items</p>
          </div>
        </div>
        
        <div class="space-y-3 mb-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
          <div class="flex justify-between text-sm">
            <span class="text-slate-600 dark:text-slate-400">{{ $t('AGENT_MGMT.CSBOT.TICKET.CHARACTERS') }}</span>
            <span class="font-semibold text-slate-900 dark:text-slate-100">{{ detectedCharacters.toLocaleString() }}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-slate-600 dark:text-slate-400">Pending</span>
            <span class="font-semibold text-yellow-700 dark:text-yellow-300">{{ newFiles.length }}</span>
          </div>
        </div>
        
        <Button
          class="w-full"
          :is-loading="isSaving"
          :disabled="isButtonDisabled"
          @click="save"
        >
          <span class="flex items-center justify-center gap-2">
            <svg v-if="!isSaving" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 11l3 3m0 0l3-3m-3 3V9"/>
            </svg>
            {{ isSaving ? 'Uploading...' : $t('AGENT_MGMT.CSBOT.TICKET.SAVE_BUTTON') }}
          </span>
        </Button>
        
        <div class="mt-3 text-center">
          <div v-if="isButtonDisabled && !isSaving" class="text-xs text-gray-500 dark:text-gray-400">
            {{ newFiles.length === 0 ? 'Upload file terlebih dahulu' : '' }}
          </div>
          <div v-else-if="!isButtonDisabled" class="text-xs text-green-600 dark:text-green-400 font-medium">
            ✅ Siap untuk upload
          </div>
        </div>
      </div>
    </div>
  </div>
</template>