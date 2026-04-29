<template>
  <div class="flex-1 overflow-auto p-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
    <div class="max-w-4xl mx-auto bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
      
      <!-- Header -->
      <div class="p-6 border-b border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800">
        <h2 class="text-2xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('BROADCAST.ADD_TITLE') }}
        </h2>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ $t('BROADCAST.ADD_DESC') }}
        </p>
      </div>

      <!-- Formulir -->
      <form @submit.prevent="submitBroadcast" class="p-6">
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          
          <!-- Pilih Inbox Sender (Sekarang Menggunakan Multiselect) -->
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
              class="w-full"
            >
              <template slot="noResult">{{ $t('BROADCAST.INBOX_EMPTY') }}</template>
            </multiselect>
            
            <p v-if="whatsappInboxes.length === 0" class="text-xs text-red-500 mt-2 flex items-center gap-1">
              <span class="i-lucide-alert-circle w-4 h-4"></span>
              {{ $t('BROADCAST.INBOX_EMPTY') }}
            </p>
          </div>

          <!-- Target Segmen / Label (Multiselect) -->
          <div>
            <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('BROADCAST.TARGET_LABEL') }}
            </label>
            <multiselect
              v-model="selectedLabel"
              :options="labelOptions"
              track-by="value"
              label="label"
              placeholder="Ketik untuk mencari segmen..."
              :searchable="true"
              :allow-empty="false"
              select-label=""
              deselect-label=""
              class="w-full"
            >
              <template slot="noResult">Label tidak ditemukan.</template>
            </multiselect>
          </div>
          
        </div>

        <!-- Bagian 2: Editor Pesan -->
        <div class="mb-8">
          <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
            {{ $t('BROADCAST.MESSAGE_LABEL') }}
          </label>
          <MessageEditor v-model="form.message_body" />
        </div>

        <!-- Bagian 3: Fitur Lanjutan -->
        <div class="mb-8 p-5 bg-slate-50 dark:bg-slate-900/50 rounded-lg border border-slate-200 dark:border-slate-700">
          <h3 class="text-sm font-bold mb-4 uppercase tracking-wider text-slate-500 dark:text-slate-400">
            {{ $t('BROADCAST.ADVANCED_SETTINGS') }}
          </h3>
          
          <div class="flex flex-col gap-4">
            <label class="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" v-model="form.spin_text_enabled" class="w-4 h-4 text-woot-500 rounded border-slate-300 focus:ring-woot-500" />
              <div class="text-sm">
                <span class="font-medium text-slate-700 dark:text-slate-300">{{ $t('BROADCAST.SPIN_TEXT_LABEL') }}</span>
                <p class="text-slate-500 text-xs">{{ $t('BROADCAST.SPIN_TEXT_DESC') }}</p>
              </div>
            </label>

            <label class="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" v-model="form.unsubscribe_link_enabled" class="w-4 h-4 text-woot-500 rounded border-slate-300 focus:ring-woot-500" />
              <div class="text-sm">
                <span class="font-medium text-slate-700 dark:text-slate-300">{{ $t('BROADCAST.UNSUBSCRIBE_LABEL') }}</span>
                <p class="text-slate-500 text-xs">{{ $t('BROADCAST.UNSUBSCRIBE_DESC') }}</p>
              </div>
            </label>
          </div>
        </div>

        <!-- Tombol Aksi -->
        <div class="flex justify-end items-center gap-3 pt-6 border-t border-slate-200 dark:border-slate-700">
          <button type="button" class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:text-slate-900 focus:outline-none" @click="goBack">
            {{ $t('BROADCAST.CANCEL') }}
          </button>
          
          <button type="button" class="px-4 py-2 text-sm font-medium text-slate-700 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-md hover:bg-slate-50 focus:outline-none" @click="resetForm">
            {{ $t('BROADCAST.RESET') }}
          </button>
          
          <button type="submit" class="px-6 py-2 text-sm font-medium text-white !bg-emerald-500 rounded-md hover:!bg-emerald-600 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2" :disabled="isSubmitting || !isFormValid">
            <span v-if="isSubmitting" class="i-lucide-loader-2 animate-spin w-4 h-4"></span>
            <span v-else class="i-lucide-send w-4 h-4"></span>
            {{ $t('BROADCAST.SUBMIT') }}
          </button>
        </div>

      </form>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import Multiselect from 'vue-multiselect';
