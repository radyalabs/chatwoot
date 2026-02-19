<template>
  <div class="w-full min-w-0">
    <div class="flex flex-row gap-6">
      
      <div class="flex-1 min-w-0 flex flex-col justify-stretch gap-6">
        
        <div class="flex flex-col gap-1">
             <h3 class="text-lg font-bold text-slate-900 dark:text-white">
               {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.CONFIG_TITLE') }}
             </h3>
             <p class="text-sm text-gray-500">
               {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.CONFIG_DESC') }}
             </p>
        </div>

        <div>
          <button
            @click="openAddModal"
            :disabled="props.isSaving"
            class="inline-flex items-center gap-2 px-4 py-2.5 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-all font-medium shadow-sm active:scale-95 disabled:opacity-70 disabled:cursor-not-allowed"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.ADD_ADDRESS_BTN') }}
          </button>
        </div>

        <div class="space-y-4">
          <div v-for="(store, index) in localStores" :key="store.id || index" 
               class="bg-white dark:bg-slate-800 border border-gray-200 dark:border-gray-700 rounded-xl p-5 shadow-sm hover:shadow-md transition-shadow group">
            
            <div class="flex justify-between items-start mb-4">
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <h4 class="text-base font-bold text-slate-900 dark:text-white">{{ store.name }}</h4>
                </div>
                
                <div class="flex items-start mt-2 text-sm text-gray-600 dark:text-gray-300">
                  <svg class="w-4 h-4 mt-0.5 mr-2 flex-shrink-0 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  <span class="leading-snug">{{ store.address }}</span>
                </div>
                <div class="mt-1 text-xs text-gray-400 ml-6">
                   Lat: {{ store.coordinates?.lat?.toFixed(5) }}, Long: {{ store.coordinates?.lng?.toFixed(5) }}
                </div>
              </div>
              
              <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button @click="editStore(index)" :disabled="props.isSaving" class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed" title="Edit">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                  </svg>
                </button>
                <button @click="promptDelete(index)" :disabled="props.isSaving" class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed" title="Hapus">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>

            <div class="border-t border-gray-100 dark:border-gray-700 my-4"></div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
               <div class="flex items-center justify-between p-3.5 bg-gray-50 dark:bg-slate-900/50 rounded-lg border border-gray-100 dark:border-gray-700">
                  <div class="flex items-center gap-3">
                     <div class="w-8 h-8 rounded-full bg-white dark:bg-slate-700 flex items-center justify-center text-gray-500 shadow-sm">
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                           <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                        </svg>
                     </div>
                     <span class="text-sm font-medium">{{ $t('AGENT_MGMT.SALESBOT.SHIPPING.STORE_COURIER_LABEL') }}</span>
                  </div>
                  <span :class="[
                     'text-xs px-2.5 py-1 rounded-full font-medium border', 
                     store.store_courier?.enabled 
                       ? 'bg-green-50 text-green-700 border-green-200 dark:bg-green-900/20 dark:text-green-400 dark:border-green-800' 
                       : 'bg-gray-100 text-gray-500 border-gray-200 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-700'
                  ]">
                     {{ store.store_courier?.enabled ? $t('AGENT_MGMT.SALESBOT.SHIPPING.STATUS_ACTIVE') : $t('AGENT_MGMT.SALESBOT.SHIPPING.STATUS_INACTIVE') }}
                  </span>
               </div>

               <div class="flex items-center justify-between p-3.5 bg-gray-50 dark:bg-slate-900/50 rounded-lg border border-gray-100 dark:border-gray-700">
                  <div class="flex items-center gap-3">
                     <div class="w-8 h-8 rounded-full bg-white dark:bg-slate-700 flex items-center justify-center text-gray-500 shadow-sm">
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                           <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m8-2a2 2 0 11-4 0 2 2 0 014 0z" />
                        </svg>
                     </div>
                     <div class="flex flex-col">
                        <span class="text-sm font-medium">{{ $t('AGENT_MGMT.SALESBOT.SHIPPING.STORE_PICKUP_LABEL') }}</span>
                        <span v-if="store.store_pickup?.enabled" class="text-[10px] text-gray-500">
                           {{ store.store_pickup.open_time }} - {{ store.store_pickup.close_time }}
                        </span>
                     </div>
                  </div>
                  <span :class="[
                     'text-xs px-2.5 py-1 rounded-full font-medium border', 
                     store.store_pickup?.enabled 
                       ? 'bg-green-50 text-green-700 border-green-200 dark:bg-green-900/20 dark:text-green-400 dark:border-green-800' 
                       : 'bg-gray-100 text-gray-500 border-gray-200 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-700'
                  ]">
                     {{ store.store_pickup?.enabled ? $t('AGENT_MGMT.SALESBOT.SHIPPING.STATUS_ACTIVE') : $t('AGENT_MGMT.SALESBOT.SHIPPING.STATUS_INACTIVE') }}
                  </span>
               </div>
            </div>

          </div>
          
          <div v-if="localStores.length === 0" class="text-center py-12 bg-white dark:bg-slate-800 rounded-xl border border-dashed border-gray-300 dark:border-gray-700">
             <div class="w-16 h-16 bg-gray-50 dark:bg-slate-700 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="h-8 w-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
             </div>
             <h3 class="text-base font-medium text-gray-900 dark:text-gray-200">
               {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.EMPTY_STATE_TITLE') }}
             </h3>
             <p class="mt-1 text-sm text-gray-500 max-w-xs mx-auto">
               {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.EMPTY_STATE_DESC') }}
             </p>
             <button @click="openAddModal" :disabled="props.isSaving" class="mt-4 text-sm font-medium text-green-600 hover:text-green-700 disabled:opacity-50 disabled:cursor-not-allowed">
                {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.ADD_ADDRESS_EMPTY_BTN') }}
             </button>
          </div>
        </div>
      </div>

      <div class="w-[280px] flex flex-col gap-4 flex-shrink-0">
        <div class="sticky top-4 bg-white dark:bg-slate-800 rounded-xl border border-gray-200 dark:border-gray-700 p-5 shadow-sm">
          <div class="flex items-center gap-3 mb-4">
            <div class="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center flex-shrink-0">
              <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
              </svg>
            </div>
            <div>
              <h3 class="font-semibold text-slate-700 dark:text-slate-300">
                {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.SAVE_CONFIG_TITLE') }}
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.SAVE_CONFIG_DESC') }}
              </p>
            </div>
          </div>
          
          <button
            class="w-full flex justify-center items-center gap-2 bg-green-600 hover:bg-green-700 text-white px-4 py-2.5 rounded-lg transition-colors disabled:opacity-70 disabled:cursor-not-allowed font-medium shadow-sm"
            :disabled="props.isSaving"
            @click="saveAll"
          >
            <svg v-if="props.isSaving" class="animate-spin h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
               <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25"></circle>
               <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span>{{ props.isSaving ? $t('AGENT_MGMT.SALESBOT.SHIPPING.SAVING_BTN') : $t('AGENT_MGMT.SALESBOT.SHIPPING.SAVE_BTN') }}</span>
          </button>
        </div>
      </div>
    </div>

    <StoreAddressModal 
      :is-open="showModal"
      :initial-data="selectedStore"
      @close="closeModal"
      @save="handleSaveStore"
    />

    <div v-if="showDeleteModal" class="fixed inset-0 z-[70] flex items-center justify-center p-4 sm:p-6" role="dialog">
      <div class="fixed inset-0 bg-slate-900/50 transition-opacity backdrop-blur-sm" @click="cancelDelete"></div>
      
      <div class="relative w-full max-w-md transform rounded-xl bg-white dark:bg-slate-800 shadow-xl transition-all border border-gray-200 dark:border-gray-700 overflow-hidden">
        <div class="p-6">
          <div class="flex items-center gap-4 mb-4">
            <div class="w-12 h-12 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center flex-shrink-0 text-red-600 dark:text-red-400">
              <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-bold text-slate-900 dark:text-white">
                {{ $t('AGENT_MGMT.DELETE.CONFIRM.TITLE') }}
              </h3>
              <p class="text-sm text-gray-500 mt-1">
                {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.DELETE_CONFIRM') }}
              </p>
            </div>
          </div>
          
          <div class="flex justify-end gap-3 mt-6">
            <button 
              @click="cancelDelete" 
              class="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors dark:border-gray-600 dark:text-gray-200 dark:hover:bg-slate-700"
            >
              {{ $t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT') }}
            </button>
            <button 
              @click="confirmDelete" 
              class="px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium hover:bg-red-700 shadow-sm transition-colors"
            >
              {{ $t('AGENT_MGMT.DELETE.BUTTON_TEXT') }}
            </button>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import StoreAddressModal from './components/StoreAddressModal.vue';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const store = useStore();

const props = defineProps({
  aiAgentId: {
    type: [Number, String],
    required: true
  },
  isSaving: {
    type: Boolean,
    default: false
  }
});

const emit = defineEmits(['save-config']);

const savedStores = computed(() => store.getters['shippingStores/getStores']);
const uiFlags = computed(() => store.getters['shippingStores/getUIFlags']);

const localStores = ref([]);

const showModal = ref(false);
const selectedStore = ref(null);
const editingIndex = ref(-1);

// State untuk Modal Hapus Custom
const showDeleteModal = ref(false);
const storeToDeleteIndex = ref(-1);

// PERBAIKAN: Gunakan watch agar data sinkron saat fetch dari parent selesai
watch(savedStores, (newStores) => {
  if (newStores) {
    localStores.value = JSON.parse(JSON.stringify(newStores));
  }
}, { deep: true, immediate: true });

const openAddModal = () => {
  selectedStore.value = null;
  editingIndex.value = -1;
  showModal.value = true;
};

const editStore = (index) => {
  selectedStore.value = JSON.parse(JSON.stringify(localStores.value[index]));
  editingIndex.value = index;
  showModal.value = true;
};

// PERBAIKAN: Fungsi Prompt Hapus (Buka Modal Custom)
const promptDelete = (index) => {
  storeToDeleteIndex.value = index;
  showDeleteModal.value = true;
};

// PERBAIKAN: Fungsi Konfirmasi Hapus
const confirmDelete = () => {
  if (storeToDeleteIndex.value > -1) {
    localStores.value.splice(storeToDeleteIndex.value, 1);
    storeToDeleteIndex.value = -1;
  }
  showDeleteModal.value = false;
};

// PERBAIKAN: Fungsi Batal Hapus
const cancelDelete = () => {
  storeToDeleteIndex.value = -1;
  showDeleteModal.value = false;
};

const closeModal = () => {
  showModal.value = false;
  selectedStore.value = null;
};

const handleSaveStore = (storeData) => {
  if (editingIndex.value > -1) {
    localStores.value[editingIndex.value] = storeData;
  } else {
    localStores.value.push(storeData);
  }
};

const saveAll = () => {
  emit('save-config', localStores.value);
};
</script>