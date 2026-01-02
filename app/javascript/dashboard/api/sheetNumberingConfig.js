/* global axios */

const getAccountId = () => {
  const isInsideAccountScopedURLs =
    window.location.pathname.includes('/app/accounts');

  if (isInsideAccountScopedURLs) {
    return window.location.pathname.split('/')[3];
  }

  return '';
};

const buildUrl = (aiAgentId) => {
  const accountId = getAccountId();
  return `/api/v2/accounts/${accountId}/ai_agents/${aiAgentId}/sheet_numbering_configs`;
};

export default {
  getConfig(aiAgentId) {
    return axios.get(`${buildUrl(aiAgentId)}/config`);
  },

  updateConfig(aiAgentId, data) {
    return axios.put(`${buildUrl(aiAgentId)}/config`, {
      sheet_numbering_config: data,
    });
  },
};
