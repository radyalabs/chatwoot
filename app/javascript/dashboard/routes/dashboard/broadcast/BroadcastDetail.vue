<template>
  <div class="flex-1 w-full h-full p-8 overflow-y-auto flex flex-col bg-slate-50 dark:bg-slate-900 custom-scrollbar">
    
    <div class="flex flex-col gap-4 mb-8 border-b border-slate-200 dark:border-slate-800 pb-6">
      <button 
        @click="goBack" 
        class="flex items-center gap-2 text-sm font-medium text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-100 w-fit transition-colors focus:outline-none"
      >
        <span class="i-lucide-arrow-left w-4 h-4"></span>
        {{ $t('BROADCAST_DETAIL.BACK') }}
      </button>

      <div class="flex justify-between items-end">
        <div>
          <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100 flex items-center gap-3">
            {{ $t('BROADCAST_DETAIL.TITLE') }} #{{ campaign.id }}
            <span 
              class="px-2.5 py-0.5 rounded-full text-xs font-semibold tracking-wide uppercase border"
              :class="{
                'bg-emerald-100 text-emerald-700 border-emerald-200 dark:bg-emerald-900/30 dark:text-emerald-400 dark:border-emerald-800/50': campaign.status === 'completed',
                'bg-amber-100 text-amber-700 border-amber-200 dark:bg-amber-900/30 dark:text-amber-400 dark:border-amber-800/50': campaign.status === 'processing',
                'bg-rose-100 text-rose-700 border-rose-200 dark:bg-rose-900/30 dark:text-rose-400 dark:border-rose-800/50': campaign.status === 'failed',
                'bg-slate-100 text-slate-700 border-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700': campaign.status === 'draft' || !campaign.status,
              }"
            >
              {{ campaign.status || 'Loading...' }}
            </span>
          </h1>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-2 flex items-center gap-1.5">
            <span class="i-lucide-calendar-clock w-4 h-4"></span>
            {{ $t('BROADCAST_DETAIL.SENT_AT') }}: <span class="font-medium text-slate-700 dark:text-slate-300">{{ formattedDate }}</span>
          </p>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center text-blue-500">
          <span class="i-lucide-send w-6 h-6"></span>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ $t('BROADCAST_DETAIL.METRIC_SENT') }}</p>
          <h3 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ metrics.sent }}</h3>
        </div>
      </div>

      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-emerald-50 dark:bg-emerald-900/20 flex items-center justify-center text-emerald-500">
          <span class="i-lucide-check-check w-6 h-6"></span>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ $t('BROADCAST_DETAIL.METRIC_READ') }}</p>
          <h3 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ metrics.read }}</h3>
        </div>
      </div>

      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-purple-50 dark:bg-purple-900/20 flex items-center justify-center text-purple-500">
          <span class="i-lucide-message-circle-reply w-6 h-6"></span>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ $t('BROADCAST_DETAIL.METRIC_REPLIED') }}</p>
          <h3 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ metrics.replied }}</h3>
        </div>
      </div>

      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-rose-50 dark:bg-rose-900/20 flex items-center justify-center text-rose-500">
          <span class="i-lucide-x-octagon w-6 h-6"></span>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ $t('BROADCAST_DETAIL.METRIC_FAILED') }}</p>
          <h3 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ metrics.failed }}</h3>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      
      <div class="lg:col-span-2 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden">
        <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 flex items-center gap-2">
          <span class="i-lucide-message-square w-4 h-4 text-slate-500"></span>
          <h3 class="font-semibold text-slate-800 dark:text-slate-200">{{ $t('BROADCAST_DETAIL.MESSAGE_PREVIEW') }}</h3>
        </div>
        <div class="p-6">
          <div class="whitespace-pre-wrap text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-[#0b141a] p-5 rounded-xl text-sm leading-relaxed border border-slate-200 dark:border-slate-700/50 relative">
            <div class="absolute inset-0 opacity-5 pointer-events-none rounded-xl" style="background-image: url('https://w0.peakpx.com/wallpaper/818/148/HD-wallpaper-whatsapp-background-solid-color-thumbnail.jpg'); background-size: cover;"></div>
            <div class="relative z-10 font-sans">{{ formattedMessage }}</div>
          </div>
          <p class="text-xs text-slate-500 mt-3 flex items-center gap-1.5">
            <span class="i-lucide-info w-3.5 h-3.5"></span>
            {{ $t('BROADCAST_DETAIL.PREVIEW_HINT') }}
          </p>
        </div>
      </div>

      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden h-fit">
        <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 flex items-center gap-2">
          <span class="i-lucide-info w-4 h-4 text-slate-500"></span>
          <h3 class="font-semibold text-slate-800 dark:text-slate-200">{{ $t('BROADCAST_DETAIL.INFO') }}</h3>
        </div>
        <div class="p-6 flex flex-col gap-5">
          <div>
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 mb-2 uppercase tracking-wider">{{ $t('BROADCAST_DETAIL.TARGET') }}</p>
            <div class="flex flex-wrap gap-2 mt-1">
              <span v-for="(badge, index) in formattedTargetSegments" :key="index" class="px-2.5 py-1.5 bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400 border border-blue-200 dark:border-blue-800/50 rounded-md text-xs font-medium leading-tight">
                {{ badge }}
              </span>
            </div>
          </div>
          <div class="pt-4 border-t border-slate-100 dark:border-slate-700/50">
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 mb-1 uppercase tracking-wider">{{ $t('BROADCAST.INBOX_LABEL') }}</p>
            <p class="font-medium text-sm text-slate-800 dark:text-slate-200 flex items-center gap-2">
              <span class="i-lucide-inbox w-4 h-4 text-green-600"></span>
              {{ campaign.inbox_name || 'Loading...' }}
            </p>
          </div>
          <div class="pt-4 border-t border-slate-100 dark:border-slate-700/50">
            <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 mb-2 uppercase tracking-wider">{{ $t('BROADCAST.ADVANCED_SETTINGS') }}</p>
            <div class="flex flex-wrap gap-2">
              <span v-if="campaign.spin_text_enabled" class="px-2.5 py-1.5 bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 border border-slate-200 dark:border-slate-700 rounded-md text-xs font-medium flex items-center gap-1.5">
                <span class="i-lucide-dices w-3.5 h-3.5"></span> {{ $t('BROADCAST.SPIN_TEXT_ACTIVE') }}
              </span>
              <span v-if="campaign.unsubscribe_link_enabled" class="px-2.5 py-1.5 bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 border border-slate-200 dark:border-slate-700 rounded-md text-xs font-medium flex items-center gap-1.5">
                <span class="i-lucide-link-2-off w-3.5 h-3.5"></span> {{ $t('BROADCAST.UNSUBSCRIBE_ACTIVE') }}
              </span>
              <span v-if="!campaign.spin_text_enabled && !campaign.unsubscribe_link_enabled" class="text-sm text-slate-500 italic">
                {{ $t('BROADCAST.NO_ADVANCED_FEATURES') }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="mt-8 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden flex flex-col min-h-[300px]">
      <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 flex items-center justify-between">
        <h3 class="font-semibold text-slate-800 dark:text-slate-200 flex items-center gap-2">
          <span class="i-lucide-users w-4 h-4 text-slate-500"></span>
          {{ $t('BROADCAST.RECIPIENT_LIST') }}
        </h3>
        <span class="px-2.5 py-1 bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300 rounded text-xs font-medium">
          {{ $t('BROADCAST.TOTAL_CONTACTS') }} {{ isFetchingContacts ? '...' : contactsList.length }} {{ $t('SIDEBAR.CONTACT') }}
        </span>
      </div>
      <div class="relative overflow-x-auto flex-1 custom-scrollbar max-h-[400px]">
        
        <div v-if="isFetchingContacts" class="p-12 flex justify-center">
          <Spinner />
        </div>
        
        <table v-else-if="contactsList.length > 0" class="w-full text-left text-sm text-slate-600 dark:text-slate-400">
          <thead class="bg-slate-50 dark:bg-slate-900/50 text-slate-700 dark:text-slate-300 border-b border-slate-200 dark:border-slate-700 sticky top-0 z-10">
            <tr>
              <th class="px-6 py-3.5 font-semibold">Name</th>
              <th class="px-6 py-3.5 font-semibold">Phone Number</th>
              <th class="px-6 py-3.5 font-semibold">Email</th>
              <th class="px-6 py-3.5 font-semibold">Company</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="contact in contactsList" :key="contact.id" class="border-b border-slate-100 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors">
              <td class="px-6 py-3 font-medium text-slate-800 dark:text-slate-200 flex items-center gap-3">
                <div class="w-8 h-8 rounded-full bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400 flex items-center justify-center font-bold text-xs">
                  {{ contact.name ? contact.name.charAt(0).toUpperCase() : '#' }}
                </div>
                {{ contact.name || 'Unknown' }}
              </td>
              <td class="px-6 py-3">{{ contact.phone_number || '-' }}</td>
              <td class="px-6 py-3">{{ contact.email || '-' }}</td>
              <td class="px-6 py-3">{{ contact.company_name || '-' }}</td>
            </tr>
          </tbody>
        </table>

        <div v-else class="p-12 flex flex-col items-center justify-center text-slate-500 h-full">
          <span class="i-lucide-user-x w-10 h-10 mb-3 opacity-30"></span>
          <p>No recipients found.</p>
        </div>

      </div>
    </div>

  </div>
</template>

<script>
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { mapGetters } from 'vuex';

const OPERATOR_DICTIONARY = {
  equal_to: 'Equals to',
  not_equal_to: 'Does not equal',
  contains: 'Contains',
  does_not_contain: 'Does not contain',
  is_present: 'Is present',
  is_not_present: 'Is not present',
  is_greater_than: 'Greater than',
  is_less_than: 'Less than',
};

export default {
  name: 'BroadcastDetail',
  components: { Spinner },
  data() {
    return {
      isLoading: true,
      isFetchingContacts: false,
      campaign: {},
      metrics: {
        sent: 0,
        read: 0,
        replied: 0,
        failed: 0
      }
    };
  },
  computed: {
    ...mapGetters({
      contactsList: 'contacts/getContactsList',
    }),
    formattedDate() {
      const dateString = this.campaign.scheduled_at || this.campaign.created_at;
      if (!dateString) return 'Loading date...';
      const dateOptions = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' };
      return new Date(dateString).toLocaleDateString('en-US', dateOptions);
    },

    formattedTargetSegments() {
      const segment = this.campaign.target_segment;
      if (!segment || segment === 'all') return [this.$t('BROADCAST.ALL_CONTACTS')];
      try {
        const parsed = JSON.parse(segment);
        const filters = Array.isArray(parsed) ? parsed : (parsed.payload || []);
        if (filters.length === 0) return [this.$t('BROADCAST.ALL_CONTACTS')];

        return filters.map(f => {
          const attrKey = f.attribute_key || '';
          const attr = attrKey.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
          const opKey = f.filter_operator || '';
          const op = OPERATOR_DICTIONARY[opKey] || opKey.replace(/_/g, ' ');
          const val = f.values && f.values.length > 0 ? `"${f.values.join(', ')}"` : '';
          return `${attr} ${op} ${val}`.trim();
        });
      } catch (e) {
        return [segment];
      }
    },

    formattedMessage() {
      let text = this.campaign.message_body;
      if (!text) return 'Loading message...';

      if (this.campaign.spin_text_enabled) {
        text = text.replace(/\[([^\[\]]+)\]/g, (_, group) => group.split('|')[0]);
      }
      text = text.replace(/\{\{full_name\}\}/g, 'John Doe').replace(/\{\{first_name\}\}/g, 'John').replace(/\{\{phone_number\}\}/g, '+1234567890');
      text = text.replace(/\{\{([^}]+)\}\}/g, (_, varName) => `[${varName.replace(/_/g, ' ')}]`);

      return text;
    }
  },
  mounted() {
    this.fetchCampaignDetail();
  },
  methods: {
    async fetchCampaignDetail() {
      this.isLoading = true;
      try {
        const broadcastId = this.$route.params.id;
        const data = await this.$store.dispatch('broadcasts/show', broadcastId);
        
        this.campaign = data;
        this.metrics = data.metrics || this.metrics;

        this.fetchRecipients();
      } catch (error) {
        if (window.bus) {
          window.bus.$emit('new-toast-message', this.$t('BROADCAST.ERROR_MESSAGE'));
        } else {
          alert(this.$t('BROADCAST.ERROR_MESSAGE'));
        }
        this.goBack();
      } finally {
        this.isLoading = false;
      }
    },
    
    async fetchRecipients() {
      this.isFetchingContacts = true;
      try {
        const segment = this.campaign.target_segment;
        if (!segment || segment === 'all') {
          await this.$store.dispatch('contacts/get', { page: 1 });
        } else {
          const parsed = JSON.parse(segment);
          await this.$store.dispatch('contacts/filter', { page: 1, queryPayload: parsed });
        }
      } catch (e) {
        console.error("Failed to load recipient contacts", e);
      } finally {
        this.isFetchingContacts = false;
      }
    },

    goBack() {
      this.$router.push({ name: 'blasting_index' });
    }
  }
};
</script>

<style scoped>
.custom-scrollbar::-webkit-scrollbar { width: 8px; }
.custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
.custom-scrollbar::-webkit-scrollbar-thumb { background-color: #cbd5e1; border-radius: 20px; }
.dark .custom-scrollbar::-webkit-scrollbar-thumb { background-color: #475569; }
</style>