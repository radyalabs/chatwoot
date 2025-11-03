<template>
  <div class="settings--content">
    <h2 class="text-lg font-semibold mb-4">Konfigurasi Penomoran Otomatis</h2>
    <div class="card p-4 space-y-4">
      
      <div>
        <label>Format Penomoran <span class="text-red-500">*</span></label>
        <div class="flex gap-2">
          <input v-model="form.format" type="text" class="input flex-1"/>
          <select v-model="codeOption" class="input w-80" @change="addCode">
            <option value="" disabled selected hidden>Tambah Kode Penomoran</option>

            <option value="[NUMBER]">Nomor Urut (1 - 10000)</option>
            <option value="[MONTH]">Bulan (01 - 12)</option>
            <option value="[MONTH_ROMAN]">Bulan Romawi (I - XII)</option>
            <option value="[MONTH_SHORT]">Bulan (JAN - DES)</option>
            <option value="[MONTH_LONG]">Bulan (JANUARI - DESEMBER)</option>
            <option value="[YEAR_SHORT]">Tahun (contoh: 25)</option>
            <option value="[YEAR]">Tahun (contoh: 2025)</option>
          </select>
        </div>
        <p class="text-md text-gray-400 mt-1">Contoh Output: {{ liveSampleOutput }}</p>
      </div>

      <div>
        <label>Nomor Saat Ini <span class="text-red-500">*</span></label>
        <input v-model.number="form.currentNumber" type="number" class="input w-full" min="0" />
      </div>

      <div>
        <label>Reset Nomor Setiap</label>
        <div class="space-y-1">
          <label><input type="radio" value="never" v-model="form.resetEvery" /> Tidak pernah reset</label><br />
          <label><input type="radio" value="month" v-model="form.resetEvery" /> Setiap bulan</label><br />
          <label><input type="radio" value="year" v-model="form.resetEvery" /> Setiap tahun</label>
        </div>
      </div>

      <div class="flex justify-end mt-4">
        <button class="button primary" @click="onSave" :disabled="loading">
          <span v-if="!loading">Simpan</span>
          <span v-else>Menunggu...</span>
        </button>
      </div>
      <div v-if="showSuccessModal" class="success-modal-overlay" @click.self="closeSuccessModal">
          <div class="success-modal-content">
            
            <div class="modal-icon-wrapper">
              <svg class="modal-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
              </svg>
            </div>

            <h2 class="modal-title">Sukses!</h2>
            <p class="modal-message">Data format penomoran berhasil disimpan.</p>

            <button class="button primary" @click="closeSuccessModal">
              Tutup
            </button>

        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { mapState, mapGetters, mapActions } from 'vuex';

export default {
  name: 'AutoNumbering',
  data() {
    return {
      form: {
        id: null,
        format: '[NUMBER]/[MONTH]/[YEAR]',
        currentNumber: 1,
        resetEvery: 'never',
      },
      codeOption: '',
      showSuccessModal: false,
    };
  },
  computed: {
    ...mapState('numberFormatConfig', {
      configFromStore: state => state.config,
      loading: state => state.loading,
    }),
    ...mapGetters('numberFormatConfig', [
      'errorMessage',
    ]),

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
      
      const number = String(this.form.currentNumber || 0).padStart(5, '0');
      return this.form.format
        .replace(/\[NUMBER\]/g, number)
        .replace(/\[YEAR\]/g, year)
        .replace(/\[YEAR_SHORT\]/g, yearShort)
        .replace(/\[MONTH\]/g, monthNum)
        .replace(/\[MONTH_ROMAN\]/g, roman[monthIndex])
        .replace(/\[MONTH_SHORT\]/g, shortMonths[monthIndex])
        .replace(/\[MONTH_LONG\]/g, longMonths[monthIndex]);
    },
  },
  watch: {
    configFromStore(newConfig) {
      if (newConfig) {
        this.form = { ...newConfig };
      }
    },
  },
  methods: {
    ...mapActions('numberFormatConfig', [
      'fetchConfig',
      'saveConfig',
    ]),

    addCode() {
      const token = this.codeOption;
      if (!token) return;
      this.form.format = this.form.format + token;
      this.codeOption = '';
    },

    async onSave() {
      try {
        await this.saveConfig(this.form);
        this.showSuccessModal = true; 
      } catch (error) {
        console.error("Mohon maaf, Format belum berhasil disimpan");
      }
    },
    
    closeSuccessModal() {
      this.showSuccessModal = false;
    },
  },
  async mounted() {
    await this.fetchConfig();
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