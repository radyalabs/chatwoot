import shippingStoresAPI from '../../api/shippingStores';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isSaving: false,
    isError: false,
  },
};

const getters = {
  getStores: (state) => state.records,
  getUIFlags: (state) => state.uiFlags,
};

const mutations = {
  SET_STORES(state, data) {
    state.records = data;
  },
  SET_UI_FLAG(state, { key, value }) {
    state.uiFlags = { ...state.uiFlags, [key]: value };
  },
};

const actions = {
  async fetch({ commit }, aiAgentId) {
    commit('SET_UI_FLAG', { key: 'isFetching', value: true });
    try {
      const response = await shippingStoresAPI.getStores(aiAgentId);
      commit('SET_STORES', response.data);
    } catch (error) {
      console.error('Error fetching shipping stores:', error);
      commit('SET_UI_FLAG', { key: 'isError', value: true });
    } finally {
      commit('SET_UI_FLAG', { key: 'isFetching', value: false });
    }
  },

  async update({ commit }, { aiAgentId, stores }) {
    commit('SET_UI_FLAG', { key: 'isSaving', value: true });
    try {
      const response = await shippingStoresAPI.batchUpdate(aiAgentId, stores);
      
      commit('SET_STORES', response.data);
      return response.data;
    } catch (error) {
      console.error('Error updating shipping stores:', error);
      commit('SET_UI_FLAG', { key: 'isError', value: true });
      throw error;
    } finally {
      commit('SET_UI_FLAG', { key: 'isSaving', value: false });
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};