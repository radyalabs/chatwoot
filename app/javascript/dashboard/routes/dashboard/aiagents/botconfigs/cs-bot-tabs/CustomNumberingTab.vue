<template>
  <div class="w-full">
    <div class="flex flex-row gap-4">
      
      <div class="flex-1 min-w-0 flex flex-col gap-6">
        
        <div class="border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-transparent">
          
          <div class="flex items-center gap-3 p-6">
            <div class="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-lg flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" />
              </svg>
            </div>
            <div>
              <h2 class="text-lg font-medium text-slate-900 dark:text-slate-25">{{ $t('AGENT_MGMT.NUMBERING.TITLE') }}</h2>
              <p class="text-sm text-gray-500">{{ $t('AGENT_MGMT.NUMBERING.DESC') }}</p>
            </div>
          </div>
          
          <div class="border-t border-gray-200 dark:border-gray-700 p-6 space-y-6">
            
            <div>
              <label class="block text-sm font-medium mb-1 text-slate-900 dark:text-slate-25">
                {{ $t('AGENT_MGMT.NUMBERING.FORMAT') }} <span class="text-red-500">*</span>
              </label>
              <div class="flex flex-col sm:flex-row gap-2 mb-2">
                <input 
                  v-model="form.format" 
                  type="text" 
                  class="flex-1 p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 focus:ring-2 focus:ring-green-500 focus:border-transparent text-slate-900 dark:text-slate-100 transition-all placeholder:text-gray-400"
                  placeholder="[NUMBER]/[MONTH]/[YEAR]"
                />
                <select 
                  v-model="codeOption" 
                  @change="addCode"
                  class="sm:w-64 p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 focus:ring-2 focus:ring-green-500 text-slate-900 dark:text-slate-100 transition-all cursor-pointer"
                >
                  <option value="" disabled selected hidden>{{ $t('AGENT_MGMT.NUMBERING.ADD_CODE_TITLE') }}</option>
                  <option value="[NUMBER]">{{ $t('AGENT_MGMT.NUMBERING.OPTIONS.NUMBER') }}</option>
                  <option value="[MONTH]">{{ $t('AGENT_MGMT.NUMBERING.OPTIONS.MONTH') }}</option>
                  <option value="[MONTH_ROMAN]">{{ $t('AGENT_MGMT.NUMBERING.OPTIONS.MONTH_ROMAN') }}</option>
                  <option value="[MONTH_SHORT]">{{ $t('AGENT_MGMT.NUMBERING.OPTIONS.MONTH_SHORT') }}</option>
                  <option value="[MONTH_LONG]">{{ $t('AGENT_MGMT.NUMBERING.OPTIONS.MONTH_LONG') }}</option>
                  <option value="[YEAR_SHORT]">{{ $t('AGENT_MGMT.NUMBERING.OPTIONS.YEAR_SHORT') }}</option>
                  <option value="[YEAR]">{{ $t('AGENT_MGMT.NUMBERING.OPTIONS.YEAR') }}</option>
                </select>
              </div>
              <div class="flex items-center gap-2 p-2 bg-gray-50 dark:bg-slate-800/50 rounded text-xs text-gray-500 dark:text-gray-400">
                <span>{{ $t('AGENT_MGMT.NUMBERING.PREVIEW') }}</span>
                <span class="font-mono font-bold text-green-600 dark:text-green-400 bg-green-100 dark:bg-green-900/30 px-2 py-0.5 rounded">
                  {{ liveSampleOutput }}
                </span>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
              <div>
                <label class="block text-sm font-medium mb-1 text-slate-900 dark:text-slate-25">
                  {{ $t('AGENT_MGMT.NUMBERING.NUMBER') }} <span class="text-red-500">*</span>
                </label>
                <input 
                  v-model.number="form.currentNumber" 
                  type="number" 
                  min="1" 
                  class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 focus:ring-2 focus:ring-green-500 text-slate-900 dark:text-slate-100 transition-all" 
                />
              </div>

              <div>
                <label class="block text-sm font-medium mb-1 text-slate-900 dark:text-slate-25">
                  {{ $t('AGENT_MGMT.NUMBERING.DIGIT_NUMBER') }}
                </label>
                <input 
                  v-model.number="form.number_digits" 
                  type="number" 
                  min="3" 
                  class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 focus:ring-2 focus:ring-green-500 text-slate-900 dark:text-slate-100 transition-all" 
                />
                <p class="text-[10px] text-gray-400 italic">Min: 3 (001)</p>
              </div>

              <div>
                <label class="block text-sm font-medium mb-1 text-slate-900 dark:text-slate-25">
                  {{ $t('AGENT_MGMT.NUMBERING.PREFIX') }}
                </label>
                <input 
                  v-model="form.prefix" 
                  type="text" 
                  :placeholder="$t('AGENT_MGMT.NUMBERING.PREFIX_EXP')"
                  class="w-full p-2.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-slate-800 focus:ring-2 focus:ring-green-500 text-slate-900 dark:text-slate-100 transition-all" 
                />
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium mb-3 text-slate-900 dark:text-slate-25">
                {{ $t('AGENT_MGMT.NUMBERING.RESET_TITLE') }}
              </label>
              <div class="flex flex-col gap-3">
                <label class="flex items-center cursor-pointer group">
                  <div class="relative flex items-center">
                    <input type="radio" value="never" v-model="form.resetEvery" class="peer sr-only" />
                    <div class="w-5 h-5 border-2 border-gray-300 dark:border-gray-500 rounded-full peer-checked:border-green-500 peer-checked:bg-green-500 transition-all"></div>
                    <div class="absolute w-2 h-2 bg-white rounded-full left-1.5 top-1.5 opacity-0 peer-checked:opacity-100 transition-all"></div>
                  </div>
                  <span class="ml-3 text-sm text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-white transition-colors">
                    {{ $t('AGENT_MGMT.NUMBERING.NEVER_RESET') }}
                  </span>
                </label>

                <label class="flex items-center cursor-pointer group">
                  <div class="relative flex items-center">
                    <input type="radio" value="month" v-model="form.resetEvery" class="peer sr-only" />
                    <div class="w-5 h-5 border-2 border-gray-300 dark:border-gray-500 rounded-full peer-checked:border-green-500 peer-checked:bg-green-500 transition-all"></div>
                    <div class="absolute w-2 h-2 bg-white rounded-full left-1.5 top-1.5 opacity-0 peer-checked:opacity-100 transition-all"></div>
                  </div>
                  <span class="ml-3 text-sm text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-white transition-colors">
                    {{ $t('AGENT_MGMT.NUMBERING.RESET_MONTHLY') }}
                  </span>
                </label>

                <label class="flex items-center cursor-pointer group">
                  <div class="relative flex items-center">
                    <input type="radio" value="year" v-model="form.resetEvery" class="peer sr-only" />
                    <div class="w-5 h-5 border-2 border-gray-300 dark:border-gray-500 rounded-full peer-checked:border-green-500 peer-checked:bg-green-500 transition-all"></div>
                    <div class="absolute w-2 h-2 bg-white rounded-full left-1.5 top-1.5 opacity-0 peer-checked:opacity-100 transition-all"></div>
                  </div>
                  <span class="ml-3 text-sm text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-white transition-colors">
                    {{ $t('AGENT_MGMT.NUMBERING.RESET_YEARLY') }}
                  </span>
                </label>
              </div>
            </div>

          </div>
        </div>
      </div>

      <div class="w-[240px] flex flex-col gap-3">
        <div class="sticky top-4 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm">
          <div class="flex items-center gap-3 mb-4">
            <div class="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <div>
              <h3 class="font-semibold text-slate-700 dark:text-slate-300">{{ $t('AGENT_MGMT.BOOKING_BOT.CONFIGURE') }}</h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">{{ $t('AGENT_MGMT.NUMBERING.SAVE_DESC') }}</p>
            </div>
          </div>
          
          <Button
            class="w-full"
            :is-loading="loading"
            :disabled="loading"
            @click="onSave"
          >
             <span class="flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                </svg>
                {{ $t('AGENT_MGMT.EOBOT.SAVE_BTN') }}
             </span>
          </Button>
        </div>
      </div>

    </div>

    <div v-if="showSuccessModal" class="success-modal-overlay" @click.self="closeSuccessModal">
        <div class="success-modal-content dark:bg-slate-800 dark:border dark:border-slate-700">
          
          <div class="modal-icon-wrapper dark:bg-green-900/30">
            <svg class="modal-icon dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
            </svg>
          </div>

          <h2 class="modal-title dark:text-white">{{ $t('AGENT_MGMT.NUMBERING.SUCCESS') }}</h2>
          <p class="modal-message dark:text-slate-300">{{ $t('AGENT_MGMT.NUMBERING.SUCCESS_MESSAGE') }}</p>

          <button class="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded transition-colors" @click="closeSuccessModal">
            {{ $t('AGENT_MGMT.NUMBERING.CLOSE') }}
          </button>

      </div>
    </div>
  </div>
