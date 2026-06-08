/* global axios */
import ApiClient from './ApiClient';

class AgentSkillsAPI extends ApiClient {
  constructor() {
    super('agent_skills', { accountScoped: true, apiVersion: 'v2' });
  }

  listSkills(aiAgentId) {
    return axios.get(`${this.baseUrl()}/ai_agents/${aiAgentId}/skills`);
  }

  createSkill(aiAgentId, data) {
    return axios.post(`${this.baseUrl()}/ai_agents/${aiAgentId}/skills`, data);
  }

  updateSkill(aiAgentId, skillId, data) {
    return axios.patch(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/skills/${skillId}`,
      data
    );
  }

  deleteSkill(aiAgentId, skillId) {
    return axios.delete(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/skills/${skillId}`
    );
  }

  listCustomTools(aiAgentId) {
    return axios.get(
      `${this.baseUrl()}/ai_agents/${aiAgentId}/skills/custom_tools`
    );
  }
}

export default new AgentSkillsAPI();
