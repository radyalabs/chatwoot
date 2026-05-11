import ApiClient from './ApiClient';

class Broadcasts extends ApiClient {
  constructor() {
    super('broadcast_campaigns', { accountScoped: true });
  }
}

export default new Broadcasts();