import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import AgentNotificationSettingsAPI from '../../api/agentNotificationSettings';

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
  getAgentNotificationSettings(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }, aiAgentId) => {
    commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
      isFetching: true,
    });
    try {
      const response =
        await AgentNotificationSettingsAPI.getAll(aiAgentId);
      commit(types.SET_AGENT_NOTIFICATION_SETTINGS, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
        isFetching: false,
      });
    }
  },

  create: async ({ commit }, { aiAgentId, data }) => {
    commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
      isCreating: true,
    });
    try {
      const response = await AgentNotificationSettingsAPI.createSetting(
        aiAgentId,
        data
      );
      commit(types.ADD_AGENT_NOTIFICATION_SETTING, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
        isCreating: false,
      });
    }
  },

  update: async ({ commit }, { aiAgentId, settingId, data }) => {
    commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
      isUpdating: true,
    });
    try {
      const response = await AgentNotificationSettingsAPI.updateSetting(
        aiAgentId,
        settingId,
        data
      );
      commit(types.UPDATE_AGENT_NOTIFICATION_SETTING, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
        isUpdating: false,
      });
    }
  },

  delete: async ({ commit }, { aiAgentId, settingId }) => {
    commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
      isDeleting: true,
    });
    try {
      await AgentNotificationSettingsAPI.deleteSetting(aiAgentId, settingId);
      commit(types.DELETE_AGENT_NOTIFICATION_SETTING, settingId);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG, {
        isDeleting: false,
      });
    }
  },
};

export const mutations = {
  [types.SET_AGENT_NOTIFICATION_SETTINGS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_AGENT_NOTIFICATION_SETTINGS](_state, data) {
    MutationHelpers.set(_state, data);
  },
  [types.ADD_AGENT_NOTIFICATION_SETTING](_state, data) {
    MutationHelpers.create(_state, data);
  },
  [types.UPDATE_AGENT_NOTIFICATION_SETTING](_state, data) {
    MutationHelpers.update(_state, data);
  },
  [types.DELETE_AGENT_NOTIFICATION_SETTING](_state, id) {
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
