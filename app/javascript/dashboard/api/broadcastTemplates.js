/* eslint-disable no-console */
import ApiClient from './ApiClient';

class BroadcastTemplatesAPI extends ApiClient {
  constructor() {
    // accountScoped: true otomatis menyisipkan /api/v1/accounts/{account_id}/ di depan URL
    super('broadcast_templates', { accountScoped: true });
  }
}

export default new BroadcastTemplatesAPI();