</template>

<script>
import { useAlert } from 'dashboard/composables';
import aiAgents from '../../../../../api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';

export default {
  name: 'AutoNumbering',
  components: {
    Button,
  },
  inject: {
    // Provided by CSBotView -> parent to trigger refresh
    emitUpdate: {
      default: () => () => {},
    },
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
  },

  data() {
    return {
      form: {
        prefix: '',
        format: '[NUMBER]/[MONTH]/[YEAR]',
        currentNumber: 1,
        resetEvery: 'never',
        number_digits: 3,
      },
      codeOption: '',
      showSuccessModal: false,
      loading: false,
    };
  },
  computed: {
    liveSampleOutput() {
      if (!this.form.format) return '...';

      const roman = ['I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'];
      const shortMonths = ['JAN','FEB','MAR','APR','MEI','JUN','JUL','AGU','SEP','OKT','NOV','DES'];
      const longMonths = ['JANUARI','FEBRUARI','MARET','APRIL','MEI','JUNI','JULI','AGUSTUS','SEPTEMBER','OKTOBER','NOVEMBER','DESEMBER'];

      const now = new Date();
      const year = now.getFullYear();                
      const yearShort = String(year).slice(-2);      
      const monthIndex = now.getMonth();             
      const monthNum = String(monthIndex + 1).padStart(2, '0');

      let padding = this.form.number_digits || 3;
      if (padding < 3) {
        padding = 3;
      }
      const number = String(this.form.currentNumber || 0).padStart(padding, '0');

      const processedFormat = this.form.format
        .replace(/\[NUMBER\]/g, number)
        .replace(/\[YEAR\]/g, year)
        .replace(/\[YEAR_SHORT\]/g, yearShort)
        .replace(/\[MONTH\]/g, monthNum)
        .replace(/\[MONTH_ROMAN\]/g, roman[monthIndex])
        .replace(/\[MONTH_SHORT\]/g, shortMonths[monthIndex])
        .replace(/\[MONTH_LONG\]/g, longMonths[monthIndex]);

      return (this.form.prefix || '') + processedFormat;
    },
  },
  watch: {
    data: {
      handler(newData) {
        // Cek jika 'number_format_config' ada di dalam flowData
        if (newData && 
            newData.display_flow_data && 
            newData.display_flow_data.agents_config && 
            newData.display_flow_data.agents_config[0] &&
            newData.display_flow_data.agents_config[0].configurations && 
            newData.display_flow_data.agents_config[0].configurations.number_format
        ) {
          // Gabungkan data dari flowData dengan data default
          this.form = { 
            ...this.form, 
            ...newData.display_flow_data.agents_config[0].configurations.number_format 
          };
        }
      },
      immediate: true,
      deep: true,
    }
  },

  methods: {
    addCode() {
      const token = this.codeOption;
      if (!token) return;
      this.form.format = this.form.format + token;
      this.codeOption = '';
    },

    async onSave() {
      if (this.loading) return;

      try {
        this.loading = true;
        const flowData = JSON.parse(JSON.stringify(this.data.flow_data));
        const displayFlowData = JSON.parse(JSON.stringify(this.data.display_flow_data));


        // Pastikan path-nya ada
        if (flowData.agents_config && flowData.agents_config[0]) {
          if (!flowData.agents_config[0].configurations) {
            flowData.agents_config[0].configurations = {};
          }
          // Suntikkan 'form' kita ke lokasi yang benar
          flowData.agents_config[0].configurations.number_format = this.form;
          displayFlowData.agents_config[0].configurations.number_format = this.form;
        } else {
          throw new Error("Format data tidak ditemukan.");
        }

        const payload = {
          flow_data: flowData,
          display_flow_data: displayFlowData,
        };

        await aiAgents.updateAgent(this.data.id, payload);

        // trigger parent refresh
        this.emitUpdate();


        this.showSuccessModal = true;

      } catch (error) {
        console.error("Gagal menyimpan:", error);
      } finally {
        this.loading = false;
      }
    },
    
    closeSuccessModal() {
      this.showSuccessModal = false;
    },
  },
};
</script>

<style scoped>
.success-modal-overlay {
  position: fixed; 
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5); 
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 999; 
}

.success-modal-content {
  background-color: white;
  padding: 24px;
  border-radius: 8px;
  text-align: center;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  max-width: 400px; /* Lebar modal */
  width: 90%;
}

.modal-icon-wrapper {
  width: 72px;
  height: 72px;
  background-color: #A7F3D0; 
  border-radius: 50%; 
  margin: 0 auto 20px auto; 
  display: flex;
  justify-content: center;
  align-items: center;
}

.modal-icon {
  width: 36px;
  height: 36px;
  color: #065F46; 
}

.modal-title {
  font-size: 24px; 
  font-weight: 600; 
  margin-bottom: 8px;
  color: black;
}

.modal-message {
  font-size: 16px; 
  color: black; 
  margin-bottom: 24px;
}
</style>