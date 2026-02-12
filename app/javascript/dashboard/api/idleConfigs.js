/* global axios */

import ApiClient from './ApiClient';

class IdleConfigs extends ApiClient {
  constructor() {
    super('idle_configs', { accountScoped: true });
  }

  // Get idle config for an AI agent
  getConfig(aiAgentId) {
    return axios.get(
      `/api/v2/accounts/${this.accountIdFromRoute}/ai_agents/${aiAgentId}/idle_configs/config`
    );
  }

  // Update idle config for an AI agent
  updateConfig(aiAgentId, data) {
    return axios.put(
      `/api/v2/accounts/${this.accountIdFromRoute}/ai_agents/${aiAgentId}/idle_configs/config`,
      { idle_config: data }
    );
  }
}

export default new IdleConfigs();
