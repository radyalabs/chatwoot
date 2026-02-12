import ApiClient from './ApiClient';

class ShippingStores extends ApiClient {
  constructor() {
    super('shipping_stores', { accountScoped: true });
  }

  // Mengambil daftar toko (GET)
  getStores(aiAgentId) {
    return axios.get(
      `/api/v2/accounts/${this.accountIdFromRoute}/ai_agents/${aiAgentId}/shipping_stores`
    );
  }

  // Menyimpan semua toko sekaligus (POST/Batch Update)
  batchUpdate(aiAgentId, storesData) {
    return axios.post(
      `/api/v2/accounts/${this.accountIdFromRoute}/ai_agents/${aiAgentId}/shipping_stores/batch_update`,
      { stores: storesData }
    );
  }
}

export default new ShippingStores();