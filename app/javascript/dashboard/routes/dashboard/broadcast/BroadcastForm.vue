<template>
  <div class="w-full h-full p-6 overflow-y-auto bg-slate-50 dark:bg-slate-900 custom-scrollbar">
    <div class="max-w-[1400px] mx-auto flex flex-col lg:flex-row gap-6 items-start pb-20">

      <!-- KOLOM KIRI: FORMULIR -->
      <div class="flex-1 w-full bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden relative">

        <div class="p-6 border-b border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800">
          <h2 class="text-2xl font-bold text-slate-800 dark:text-slate-100">
            {{ $t('BROADCAST.ADD_TITLE') }}
          </h2>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
            {{ $t('BROADCAST.SUBTITLE') }}
          </p>
        </div>

        <form @submit.prevent="submitBroadcast" class="p-8">

          <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
            <div>
              <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                {{ $t('BROADCAST.INBOX_LABEL') }}
              </label>
              <multiselect
                v-model="selectedInbox"
                :options="whatsappInboxes"
                track-by="id"
                label="name"
                :placeholder="$t('BROADCAST.INBOX_PLACEHOLDER')"
                :searchable="true"
                :allow-empty="false"
                select-label=""
                deselect-label=""
                class="w-full uniform-dropdown"
              >
                <template slot="noResult">{{ $t('BROADCAST.INBOX_NO_RESULT') }}</template>
              </multiselect>
            </div>

            <div>
              <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                {{ $t('BROADCAST.LABEL_TARGET') }}
              </label>
              <multiselect
                v-model="selectedLabel"
                :options="labelOptions"
                track-by="value"
                label="label"
                :placeholder="$t('BROADCAST.ALL_CONTACTS')"
                :searchable="true"
                :allow-empty="false"
                select-label=""
                deselect-label=""
                class="w-full uniform-dropdown"
              >
                <template slot="noResult">{{ $t('BROADCAST.LABEL_NO_RESULT') }}</template>
              </multiselect>
            </div>
          </div>

          <!-- Template Pesan Cepat -->
          <div class="mb-8 p-5 bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-800/50 rounded-xl">
            <label class="block text-sm font-semibold text-blue-800 dark:text-blue-300 mb-3 flex items-center gap-2">
              <span class="i-lucide-book-template w-5 h-5"></span>
              {{ $t('BROADCAST.TEMPLATE_LABEL') }}
            </label>
            <multiselect
              v-model="selectedTemplate"
              :options="messageTemplates"
              track-by="id"
              label="name"
              :placeholder="$t('BROADCAST.TEMPLATE_PLACEHOLDER')"
              :searchable="true"
              :allow-empty="true"
              select-label=""
              deselect-label=""
              class="w-full uniform-dropdown template-dropdown"
              @select="applyTemplate"
            >
              <template slot="noResult">{{ $t('BROADCAST.TEMPLATE_NO_RESULT') }}</template>
            </multiselect>
          </div>

          <!-- Editor Pesan & Baris Variabel -->
          <div class="mb-8">
            <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
              {{ $t('BROADCAST.MESSAGE_LABEL') }}
            </label>

            <!-- Baris Sisipkan Variabel -->
            <div class="mb-3 flex flex-wrap items-center gap-2.5">
              <span class="text-sm font-semibold text-slate-600 dark:text-slate-400 mr-1">
                {{ $t('BROADCAST.INSERT_VARIABLE') }}:
              </span>

              <!-- Variabel bawaan -->
              <button type="button" @click="insertVariable('{{full_name}}')" class="var-chip">
                {{ $t('BROADCAST.VAR_FULL_NAME') }}
              </button>
              <button type="button" @click="insertVariable('{{first_name}}')" class="var-chip">
                {{ $t('BROADCAST.VAR_FIRST_NAME') }}
              </button>
              <button type="button" @click="insertVariable('{{phone_number}}')" class="var-chip">
                {{ $t('BROADCAST.VAR_PHONE') }}
              </button>

              <!-- Variabel kustom (style identik dengan bawaan) -->
              <button
                v-for="customVar in customVariablesList"
                :key="customVar"
                type="button"
                @click="insertVariable('{{' + customVar + '}}')"
                class="var-chip"
              >
                {{ formatVarName(customVar) }}
              </button>

              <!-- Tombol tambah variabel baru -->
              <button
                type="button"
                @click="openVariableModal"
                class="px-2 py-1.5 text-xs font-medium text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200 flex items-center gap-1 ml-1 transition-colors focus:outline-none"
              >
                <span class="i-lucide-plus w-4 h-4"></span>
                {{ $t('BROADCAST.NEW_VARIABLE') }}
              </button>
            </div>

            <!-- Editor (wrapper menyembunyikan duplikat variabel bawaan dari komponen) -->
            <div class="hide-builtin-variables">
              <MessageEditor v-model="form.message_body" :show-variables="false" />
            </div>

            <div class="mt-3 flex justify-end">
              <button
                type="button"
                @click="openTemplateModal"
                :disabled="!form.message_body.trim()"
                class="text-xs font-medium text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 flex items-center gap-1.5 disabled:opacity-50 disabled:cursor-not-allowed transition-colors focus:outline-none"
              >
                <span class="i-lucide-save w-4 h-4"></span>
                {{ $t('BROADCAST.SAVE_AS_TEMPLATE') }}
              </button>
            </div>
          </div>

          <!-- Pengaturan Lanjutan -->
          <div class="mb-8 p-6 bg-slate-50 dark:bg-slate-900/50 rounded-xl border border-slate-200 dark:border-slate-700">
            <h3 class="text-sm font-bold mb-5 uppercase tracking-wider text-slate-500 dark:text-slate-400 flex items-center gap-2">
              <span class="i-lucide-settings-2 w-4 h-4"></span>
              {{ $t('BROADCAST.ADVANCED_SETTINGS') }}
            </h3>

            <div class="flex flex-col gap-5">
              <label class="flex items-start gap-3 cursor-pointer group">
                <input type="checkbox" v-model="form.spin_text_enabled" class="mt-0.5 w-4 h-4 text-green-600 rounded border-slate-300 focus:ring-green-600" />
                <div class="text-sm">
                  <span class="font-medium text-slate-700 dark:text-slate-300 group-hover:text-green-600 transition-colors">
                    {{ $t('BROADCAST.SPIN_TEXT_LABEL') }}
                  </span>
                  <p class="text-slate-500 text-xs mt-1">{{ $t('BROADCAST.SPIN_TEXT_DESC') }}</p>
                </div>
              </label>

              <label class="flex items-start gap-3 cursor-pointer group">
                <input type="checkbox" v-model="form.unsubscribe_link_enabled" class="mt-0.5 w-4 h-4 text-green-600 rounded border-slate-300 focus:ring-green-600" />
                <div class="text-sm">
                  <span class="font-medium text-slate-700 dark:text-slate-300 group-hover:text-green-600 transition-colors">
                    {{ $t('BROADCAST.UNSUBSCRIBE_LABEL') }}
                  </span>
                  <p class="text-slate-500 text-xs mt-1">{{ $t('BROADCAST.UNSUBSCRIBE_DESC') }}</p>
                </div>
              </label>
            </div>
          </div>

          <!-- Tombol Aksi -->
          <div class="flex justify-end items-center gap-3 pt-6 border-t border-slate-200 dark:border-slate-700">
            <button
              type="button"
              class="inline-flex justify-center rounded-lg bg-white dark:bg-transparent px-4 py-2 text-sm font-semibold text-slate-900 dark:text-slate-300 shadow-sm ring-1 ring-inset ring-slate-300 dark:ring-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none"
              @click="goBack"
            >
              {{ $t('BROADCAST.BTN_CANCEL') }}
            </button>

            <button
              type="button"
              class="inline-flex items-center space-x-2 border-2 border-red-600 hover:border-red-700 dark:border-red-400 dark:hover:border-red-500 text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-red-50 dark:hover:bg-red-900/20 focus:outline-none"
              @click="resetForm"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>
              <span>{{ $t('BROADCAST.BTN_RESET') }}</span>
            </button>

            <button
              type="submit"
              class="inline-flex items-center justify-center space-x-2 bg-green-600 text-white rounded-md hover:bg-green-700 px-6 py-2 text-sm font-semibold shadow-sm transition-colors focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
              :disabled="isSubmitting || !isFormValid"
            >
              <svg v-if="isSubmitting" class="animate-spin w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
              </svg>
              <span>{{ $t('BROADCAST.BTN_SUBMIT') }}</span>
            </button>
          </div>
        </form>
      </div>

      <!-- KOLOM KANAN: WHATSAPP PREVIEW -->
      <div class="w-full lg:w-[400px] xl:w-[420px] shrink-0 sticky top-6">
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden flex flex-col h-[calc(100vh-6rem)] min-h-[500px] max-h-[850px]">

          <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 flex items-center gap-2">
            <span class="i-lucide-smartphone w-5 h-5 text-green-600"></span>
            <h3 class="font-semibold text-slate-800 dark:text-slate-100">{{ $t('BROADCAST.PREVIEW_TITLE') }}</h3>
          </div>

          <div class="flex-1 bg-slate-100 dark:bg-[#0b141a] p-4 flex flex-col items-center justify-center relative overflow-hidden">
            <div class="absolute inset-0 opacity-10 dark:opacity-5 pointer-events-none" style="background-image: url('https://w0.peakpx.com/wallpaper/818/148/HD-wallpaper-whatsapp-background-solid-color-thumbnail.jpg'); background-size: cover;"></div>

            <div class="w-full max-w-[340px] bg-[#efeae2] dark:bg-[#0b141a] border border-slate-300 dark:border-slate-600 rounded-[2rem] overflow-hidden shadow-xl relative z-10 flex flex-col h-full max-h-[600px]">

              <div class="bg-[#00a884] dark:bg-[#202c33] px-4 py-3 flex items-center gap-3 text-white shrink-0">
                <div class="w-9 h-9 bg-white/20 rounded-full flex items-center justify-center overflow-hidden">
                  <span class="i-lucide-user w-5 h-5"></span>
                </div>
                <div>
                  <h4 class="font-semibold text-[15px] leading-tight">{{ $t('BROADCAST.PREVIEW_CONTACT_NAME') }}</h4>
                  <p class="text-[11px] opacity-90 mt-0.5">{{ $t('BROADCAST.PREVIEW_ONLINE') }}</p>
                </div>
              </div>

              <div class="flex-1 p-4 overflow-y-auto flex flex-col gap-2 relative scrollbar-hide">
                <div class="bg-[#d9fdd3] dark:bg-[#005c4b] text-[#111b21] dark:text-[#e9edef] p-2.5 pt-2 rounded-lg rounded-tr-none max-w-[92%] self-end shadow-sm relative">
                  <p class="text-[14.2px] whitespace-pre-wrap leading-[1.35] font-sans">{{ formattedPreviewMessage }}</p>
                  <div class="flex items-center justify-end gap-1 mt-1 -mb-1 float-right clear-both ml-3">
                    <span class="text-[11px] text-slate-500 dark:text-[#8696a0]">14:00</span>
                    <span class="i-lucide-check-check w-[14px] h-[14px] text-[#53bdeb]"></span>
                  </div>
                </div>
              </div>

              <div class="bg-[#f0f2f5] dark:bg-[#202c33] p-2.5 flex items-center gap-2 shrink-0">
                <div class="flex-1 bg-white dark:bg-[#2a3942] rounded-full h-10 border border-transparent flex items-center px-4">
                  <span class="text-[#8696a0] text-sm">{{ $t('BROADCAST.PREVIEW_INPUT_PLACEHOLDER') }}</span>
                </div>
                <div class="w-10 h-10 rounded-full bg-[#00a884] flex items-center justify-center text-white shrink-0">
                  <span class="i-lucide-mic w-5 h-5" :aria-label="$t('BROADCAST.PREVIEW_MIC_ARIA')"></span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- MODAL 1: TAMBAH VARIABEL KUSTOM -->
    <transition name="modal-fade">
      <div
        v-if="showVariableModal"
        class="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4"
        role="dialog"
        :aria-label="$t('BROADCAST.MODAL_VAR_TITLE')"
        aria-modal="true"
      >
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-2xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700">
          <div class="p-5 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center">
            <h3 class="font-bold text-lg text-slate-800 dark:text-white">{{ $t('BROADCAST.MODAL_VAR_TITLE') }}</h3>
            <button
              @click="closeVariableModal"
              class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 focus:outline-none"
              :aria-label="$t('BROADCAST.CLOSE')"
            >
              <span class="i-lucide-x w-5 h-5 block"></span>
            </button>
          </div>
          <div class="p-5">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('BROADCAST.MODAL_VAR_INPUT_LABEL') }}
            </label>
            <input
              ref="varInput"
              v-model="newVariableName"
              type="text"
              :placeholder="$t('BROADCAST.MODAL_VAR_PLACEHOLDER')"
              class="w-full px-4 py-2.5 bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-100 outline-none focus:ring-2 focus:ring-green-600 focus:border-green-600 transition-shadow"
              @keyup.enter="confirmAddVariable"
            >
            <p v-if="variableNameError" class="text-xs text-red-500 mt-2">{{ variableNameError }}</p>
            <p v-else class="text-xs text-slate-500 mt-2">{{ $t('BROADCAST.MODAL_VAR_HINT') }}</p>
          </div>
          <div class="p-4 bg-slate-50 dark:bg-slate-900/50 flex justify-end gap-3 border-t border-slate-200 dark:border-slate-700">
            <button @click="closeVariableModal" class="inline-flex justify-center rounded-lg bg-white dark:bg-transparent px-4 py-2 text-sm font-semibold text-slate-900 dark:text-slate-300 shadow-sm ring-1 ring-inset ring-slate-300 dark:ring-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none">
              {{ $t('BROADCAST.BTN_CANCEL') }}
            </button>
            <button @click="confirmAddVariable" :disabled="!newVariableName.trim() || !!variableNameError" class="inline-flex w-full justify-center bg-green-600 text-white rounded-md hover:bg-green-700 px-4 py-2 text-sm font-semibold shadow-sm sm:w-auto transition-colors disabled:opacity-50 focus:outline-none">
              {{ $t('BROADCAST.MODAL_VAR_BTN_CONFIRM') }}
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- MODAL 2: SIMPAN TEMPLATE -->
    <transition name="modal-fade">
      <div
        v-if="showTemplateModal"
        class="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4"
        role="dialog"
        :aria-label="$t('BROADCAST.MODAL_TPL_TITLE')"
        aria-modal="true"
      >
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-2xl w-full max-w-md overflow-hidden border border-slate-200 dark:border-slate-700">
          <div class="p-5 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center">
            <h3 class="font-bold text-lg text-slate-800 dark:text-white">{{ $t('BROADCAST.MODAL_TPL_TITLE') }}</h3>
            <button
              @click="closeTemplateModal"
              class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 focus:outline-none"
              :aria-label="$t('BROADCAST.CLOSE')"
            >
              <span class="i-lucide-x w-5 h-5 block"></span>
            </button>
          </div>
          <div class="p-5">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('BROADCAST.MODAL_TPL_INPUT_LABEL') }}
            </label>
            <input
              ref="tplInput"
              v-model="newTemplateName"
              type="text"
              :placeholder="$t('BROADCAST.MODAL_TPL_PLACEHOLDER')"
              class="w-full px-4 py-2.5 bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-100 outline-none focus:ring-2 focus:ring-green-600 focus:border-green-600 transition-shadow"
              @keyup.enter="confirmSaveTemplate"
            >
          </div>
          <div class="p-4 bg-slate-50 dark:bg-slate-900/50 flex justify-end gap-3 border-t border-slate-200 dark:border-slate-700">
            <button @click="closeTemplateModal" class="inline-flex justify-center rounded-lg bg-white dark:bg-transparent px-4 py-2 text-sm font-semibold text-slate-900 dark:text-slate-300 shadow-sm ring-1 ring-inset ring-slate-300 dark:ring-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none">
              {{ $t('BROADCAST.BTN_CANCEL') }}
            </button>
            <button @click="confirmSaveTemplate" :disabled="!newTemplateName.trim()" class="inline-flex w-full justify-center bg-green-600 text-white rounded-md hover:bg-green-700 px-4 py-2 text-sm font-semibold shadow-sm sm:w-auto transition-colors disabled:opacity-50 focus:outline-none">
              {{ $t('BROADCAST.MODAL_TPL_BTN_CONFIRM') }}
            </button>
          </div>
        </div>
      </div>
    </transition>

  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import Multiselect from 'vue-multiselect';
