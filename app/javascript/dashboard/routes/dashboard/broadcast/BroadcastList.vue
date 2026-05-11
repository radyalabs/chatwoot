<template>
  <div class="flex-1 w-full h-full p-8 overflow-y-auto flex flex-col bg-transparent">
    
    <div class="flex justify-between items-center mb-6 border-b border-slate-200 dark:border-slate-800 pb-4">
      <div>
        <h1 class="text-2xl font-medium text-slate-900 dark:text-slate-100">
          {{ $t('BROADCAST.TITLE') || 'Kelola Broadcast' }}
        </h1>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          {{ $t('BROADCAST.DESC') || 'Kelola dan pantau semua pesan massal Anda di sini.' }}
        </p>
      </div>
      
      <Button 
        v-if="broadcasts.length > 0 && !uiFlags.isFetching"
        icon="i-lucide-plus" 
        class="!bg-emerald-500 !text-white hover:!bg-emerald-600 !border-0"
        @click="goToNewBroadcast"
      >
        {{ $t('BROADCAST.NEW_BROADCAST') || 'Broadcast Baru' }}
      </Button>
    </div>

    <div 
      v-if="uiFlags.isFetching" 
      class="flex-1 flex flex-col items-center justify-center text-center"
    >
      <svg class="animate-spin w-10 h-10 text-emerald-500 mb-4" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-20" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-80" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-slate-500 dark:text-slate-400 font-medium">Memuat data broadcast...</p>
    </div>

    <div 
      v-else-if="broadcasts.length === 0"
      class="flex-1 flex flex-col items-center justify-center bg-slate-50 dark:bg-slate-900/50 rounded-lg border border-slate-200 dark:border-slate-800 p-10 text-center"
    >
      <h2 class="text-2xl font-semibold text-slate-800 dark:text-slate-200 mb-8">
        {{ $t('BROADCAST.CREATE_FIRST') || 'Belum ada broadcast yang dibuat.' }}
      </h2>
      
      <div class="w-40 h-40 mb-8 bg-white dark:bg-slate-800 rounded-full flex items-center justify-center shadow-sm border border-slate-100 dark:border-slate-700">
        <span class="i-lucide-megaphone w-20 h-20 text-emerald-500"></span>
      </div>

      <Button 
        icon="i-lucide-plus" 
        size="lg"
        class="!bg-emerald-500 !text-white hover:!bg-emerald-600 !border-0"
        @click="goToNewBroadcast"
      >
        {{ $t('BROADCAST.NEW_BROADCAST') || 'Buat Broadcast Sekarang' }}
      </Button>
    </div>

    <div v-else class="flex-1 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden shadow-sm">
      <table class="w-full text-left border-collapse">
        <thead>
          <tr class="bg-slate-50 dark:bg-slate-900/50 border-b border-slate-200 dark:border-slate-700 text-sm font-medium text-slate-600 dark:text-slate-300">
            <th class="p-4 w-16">ID</th>
            <th class="p-4 w-1/3">Target Segmen</th>
            <th class="p-4 w-1/3">Isi Pesan</th>
            <th class="p-4 w-24">Status</th>
            <th class="p-4 text-right">Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr 
            v-for="campaign in broadcasts" 
            :key="campaign.id"
            class="border-b border-slate-100 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors text-sm text-slate-700 dark:text-slate-300"
          >
            <td class="p-4 font-medium text-slate-500">#{{ campaign.id }}</td>
            
            <td class="p-4">
              <div class="flex flex-wrap gap-1.5">
                <span 
                  v-for="(badge, index) in getParsedSegments(campaign.target_segment)" 
                  :key="index"
                  class="px-2 py-1 bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 rounded text-[11px] font-medium border border-blue-100 dark:border-blue-800/50 whitespace-nowrap"
                >
                  {{ badge }}
                </span>
              </div>
            </td>
            
            <td class="p-4">
              <div 
                class="truncate max-w-sm text-slate-600 dark:text-slate-400" 
                :title="cleanMessagePreview(campaign.message_body, campaign.spin_text_enabled)"
              >
                {{ cleanMessagePreview(campaign.message_body, campaign.spin_text_enabled) }}
              </div>
            </td>
            
            <td class="p-4">
              <span 
                class="px-2.5 py-1 rounded-md text-[10px] font-semibold tracking-wide uppercase border"
                :class="{
                  'bg-amber-100 text-amber-700 border-amber-200 dark:bg-amber-900/30 dark:text-amber-400 dark:border-amber-800/50': campaign.status === 'processing',
                  'bg-emerald-100 text-emerald-700 border-emerald-200 dark:bg-emerald-900/30 dark:text-emerald-400 dark:border-emerald-800/50': campaign.status === 'completed',
                  'bg-rose-100 text-rose-700 border-rose-200 dark:bg-rose-900/30 dark:text-rose-400 dark:border-rose-800/50': campaign.status === 'failed',
                  'bg-slate-100 text-slate-700 border-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700': campaign.status === 'draft' || !campaign.status
                }"
              >
                {{ campaign.status || 'draft' }}
              </span>
            </td>
            
            <td class="p-4">
              <div class="flex items-center justify-end gap-3">
                <button @click="$router.push({ name: 'broadcast_detail', params: { id: campaign.id } })" class="text-slate-400 hover:text-blue-500 transition-colors" title="Lihat Detail">
                  <span class="i-lucide-eye w-5 h-5 block"></span>
                </button>
                <button 
                  @click="deleteCampaign(campaign.id)"
                  class="text-slate-400 hover:text-rose-500 transition-colors" 
                  title="Hapus Broadcast"
                >
                  <span class="i-lucide-trash-2 w-5 h-5 block"></span>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import Button from 'dashboard/components-next/button/Button.vue';

