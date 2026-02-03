/* global axios */

import ApiClient from './ApiClient';

class AgentNotificationSettingsAPI extends ApiClient {
  constructor() {
    super('agent_notification_settings', { accountScoped: true, apiVersion: 'v2' });
  }

  getAll(aiAgentId) {
    return axios.get(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/agent_notification_settings`
    );
  }

  createSetting(aiAgentId, data) {
    return axios.post(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/agent_notification_settings`,
      { agent_notification_setting: data }
    );
  }

  updateSetting(aiAgentId, settingId, data) {
    return axios.patch(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/agent_notification_settings/${settingId}`,
      { agent_notification_setting: data }
    );
  }

  deleteSetting(aiAgentId, settingId) {
    return axios.delete(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/agent_notification_settings/${settingId}`
    );
  }
}

export default new AgentNotificationSettingsAPI();
