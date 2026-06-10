<template>
  <div class="flex-1 w-full h-full p-8 overflow-y-auto flex flex-col bg-transparent custom-scrollbar">
    
    <!-- Header Halaman -->
    <div class="flex justify-between items-center mb-6 border-b border-slate-200 dark:border-slate-800 pb-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
          <span class="i-lucide-layout-dashboard w-6 h-6 text-emerald-600"></span>
          {{ $t('BROADCAST.TITLE') || 'Dashboard Blasting' }}
        </h1>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          {{ $t('BROADCAST.DESC') || 'Pantau performa pesan massal dan kelola campaign Anda di sini.' }}
        </p>
      </div>
      
      <!-- Tombol Tambah Atas -->
      <Button 
        v-if="broadcasts.length > 0 && !uiFlags.isFetching"
        icon="i-lucide-plus" 
        class="!bg-emerald-600 !text-white hover:!bg-emerald-700 !border-0 shadow-sm"
        @click="goToNewBroadcast"
      >
        {{ $t('BROADCAST.NEW_BROADCAST') || 'Broadcast Baru' }}
      </Button>
    </div>

    <!-- 1. TAMPILAN LOADING -->
    <div 
      v-if="uiFlags.isFetching" 
      class="flex-1 flex flex-col items-center justify-center text-center"
    >
      <svg class="animate-spin w-10 h-10 text-emerald-600 mb-4" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-20" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-80" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-slate-500 dark:text-slate-400 font-medium">Memuat data analitik...</p>
    </div>

    <!-- 2. TAMPILAN EMPTY STATE (Jika data benar-benar kosong) -->
    <div 
      v-else-if="broadcasts.length === 0"
      class="flex-1 flex flex-col items-center justify-center bg-slate-50 dark:bg-slate-900/50 rounded-xl border border-slate-200 dark:border-slate-800 p-10 text-center shadow-sm"
    >
      <h2 class="text-2xl font-bold text-slate-800 dark:text-slate-200 mb-4">
        Mulai Campaign Pertama Anda!
      </h2>
      <p class="text-slate-500 dark:text-slate-400 mb-8 max-w-md">
        Kirim pesan promosi, info diskon, atau pengumuman ke banyak pelanggan sekaligus hanya dalam beberapa klik.
      </p>
      
      <!-- Ilustrasi -->
      <div class="w-40 h-40 mb-8 bg-white dark:bg-slate-800 rounded-full flex items-center justify-center shadow-sm border border-emerald-100 dark:border-emerald-900/30">
        <span class="i-lucide-megaphone w-20 h-20 text-emerald-500"></span>
      </div>

      <!-- Tombol Utama Tengah -->
      <Button 
        icon="i-lucide-plus" 
        size="lg"
        class="!bg-emerald-600 !text-white hover:!bg-emerald-700 !border-0 shadow-md"
        @click="goToNewBroadcast"
      >
        Buat Broadcast Sekarang
      </Button>
    </div>

    <!-- 3. TAMPILAN DASHBOARD & LIST DATA -->
    <div v-else class="flex flex-col gap-6">
      
      <!-- ================= KARTU ANALITIK (DASHBOARD) ================= -->
      <div class="flex flex-col gap-5">
        
        <!-- Campaign Terbaik (Posisi Paling Atas, Full Width) -->
        <div class="bg-gradient-to-br from-emerald-600 to-teal-800 p-6 md:p-8 rounded-xl border border-emerald-700 shadow-md relative overflow-hidden text-white flex flex-col justify-center min-h-[140px]">
          <div class="absolute -right-6 -bottom-8 opacity-20 pointer-events-none">
            <span class="i-lucide-award w-48 h-48 block"></span>
          </div>
          <p class="text-sm font-semibold text-emerald-100 mb-2 relative z-10 uppercase tracking-wider flex items-center gap-1.5">
            <span class="i-lucide-star w-4 h-4"></span> Campaign Terbaik
          </p>
          
          <div class="relative z-10" v-if="bestCampaign && bestCampaign.metrics?.replied > 0">
            <h3 class="text-xl md:text-2xl font-bold leading-tight mb-2 truncate" :title="cleanMessagePreview(bestCampaign.message_body, false)">
              #{{ bestCampaign.id }} - {{ cleanMessagePreview(bestCampaign.message_body, false) }}
            </h3>
            <p class="text-sm md:text-base text-emerald-200 font-medium">
              Mendapatkan {{ bestCampaign.metrics.replied }} balasan / prospek pelanggan
            </p>
          </div>
          
          <div class="relative z-10 mt-1" v-else>
            <h3 class="text-lg md:text-xl font-bold italic text-emerald-200/80">Belum ada data interaksi</h3>
            <p class="text-sm text-emerald-200/60 mt-1">Kirim lebih banyak pesan untuk melihat pesan mana yang paling sukses membawa pelanggan.</p>
          </div>
        </div>

        <!-- Metrik Terkirim dan Gagal (Bersebelahan) -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <!-- Total Pesan Terkirim -->
          <div class="bg-white dark:bg-slate-800 p-6 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm relative overflow-hidden">
            <div class="absolute -right-4 -top-4 w-28 h-28 bg-blue-50 dark:bg-blue-900/10 rounded-full flex items-center justify-center pointer-events-none">
              <span class="i-lucide-send w-12 h-12 text-blue-500/20 dark:text-blue-400/10"></span>
            </div>
            <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-1 relative z-10">Total Pesan Terkirim</p>
            <div class="flex items-end gap-3 relative z-10">
              <h3 class="text-4xl font-bold text-slate-800 dark:text-slate-100">{{ aggregateMetrics.sent }}</h3>
              <span class="text-xs font-medium text-slate-400 mb-2 flex items-center"><span class="i-lucide-bar-chart-2 w-3 h-3 mr-1"></span> akumulasi</span>
            </div>
          </div>

          <!-- Total Pesan Gagal -->
          <div class="bg-white dark:bg-slate-800 p-6 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm relative overflow-hidden">
            <div class="absolute -right-4 -top-4 w-28 h-28 bg-rose-50 dark:bg-rose-900/10 rounded-full flex items-center justify-center pointer-events-none">
              <span class="i-lucide-alert-triangle w-12 h-12 text-rose-500/20 dark:text-rose-400/10"></span>
            </div>
            <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-1 relative z-10">Total Pengiriman Gagal</p>
            <div class="flex items-end gap-3 relative z-10">
              <h3 class="text-4xl font-bold text-rose-600 dark:text-rose-400">{{ aggregateMetrics.failed }}</h3>
              <span class="text-xs font-medium text-slate-400 mb-2 flex items-center"><span class="i-lucide-x-circle w-3 h-3 mr-1"></span> nomor tdk valid</span>
            </div>
          </div>
        </div>
        
      </div>

      <!-- ================= TABEL DAFTAR BROADCAST ================= -->
      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden shadow-sm mt-2">
        <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 flex items-center gap-2">
          <span class="i-lucide-history w-4 h-4 text-slate-500"></span>
          <h3 class="font-semibold text-slate-800 dark:text-slate-200">Riwayat Pengiriman</h3>
        </div>
        
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-slate-50 dark:bg-slate-900/50 border-b border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              <th class="p-4 w-16">ID</th>
              <th class="p-4 w-1/4">Target Segmen</th>
              <th class="p-4 w-2/5">Isi Pesan</th>
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
              <td class="p-4 font-bold text-slate-500">#{{ campaign.id }}</td>
              
              <!-- Target Segmen -->
              <td class="p-4">
                <div class="flex flex-wrap gap-1.5">
                  <span 
                    v-for="(badge, index) in getParsedSegments(campaign.target_segment)" 
                    :key="index"
                    class="px-2 py-1 bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 rounded text-[11px] font-semibold border border-blue-100 dark:border-blue-800/50 whitespace-nowrap"
                  >
                    {{ badge }}
                  </span>
                </div>
              </td>
              
              <!-- Isi Pesan -->
              <td class="p-4">
                <div 
                  class="truncate max-w-xs md:max-w-sm text-slate-600 dark:text-slate-400 font-medium" 
                  :title="cleanMessagePreview(campaign.message_body, campaign.spin_text_enabled)"
                >
                  {{ cleanMessagePreview(campaign.message_body, campaign.spin_text_enabled) }}
                </div>
              </td>
              
              <!-- Status -->
              <td class="p-4">
                <span 
                  class="px-2.5 py-1 rounded-md text-[10px] font-bold tracking-wide uppercase border"
                  :class="{
                    'bg-amber-100 text-amber-700 border-amber-200 dark:bg-amber-900/30 dark:text-amber-400 dark:border-amber-800/50': campaign.status === 'processing',
                    'bg-emerald-100 text-emerald-700 border-emerald-200 dark:bg-emerald-900/30 dark:text-emerald-400 dark:border-emerald-800/50': campaign.status === 'completed',
                    'bg-rose-100 text-rose-700 border-rose-200 dark:bg-rose-900/30 dark:text-rose-400 dark:border-rose-800/50': campaign.status === 'failed',
                    'bg-slate-100 text-slate-700 border-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700': campaign.status === 'draft' || !campaign.status
                  }"
                >
                  {{ campaign.status || 'draft' }}
                </span>
              </td>
              
              <!-- Aksi -->
              <td class="p-4">
                <div class="flex items-center justify-end gap-3">
                  <button @click="$router.push({ name: 'broadcast_detail', params: { id: campaign.id } })" class="text-slate-400 hover:text-blue-500 transition-colors focus:outline-none" title="Lihat Laporan Detail">
                    <span class="i-lucide-bar-chart w-5 h-5 block"></span>
                  </button>
                  <button 
                    @click="deleteCampaign(campaign.id)"
                    class="text-slate-400 hover:text-rose-500 transition-colors focus:outline-none" 
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
    }),

    aggregateMetrics() {
      let sent = 0;
      let failed = 0;

      if (this.broadcasts && this.broadcasts.length > 0) {
        this.broadcasts.forEach(campaign => {
          if (campaign.metrics) {
            sent += (campaign.metrics.sent || 0);
            failed += (campaign.metrics.failed || 0);
          }
        });
      }

      return { sent, failed };
    },

    bestCampaign() {
      if (!this.broadcasts || this.broadcasts.length === 0) return null;
      
      return this.broadcasts.reduce((best, current) => {
        const currentReplies = current.metrics?.replied || 0;
        const bestReplies = best.metrics?.replied || 0;
        return currentReplies > bestReplies ? current : best;
      }, this.broadcasts[0]);
    }
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
        .replace(/\{\{full_name\}\}/g, '[Nama Lengkap]')
        .replace(/\{\{first_name\}\}/g, '[Nama Depan]')
        .replace(/\{\{phone_number\}\}/g, '[Nomor HP]');

      cleaned = cleaned.replace(/\{\{([^}]+)\}\}/g, (_, varName) => {
        return `[${varName.replace(/_/g, ' ')}]`;
      });

      return cleaned;
    },

    async deleteCampaign(id) {
      if (window.confirm('Apakah Anda yakin ingin menghapus laporan broadcast ini? Tindakan ini tidak dapat dibatalkan.')) {
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

<style scoped>
  .custom-scrollbar::-webkit-scrollbar { width: 8px; }
  .custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
  .custom-scrollbar::-webkit-scrollbar-thumb { background-color: #cbd5e1; border-radius: 20px; }
  .dark .custom-scrollbar::-webkit-scrollbar-thumb { background-color: #475569; }
</style>