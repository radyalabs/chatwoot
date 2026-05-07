<template>
  <div class="flex-1 w-full h-full p-8 overflow-y-auto flex flex-col bg-transparent">
    
    <!-- Header Halaman -->
    <div class="flex justify-between items-center mb-6 border-b border-slate-200 dark:border-slate-800 pb-4">
      <div>
        <h1 class="text-2xl font-medium text-slate-900 dark:text-slate-100">
          {{ $t('BROADCAST.TITLE') }}
        </h1>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          {{ $t('BROADCAST.DESC') }}
        </p>
      </div>
      
      <!-- Tombol Tambah Atas: Hanya muncul jika array broadcasts TIDAK KOSONG -->
      <Button 
        v-if="broadcasts.length > 0"
        icon="i-lucide-plus" 
        class="!bg-emerald-500 !text-white hover:!bg-emerald-600 !border-0"
        @click="goToNewBroadcast"
      >
        {{ $t('BROADCAST.NEW_BROADCAST') }}
      </Button>
    </div>

    <!-- Tampilan Empty State: Hanya muncul jika array broadcasts KOSONG -->
    <div 
      v-if="broadcasts.length === 0"
      class="flex-1 flex flex-col items-center justify-center bg-slate-50 dark:bg-slate-900/50 rounded-lg border border-slate-200 dark:border-slate-800 p-10 text-center"
    >
      <h2 class="text-2xl font-semibold text-slate-800 dark:text-slate-200 mb-8">
        {{ $t('BROADCAST.CREATE_FIRST') }}
      </h2>
      
      <!-- Ilustrasi -->
      <div class="w-40 h-40 mb-8 bg-white dark:bg-slate-800 rounded-full flex items-center justify-center shadow-sm border border-slate-100 dark:border-slate-700">
        <span class="i-lucide-megaphone w-20 h-20 text-woot-500"></span>
      </div>

      <!-- Tombol Utama Tengah -->
      <Button 
        icon="i-lucide-plus" 
        size="lg"
        class="!bg-emerald-500 !text-white hover:!bg-emerald-600 !border-0"
        @click="goToNewBroadcast"
      >
        {{ $t('BROADCAST.NEW_BROADCAST') }}
      </Button>
    </div>

    <!-- Tampilan List Data: Nanti tabel riwayat broadcast Anda akan diletakkan di sini -->
    <div v-else class="flex-1 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden shadow-sm">
      <table class="w-full text-left border-collapse">
        <thead>
          <tr class="bg-slate-50 dark:bg-slate-900/50 border-b border-slate-200 dark:border-slate-700 text-sm font-medium text-slate-600 dark:text-slate-300">
            <th class="p-4">ID</th>
            <th class="p-4">Target Segmen</th>
            <th class="p-4">Isi Pesan</th>
            <th class="p-4">Status</th>
            <th class="p-4 text-right">Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr 
            v-for="campaign in broadcasts" 
            :key="campaign.id"
            class="border-b border-slate-100 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors text-sm text-slate-700 dark:text-slate-300"
          >
            <td class="p-4 font-medium">#{{ campaign.id }}</td>
            <td class="p-4">
              <span class="px-2 py-1 bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 rounded text-xs font-medium">
                {{ campaign.target_segment }}
              </span>
            </td>
            <td class="p-4 truncate max-w-xs">{{ campaign.message_body }}</td>
            <td class="p-4">
              <span 
                class="px-2.5 py-1 rounded-md text-xs font-semibold tracking-wide uppercase border"
                :class="{
                  'bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-900 dark:text-amber-300 dark:border-amber-700': campaign.status === 'processing',
                  'bg-emerald-100 text-emerald-800 border-emerald-300 dark:bg-emerald-900 dark:text-emerald-300 dark:border-emerald-700': campaign.status === 'completed',
                  'bg-slate-100 text-slate-800 border-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-600': campaign.status === 'draft'
                }"
              >
                {{ campaign.status }}
              </span>
            </td>
            <td class="p-4 text-right">
              <button @click="$router.push({ name: 'broadcast_detail', params: { id: campaign.id } })" class="text-slate-400 hover:text-woot-500 transition-colors" title="Lihat Detail">
                <span class="i-lucide-eye w-5 h-5 block"></span>
              </button>
              <button 
                @click="deleteCampaign(campaign.id)"
                class="text-slate-400 hover:text-rose-500 transition-colors" 
                title="Hapus Broadcast"
              >
                <span class="i-lucide-trash-2 w-5 h-5 block"></span>
              </button>
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

export default {
  name: 'BroadcastList',
  components: {
    Button,
  },
  computed: {
    // Ambil data langsung dari state Vuex
    ...mapGetters({
      broadcasts: 'broadcasts/getBroadcasts',
      uiFlags: 'broadcasts/getUIFlags',
    })
  },
  mounted() {
    // Perintahkan Vuex untuk mengambil data list dari Mock API
    this.$store.dispatch('broadcasts/get');
  },
  methods: {
    goToNewBroadcast() {
      this.$router.push({ name: 'new_broadcast' });
    },
    async deleteCampaign(id) {
      // Munculkan pop-up konfirmasi bawaan browser
      if (window.confirm('Apakah Anda yakin ingin menghapus broadcast ini?')) {
        try {
          await this.$store.dispatch('broadcasts/delete', id);
          
          window.bus.$emit('new-toast-message', 'Broadcast berhasil dihapus');
        } catch (error) {
          window.bus.$emit('new-toast-message', 'Gagal menghapus broadcast');
        }
      }
    }
  }
};
</script>