import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ScheduledRemindersAPI from '../../api/scheduledReminders';

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
  getScheduledReminders(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }, aiAgentId) => {
    commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isFetching: true });
    try {
      const response = await ScheduledRemindersAPI.getAll(aiAgentId);
      commit(types.SET_SCHEDULED_REMINDERS, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, { aiAgentId, data }) => {
    commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isCreating: true });
    try {
      const response = await ScheduledRemindersAPI.createReminder(
        aiAgentId,
        data
      );
      commit(types.ADD_SCHEDULED_REMINDER, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { aiAgentId, reminderId, data }) => {
    commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isUpdating: true });
    try {
      const response = await ScheduledRemindersAPI.updateReminder(
        aiAgentId,
        reminderId,
        data
      );
      commit(types.UPDATE_SCHEDULED_REMINDER, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, { aiAgentId, reminderId }) => {
    commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isDeleting: true });
    try {
      await ScheduledRemindersAPI.deleteReminder(aiAgentId, reminderId);
      commit(types.DELETE_SCHEDULED_REMINDER, reminderId);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error.message);
    } finally {
      commit(types.SET_SCHEDULED_REMINDERS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_SCHEDULED_REMINDERS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_SCHEDULED_REMINDERS](_state, data) {
    MutationHelpers.set(_state, data);
  },
  [types.ADD_SCHEDULED_REMINDER](_state, data) {
    MutationHelpers.create(_state, data);
  },
  [types.UPDATE_SCHEDULED_REMINDER](_state, data) {
    MutationHelpers.update(_state, data);
  },
  [types.DELETE_SCHEDULED_REMINDER](_state, id) {
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