import MessageEditor from './components/MessageEditor.vue';

export default {
  name: 'BroadcastForm',
  components: {
    MessageEditor,
    Multiselect,
  },
  data() {
    return {
      isSubmitting: false,
      selectedInbox: null, // Variabel baru untuk menampung objek inbox yang dipilih
      selectedLabel: { label: 'Semua Kontak', value: 'all' },
      form: {
        message_body: '',
        spin_text_enabled: false,
        unsubscribe_link_enabled: false,
      },
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
        'Channel::TwilioSms',
        'Channel::Api'
      ];
      return this.inboxes.filter(inbox => allowedChannels.includes(inbox.channel_type));
    },

    labelOptions() {
      const options = [{ label: 'Semua Kontak', value: 'all' }];
      if (this.labels && this.labels.length > 0) {
        this.labels.forEach(label => {
          options.push({ 
            label: `Label: ${label.title || label.name}`, 
            value: label.title || label.name 
          });
        });
      }
      return options;
    },

    isFormValid() {
      // Tombol submit aktif jika Inbox sudah dipilih (tidak null) dan pesan tidak kosong
      return this.selectedInbox !== null && this.form.message_body.trim() !== '';
    }
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
      this.form = {
        message_body: '',
        spin_text_enabled: false,
        unsubscribe_link_enabled: false,
      };
      this.selectedInbox = null; // Reset multiselect inbox
      this.selectedLabel = { label: 'Semua Kontak', value: 'all' }; // Reset multiselect label
    },
    async submitBroadcast() {
      this.isSubmitting = true;
      try {
        // Susun Payload
        const payload = {
          inbox_id: this.selectedInbox.id, // Ambil properti id dari objek multiselect inbox
          target_segment: this.selectedLabel.value, // Ambil properti value dari multiselect label
          message_body: this.form.message_body,
          spin_text_enabled: this.form.spin_text_enabled,
          unsubscribe_link_enabled: this.form.unsubscribe_link_enabled
        };

        console.log("Payload siap kirim ke backend:", payload);

        // TODO: Backend integration
        // await this.$store.dispatch('broadcasts/create', payload);

        await new Promise(resolve => setTimeout(resolve, 1500));
        
        window.$bus.$emit('global-toast', {
          message: this.$t('BROADCAST.SUCCESS_MESSAGE'),
          type: 'success',
        });
        
        this.goBack();
      } catch (error) {
        window.$bus.$emit('global-toast', {
          message: this.$t('BROADCAST.ERROR_MESSAGE'),
          type: 'error',
        });
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<style scoped>
.multiselect {
  @apply text-sm text-slate-700 dark:text-slate-200;
}
:deep(.multiselect__tags) {
  @apply bg-white dark:bg-slate-900 border-slate-300 dark:border-slate-600 rounded-md pt-2.5 pb-2;
  min-height: 42px;
}
:deep(.multiselect__input) {
  @apply bg-transparent dark:text-white pt-0.5;
}
:deep(.multiselect__single) {
  @apply bg-transparent dark:text-white mt-0.5;
}
:deep(.multiselect__content-wrapper) {
  @apply bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 z-50;
}
:deep(.multiselect__option--highlight) {
  background-color: #10b981 !important; /* Setara dengan bg-emerald-500 */
  color: #ffffff !important;
}
:deep(.multiselect__option--selected.multiselect__option--highlight) {
  background-color: #059669 !important; /* Setara dengan bg-emerald-600 */
}
</style>