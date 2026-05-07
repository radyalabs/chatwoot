import ApiClient from './ApiClient';

// 1. DATABASE SEMENTARA (Di dalam memori browser)
let mockDatabase = [
  {
    id: 101,
    target_segment: 'VIP Customers',
    inbox_name: 'WhatsApp CS Pusat',
    message_body: 'Halo {{full_name}},\n\nKami memiliki penawaran eksklusif khusus untuk pelanggan VIP!',
    status: 'completed',
    scheduled_at: '04 Mei 2026, 14:00 WIB',
    spin_text_enabled: true,
    unsubscribe_link_enabled: true,
    metrics: { sent: 1250, read: 1105, replied: 84, failed: 12 }
  },
  {
    id: 102,
    target_segment: 'all',
    inbox_name: 'WhatsApp CS Pusat',
    message_body: 'Pemberitahuan maintenance server malam ini pukul 00:00.',
    status: 'processing',
    scheduled_at: '05 Mei 2026, 09:00 WIB',
    spin_text_enabled: false,
    unsubscribe_link_enabled: false,
    metrics: { sent: 500, read: 100, replied: 0, failed: 0 }
  }
];

class Broadcasts extends ApiClient {
  constructor() {
    // Format asli yang akan memanggil /api/v1/accounts/:account_id/broadcast_campaigns
    super('broadcast_campaigns', { accountScoped: true });
  }

  // OVERRIDE: Mencegat request GET untuk daftar
  get() {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({ data: [...mockDatabase].reverse() }); 
      }, 800); // Efek loading 0.8 detik
    });
  }

  // OVERRIDE: Mencegat request GET untuk 1 detail
  show(id) {
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const record = mockDatabase.find(item => item.id === parseInt(id));
        if (record) {
          resolve({ data: record });
        } else {
          reject(new Error('Data tidak ditemukan'));
        }
      }, 500);
    });
  }

  // OVERRIDE: Mencegat request POST untuk bikin baru
  create(data) {
    return new Promise((resolve) => {
      setTimeout(() => {
        const newRecord = {
          id: Math.floor(Math.random() * 9000) + 1000, // Bikin ID acak
          target_segment: data.target_segment,
          inbox_name: 'WhatsApp Terpilih', 
          message_body: data.message_body,
          status: 'draft',
          scheduled_at: new Date().toLocaleString('id-ID'),
          spin_text_enabled: data.spin_text_enabled,
          unsubscribe_link_enabled: data.unsubscribe_link_enabled,
          metrics: { sent: 0, read: 0, replied: 0, failed: 0 }
        };
        
        mockDatabase.push(newRecord); // Simpan ke database bohongan
        resolve({ data: newRecord });
      }, 1500); // Efek loading tombol submit 1.5 detik
    });
  }

  destroy(id) {
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        // Cari posisi data di dalam array mock
        const index = mockDatabase.findIndex(item => item.id === parseInt(id));
        
        if (index !== -1) {
          mockDatabase.splice(index, 1); // Hapus data dari array
          resolve({ data: { success: true } });
        } else {
          reject(new Error('Data tidak ditemukan'));
        }
      }, 800); // Simulasi loading hapus 0.8 detik
    });
  }
}

export default new Broadcasts();