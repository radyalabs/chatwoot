import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import AgentSkillsAPI from '../../api/agentSkills';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getSkills(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }, aiAgentId) => {
    commit(types.SET_AGENT_SKILLS_UI_FLAG, { isFetching: true });
    try {
      const response = await AgentSkillsAPI.listSkills(aiAgentId);
      commit(types.SET_AGENT_SKILLS, response.data);
    } catch {
      // Ignore error
    } finally {
      commit(types.SET_AGENT_SKILLS_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, { aiAgentId, data }) => {
    commit(types.SET_AGENT_SKILLS_UI_FLAG, { isCreating: true });
    try {
      const response = await AgentSkillsAPI.createSkill(aiAgentId, data);
      commit(types.ADD_AGENT_SKILL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_AGENT_SKILLS_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { aiAgentId, skillId, data }) => {
    commit(types.SET_AGENT_SKILLS_UI_FLAG, { isUpdating: true });
    try {
      const response = await AgentSkillsAPI.updateSkill(aiAgentId, skillId, data);
      commit(types.UPDATE_AGENT_SKILL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_AGENT_SKILLS_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, { aiAgentId, skillId }) => {
    commit(types.SET_AGENT_SKILLS_UI_FLAG, { isDeleting: true });
    try {
      await AgentSkillsAPI.deleteSkill(aiAgentId, skillId);
      commit(types.DELETE_AGENT_SKILL, skillId);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_AGENT_SKILLS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_AGENT_SKILLS_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_AGENT_SKILLS](_state, data) {
    MutationHelpers.set(_state, data);
  },
  [types.ADD_AGENT_SKILL](_state, data) {
    MutationHelpers.create(_state, data);
  },
  [types.UPDATE_AGENT_SKILL](_state, data) {
    MutationHelpers.update(_state, data);
  },
  [types.DELETE_AGENT_SKILL](_state, id) {
    MutationHelpers.destroy(_state, id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
