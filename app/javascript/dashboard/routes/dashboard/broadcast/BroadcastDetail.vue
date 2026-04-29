<template>
  <div class="flex-1 w-full h-full p-8 overflow-y-auto flex flex-col bg-slate-50 dark:bg-slate-900">
    
    <!-- Tombol Kembali & Header -->
    <div class="flex flex-col gap-4 mb-8 border-b border-slate-200 dark:border-slate-800 pb-6">
      <button 
        @click="goBack" 
        class="flex items-center gap-2 text-sm font-medium text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-100 w-fit transition-colors"
      >
        <span class="i-lucide-arrow-left w-4 h-4"></span>
        {{ $t('BROADCAST_DETAIL.BACK') }}
      </button>

      <div class="flex justify-between items-end">
        <div>
          <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100 flex items-center gap-3">
            {{ $t('BROADCAST_DETAIL.TITLE') }} #{{ campaign.id }}
            <span 
              class="px-2.5 py-0.5 rounded-full text-xs font-semibold tracking-wide uppercase"
              :class="{
                'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400': campaign.status === 'completed',
                'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400': campaign.status === 'processing',
              }"
            >
              {{ campaign.status }}
            </span>
          </h1>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
            {{ $t('BROADCAST_DETAIL.SENT_AT') }}: {{ campaign.scheduled_at }}
          </p>
        </div>
      </div>
    </div>

    <!-- Statistik Utama (4 Kartu) -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
      
      <!-- Terkirim -->
      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center text-blue-500">
          <span class="i-lucide-send w-6 h-6"></span>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ $t('BROADCAST_DETAIL.METRIC_SENT') }}</p>
          <h3 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ metrics.sent }}</h3>
        </div>
      </div>

      <!-- Dibaca -->
      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-emerald-50 dark:bg-emerald-900/20 flex items-center justify-center text-emerald-500">
          <span class="i-lucide-check-check w-6 h-6"></span>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ $t('BROADCAST_DETAIL.METRIC_READ') }}</p>
          <h3 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ metrics.read }}</h3>
        </div>
      </div>

      <!-- Dibalas -->
      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-purple-50 dark:bg-purple-900/20 flex items-center justify-center text-purple-500">
          <span class="i-lucide-message-circle-reply w-6 h-6"></span>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ $t('BROADCAST_DETAIL.METRIC_REPLIED') }}</p>
          <h3 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ metrics.replied }}</h3>
        </div>
      </div>

      <!-- Gagal -->
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

    <!-- Rincian & Pratinjau Pesan -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      
      <!-- Pratinjau Pesan -->
      <div class="lg:col-span-2 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden">
        <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50">
          <h3 class="font-semibold text-slate-800 dark:text-slate-200">{{ $t('BROADCAST_DETAIL.MESSAGE_PREVIEW') }}</h3>
        </div>
        <div class="p-6">
          <div class="whitespace-pre-wrap text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-slate-900 p-4 rounded-lg font-mono text-sm">
            {{ campaign.message_body }}
          </div>
        </div>
      </div>

      <!-- Informasi Tambahan -->
      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden h-fit">
        <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50">
          <h3 class="font-semibold text-slate-800 dark:text-slate-200">{{ $t('BROADCAST_DETAIL.INFO') }}</h3>
        </div>
        <div class="p-6 flex flex-col gap-4">
          <div>
            <p class="text-xs text-slate-500 dark:text-slate-400 mb-1">{{ $t('BROADCAST_DETAIL.TARGET') }}</p>
            <p class="font-medium text-sm text-slate-800 dark:text-slate-200">{{ campaign.target_segment }}</p>
          </div>
          <div>
            <p class="text-xs text-slate-500 dark:text-slate-400 mb-1">Inbox Sender</p>
            <p class="font-medium text-sm text-slate-800 dark:text-slate-200">{{ campaign.inbox_name }}</p>
          </div>
          <div>
            <p class="text-xs text-slate-500 dark:text-slate-400 mb-1">Fitur Lanjutan</p>
            <div class="flex gap-2 mt-1">
              <span v-if="campaign.spin_text_enabled" class="px-2 py-1 bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded text-xs">Spin Text Aktif</span>
              <span v-if="campaign.unsubscribe_link_enabled" class="px-2 py-1 bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded text-xs">Unsubscribe Aktif</span>
            </div>
          </div>
        </div>
      </div>

    </div>

  </div>
</template>

<script>
export default {
  name: 'BroadcastDetail',
  data() {
    return {
      // Data MOCK untuk menguji UI
      campaign: {
        id: this.$route.params.id || 101, // Mengambil ID dari URL jika ada
        target_segment: 'VIP Customers',
        inbox_name: 'WhatsApp CS Pusat',
        message_body: 'Halo {{full_name}},\n\nKami memiliki penawaran eksklusif khusus untuk pelanggan VIP seperti Anda! Dapatkan diskon 50% untuk semua layanan kami hingga akhir bulan ini.\n\nJangan lewatkan!',
        status: 'completed',
        scheduled_at: '29 Apr 2026, 14:00 WIB',
        spin_text_enabled: true,
        unsubscribe_link_enabled: true,
      },
      metrics: {
        sent: 1250,
        read: 1105,
        replied: 84,
        failed: 12
      }
    };
  },
  mounted() {
    // TODO: Nanti di sini kita akan me-load data dari backend berdasarkan ID
    // this.fetchCampaignDetail(this.$route.params.id);
  },
  methods: {
    goBack() {
      this.$router.push({ name: 'blasting_index' });
    }
  }
};
</script>