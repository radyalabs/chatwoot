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
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await BroadcastTemplatesAPI.get();
      commit('SET_DATA', response.data);
    } catch (error) {
      console.error("Gagal menarik data template dari DB:", error);
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },

  create: async function createTemplate({ commit }, templateObj) {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await BroadcastTemplatesAPI.create(templateObj);
      commit('ADD_RECORD', response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || 'Gagal menyimpan template');
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },

  delete: async function deleteTemplate({ commit }, id) {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await BroadcastTemplatesAPI.delete(id);
      commit('DELETE_RECORD', id);
    } catch (error) {
      throw new Error(error?.response?.data?.message || 'Gagal menghapus template');
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },
  update: async function updateTemplate({ commit }, { id, payload }) {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await BroadcastTemplatesAPI.update(id, payload);
      commit('UPDATE_RECORD', response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || 'Gagal memperbarui template');
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG(_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  SET_DATA(_state, data) {
    _state.records = data;
  },
  ADD_RECORD(_state, data) {
    _state.records.push(data);
  },
  DELETE_RECORD(_state, id) {
    _state.records = _state.records.filter(record => record.id !== id);
  },
  UPDATE_RECORD(_state, data) {
    const index = _state.records.findIndex(r => r.id === data.id);
    if (index !== -1) {
      _state.records.splice(index, 1, data);
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};