const OPERATOR_DICTIONARY = {
  equal_to: 'Sama dengan',
  not_equal_to: 'Tidak sama dengan',
  contains: 'Mengandung',
  does_not_contain: 'Tidak mengandung',
  is_present: 'Ada',
  is_not_present: 'Tidak ada',
  is_greater_than: 'Lebih dari',
  is_less_than: 'Kurang dari',
};

export default {
  name: 'BroadcastList',
  components: {
    Button,
  },
  computed: {
    ...mapGetters({
      broadcasts: 'broadcasts/getBroadcasts',
      uiFlags: 'broadcasts/getUIFlags',
    })
  },
  mounted() {
    this.$store.dispatch('broadcasts/get');
  },
  methods: {
    goToNewBroadcast() {
      this.$router.push({ name: 'new_broadcast' });
    },
    
    getParsedSegments(segment) {
      if (!segment || segment === 'all') return ['Semua Kontak'];
      
      try {
        const parsed = JSON.parse(segment);
        const filters = Array.isArray(parsed) ? parsed : (parsed.payload || []);
        
        if (filters.length === 0) return ['Semua Kontak'];

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

    cleanMessagePreview(text, spinEnabled) {
      if (!text) return '-';
      let cleaned = text;

      if (spinEnabled) {
        cleaned = cleaned.replace(/\[([^\[\]]+)\]/g, (_, group) => group.split('|')[0]);
      }

      cleaned = cleaned
        .replace(/\{\{full_name\}\}/g, 'Budi Santoso')
        .replace(/\{\{first_name\}\}/g, 'Budi')
        .replace(/\{\{phone_number\}\}/g, '+6281234567890');

      cleaned = cleaned.replace(/\{\{([^}]+)\}\}/g, (_, varName) => {
        return `[${varName.replace(/_/g, ' ')}]`;
      });

      return cleaned;
    },

    async deleteCampaign(id) {
      if (window.confirm('Apakah Anda yakin ingin menghapus broadcast ini?')) {
        try {
          await this.$store.dispatch('broadcasts/delete', id);
          if (window.bus) window.bus.$emit('new-toast-message', 'Broadcast berhasil dihapus');
        } catch (error) {
          if (window.bus) window.bus.$emit('new-toast-message', 'Gagal menghapus broadcast');
        }
      }
    }
  }
};
</script>