import MessageEditor from './components/MessageEditor.vue';

// Regex untuk validasi nama variabel: harus diawali huruf/underscore, hanya alphanumeric + underscore
const VALID_VAR_NAME = /^[a-z_][a-z0-9_]*$/;

export default {
  name: 'BroadcastForm',
  components: { MessageEditor, Multiselect },

  data() {
    return {
      isSubmitting: false,

      showTemplateModal: false,
      newTemplateName: '',

      showVariableModal: false,
      newVariableName: '',
      customVariablesList: [],

      selectedInbox: null,
      selectedLabel: null, // diinisialisasi di created() agar $t() tersedia
      selectedTemplate: null,

      form: {
        message_body: '',
        spin_text_enabled: false,
        unsubscribe_link_enabled: false,
      },

      // NOTE: Dalam implementasi nyata, daftar ini harus di-fetch dari store/API
      // agar tidak hilang saat refresh halaman.
      messageTemplates: [
        {
          id: 1,
          name: '🎂 Ucapan Ulang Tahun',
          content: 'Halo {{full_name}}! 🎉\n\nSelamat ulang tahun! Semoga panjang umur dan sehat selalu.\n\nSebagai hadiah spesial, tunjukkan pesan ini di kasir untuk Diskon 20% hari ini!',
        },
        {
          id: 2,
          name: '🚀 Info Promo & Diskon',
          // Spin syntax [A|B] hanya valid di dalam tanda kurung siku yang BUKAN placeholder var kustom
          content: '[Halo|Hai|Selamat Pagi] Kak {{first_name}},\n\nJangan lewatkan promo Beli 1 Gratis 1 untuk semua produk pilihan!\n\nPromo berlaku sampai besok. Buruan sebelum kehabisan!',
        },
      ],
    };
  },

  computed: {
    ...mapGetters({
      inboxes: 'inboxes/getInboxes',
      labels: 'labels/getLabels',
    }),

    whatsappInboxes() {
      const allowedChannels = [
        'Channel::Whatsapp',
        'Channel::WhatsappUnofficial',
        'Channel::Api',
      ];
      return this.inboxes.filter(inbox =>
        allowedChannels.includes(inbox.channel_type)
      );
    },

    labelOptions() {
      const all = [{ label: this.$t('BROADCAST.ALL_CONTACTS'), value: 'all' }];
      if (this.labels?.length) {
        this.labels.forEach(label => {
          // Gunakan `title` sebagai field canonical; fallback ke `name` untuk backward compat
          const title = label.title || label.name;
          all.push({ label: `${this.$t('BROADCAST.LABEL_PREFIX')}: ${title}`, value: title });
        });
      }
      return all;
    },

    isFormValid() {
      return this.selectedInbox !== null && this.form.message_body.trim() !== '';
    },

    /**
     * Validasi nama variabel secara realtime saat user mengetik di modal.
     * Mengembalikan pesan error atau string kosong jika valid.
     */
    variableNameError() {
      const raw = this.newVariableName.trim();
      if (!raw) return '';
      const sanitized = raw.toLowerCase().replace(/\s+/g, '_');
      if (!VALID_VAR_NAME.test(sanitized)) {
        return this.$t('BROADCAST.MODAL_VAR_ERROR_INVALID');
      }
      if (this.customVariablesList.includes(sanitized)) {
        return this.$t('BROADCAST.MODAL_VAR_ERROR_DUPLICATE');
      }
      return '';
    },

    formattedPreviewMessage() {
      let text = this.form.message_body;

      if (!text?.trim()) {
        return this.$t('BROADCAST.PREVIEW_EMPTY');
      }

      // URUTAN PENTING:
      // 1. Proses spin text SEBELUM substitusi variabel agar regex [A|B] tidak
      //    bertabrakan dengan format placeholder custom var ⟨nama var⟩ di bawah.
      if (this.form.spin_text_enabled) {
        text = text.replace(/\[([^\[\]]+)\]/g, (_, group) => group.split('|')[0]);
      }

      // 2. Substitusi variabel bawaan
      text = text
        .replace(/\{\{full_name\}\}/g, 'Budi Santoso')
        .replace(/\{\{first_name\}\}/g, 'Budi')
        .replace(/\{\{phone_number\}\}/g, '+6281234567890');

      // 3. Custom variable ditampilkan dengan format ⟨nama var⟩ (tidak ambigu dengan spin syntax)
      text = text.replace(/\{\{([^}]+)\}\}/g, (_, varName) => {
        return `⟨${varName.replace(/_/g, ' ')}⟩`;
      });

      // 4. Append unsubscribe footer
      if (this.form.unsubscribe_link_enabled) {
        text += `\n\n---\n${this.$t('BROADCAST.UNSUBSCRIBE_FOOTER')}`;
      }

      return text;
    },
  },

  created() {
    // Inisialisasi di created() agar $t() sudah tersedia (bukan di data())
    this.selectedLabel = { label: this.$t('BROADCAST.ALL_CONTACTS'), value: 'all' };
  },

  mounted() {
    this.$store.dispatch('inboxes/get');
    this.$store.dispatch('labels/get');
  },

  methods: {
    goBack() {
      this.$router.push({ name: 'blasting_index' });
    },

    resetForm() {
      this.form = { message_body: '', spin_text_enabled: false, unsubscribe_link_enabled: false };
      this.selectedInbox = null;
      this.selectedLabel = { label: this.$t('BROADCAST.ALL_CONTACTS'), value: 'all' };
      this.selectedTemplate = null;
    },

    applyTemplate(selectedOption) {
      if (selectedOption) {
        this.form.message_body = selectedOption.content;
      }
    },

    // ---- Modal: Variabel Kustom ----

    openVariableModal() {
      this.newVariableName = '';
      this.showVariableModal = true;
      this.$nextTick(() => this.$refs.varInput?.focus());
    },

    closeVariableModal() {
      this.showVariableModal = false;
    },

    confirmAddVariable() {
      if (this.variableNameError) return;

      const varName = this.newVariableName.trim().toLowerCase().replace(/\s+/g, '_');
      if (!varName || !VALID_VAR_NAME.test(varName)) return;

      if (!this.customVariablesList.includes(varName)) {
        this.customVariablesList.push(varName);
      }
      this.insertVariable(`{{${varName}}}`);
      this.closeVariableModal();
    },

    /**
     * Append variabel ke body pesan.
     * NOTE: Idealnya emit event ke MessageEditor agar insert di posisi kursor.
     * Saat ini MessageEditor tidak mengekspos insertAtCursor(), jadi append ke akhir
     * dengan spasi yang rapi adalah tradeoff yang disengaja.
     */
    insertVariable(variableStr) {
      const body = this.form.message_body;
      const needsLeadingSpace = body.length > 0 && !body.endsWith(' ') && !body.endsWith('\n');
      this.form.message_body = body + (needsLeadingSpace ? ' ' : '') + variableStr + ' ';
    },

    formatVarName(varName) {
      return varName
        .split('_')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');
    },

    // ---- Modal: Simpan Template ----

    openTemplateModal() {
      this.newTemplateName = '';
      this.showTemplateModal = true;
      this.$nextTick(() => this.$refs.tplInput?.focus());
    },

    closeTemplateModal() {
      this.showTemplateModal = false;
    },

    confirmSaveTemplate() {
      const name = this.newTemplateName.trim();
      if (!name) return;

      const newTemplate = {
        id: Date.now(),
        name: `💾 ${name}`,
        content: this.form.message_body,
      };

      this.messageTemplates.push(newTemplate);
      this.selectedTemplate = newTemplate;

      // NOTE: Template saat ini hanya disimpan di local state dan hilang saat refresh.
      // Untuk persistensi, dispatch ke store: this.$store.dispatch('broadcasts/saveTemplate', newTemplate)
      window.bus?.$emit(
        'new-toast-message',
        this.$t('BROADCAST.TEMPLATE_SAVED_TOAST', { name })
      );

      this.closeTemplateModal();
    },

    // ---- Submit ----

    async submitBroadcast() {
      if (!this.isFormValid) return;
      this.isSubmitting = true;

      try {
        const payload = {
          inbox_id: this.selectedInbox.id,
          target_segment: this.selectedLabel.value,
          message_body: this.form.message_body,
          spin_text_enabled: this.form.spin_text_enabled,
          unsubscribe_link_enabled: this.form.unsubscribe_link_enabled,
        };

        await this.$store.dispatch('broadcasts/create', payload);

        window.bus?.$emit('new-toast-message', this.$t('BROADCAST.SUCCESS_MESSAGE'));
        this.goBack();
      } catch {
        window.bus?.$emit('new-toast-message', this.$t('BROADCAST.ERROR_MESSAGE'));
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<style scoped>
  /* Animasi Modal */
  .modal-fade-enter-active,
  .modal-fade-leave-active {
    transition: opacity 0.2s ease, transform 0.2s ease;
  }
  .modal-fade-enter,
  .modal-fade-leave-to {
    opacity: 0;
    transform: scale(0.95);
  }

  /* Chip variabel: digunakan berulang oleh variabel bawaan dan kustom */
  .var-chip {
    @apply px-3 py-1.5 text-xs font-medium bg-transparent border border-slate-300 dark:border-slate-600 rounded-md text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors focus:outline-none;
  }

  .custom-scrollbar::-webkit-scrollbar {
    width: 8px;
  }
  .custom-scrollbar::-webkit-scrollbar-track {
    background: transparent;
  }
  .custom-scrollbar::-webkit-scrollbar-thumb {
    background-color: #cbd5e1;
    border-radius: 20px;
  }
  .dark .custom-scrollbar::-webkit-scrollbar-thumb {
    background-color: #475569;
  }

  .uniform-dropdown {
    @apply text-sm text-slate-700 dark:text-slate-200;
  }
  :deep(.uniform-dropdown .multiselect__tags) {
    @apply bg-white dark:bg-slate-900 border-slate-300 dark:border-slate-600 rounded-lg;
    min-height: 44px;
    padding-top: 10px;
    padding-bottom: 10px;
  }
  :deep(.uniform-dropdown .multiselect__input) {
    @apply bg-transparent dark:text-white pt-0.5;
  }
  :deep(.uniform-dropdown .multiselect__single) {
    @apply bg-transparent dark:text-white mt-0.5;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 90%;
  }
  :deep(.uniform-dropdown .multiselect__content-wrapper) {
    @apply bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 z-50 rounded-lg shadow-lg mt-1;
  }

  :deep(.template-dropdown .multiselect__tags) {
    border-color: #16a34a;
  }

  :deep(.multiselect__option--highlight) {
    background-color: #16a34a !important;
    color: #ffffff !important;
  }
  :deep(.multiselect__option--selected.multiselect__option--highlight) {
    background-color: #15803d !important;
  }

  .scrollbar-hide::-webkit-scrollbar {
    display: none;
  }
  .scrollbar-hide {
    -ms-overflow-style: none;
    scrollbar-width: none;
  }

  :deep(.hide-builtin-variables label),
  :deep(.hide-builtin-variables .variables-container),
  :deep(.hide-builtin-variables .toolbar),
  :deep(.hide-builtin-variables .flex.gap-2) {
    display: none !important;
  }
</style>