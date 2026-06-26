import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import BroadcastTemplatesAPI from '../../api/broadcastTemplates';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
  },
};

export const getters = {
  getTemplates(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getTemplates({ commit }) {
    commit(types.SET_UI_FLAG, { isFetching: true });
    try {
      const response = await BroadcastTemplatesAPI.get();
      commit(types.SET_DATA, response.data);
    } catch (error) {
      // Abaikan error
    } finally {
      commit(types.SET_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createTemplate({ commit }, templateObj) {
    commit(types.SET_UI_FLAG, { isCreating: true });
    try {
      const response = await BroadcastTemplatesAPI.create(templateObj);
      commit(types.ADD_RECORD, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || 'Gagal menyimpan template');
    } finally {
      commit(types.SET_UI_FLAG, { isCreating: false });
    }
  },

  delete: async function deleteTemplate({ commit }, id) {
    commit(types.SET_UI_FLAG, { isDeleting: true });
    try {
      await BroadcastTemplatesAPI.delete(id);
      commit(types.DELETE_RECORD, id);
    } catch (error) {
      throw new Error(error?.response?.data?.message || 'Gagal menghapus template');
    } finally {
      commit(types.SET_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_DATA]: (_state, data) => {
    _state.records = data;
  },
  [types.ADD_RECORD]: (_state, data) => {
    _state.records.push(data);
  },
  [types.DELETE_RECORD]: (_state, id) => {
    _state.records = _state.records.filter(record => record.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};