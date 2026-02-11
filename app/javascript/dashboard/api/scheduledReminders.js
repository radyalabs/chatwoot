/* global axios */

import ApiClient from './ApiClient';

class ScheduledRemindersAPI extends ApiClient {
  constructor() {
    super('scheduled_reminders', { accountScoped: true, apiVersion: 'v2' });
  }

  getAll(aiAgentId) {
    return axios.get(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/scheduled_reminders`
    );
  }

  createReminder(aiAgentId, data) {
    return axios.post(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/scheduled_reminders`,
      { scheduled_reminder: data }
    );
  }

  updateReminder(aiAgentId, reminderId, data) {
    return axios.patch(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/scheduled_reminders/${reminderId}`,
      { scheduled_reminder: data }
    );
  }

  deleteReminder(aiAgentId, reminderId) {
    return axios.delete(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/scheduled_reminders/${reminderId}`
    );
  }
}

export default new ScheduledRemindersAPI();
