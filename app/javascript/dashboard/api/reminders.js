/* global axios */

import ApiClient from './ApiClient';

class Reminders extends ApiClient {
  constructor() {
    super('reminders', { accountScoped: true });
  }

  // Get reminder config for an AI agent
  getConfig(aiAgentId) {
    return axios.get(
      `/api/v2/accounts/${this.accountIdFromRoute}/ai_agents/${aiAgentId}/reminders/config`
    );
  }

  // Update reminder config for an AI agent
  updateConfig(aiAgentId, data) {
    return axios.put(
      `/api/v2/accounts/${this.accountIdFromRoute}/ai_agents/${aiAgentId}/reminders/config`,
      { reminder_config: data }
    );
  }
}

export default new Reminders();
