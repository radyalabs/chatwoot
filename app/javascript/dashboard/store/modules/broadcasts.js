import BroadcastsAPI from '../../api/broadcasts';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
  },
};

const getters = {
  getBroadcasts($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

const actions = {
  // Action untuk List
  get: async ({ commit }) => {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await BroadcastsAPI.get();
      commit('SET_RECORDS', response.data);
    } catch (error) {
      console.error(error);
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },

  // Action untuk Detail
  show: async ({ commit }, id) => {
    commit('SET_UI_FLAG', { isFetchingItem: true });
    try {
      const response = await BroadcastsAPI.show(id);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_UI_FLAG', { isFetchingItem: false });
    }
  },

  // Action untuk Form (Submit)
  create: async ({ commit }, data) => {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await BroadcastsAPI.create(data);
      commit('ADD_RECORD', response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },

  delete: async ({ commit }, id) => {
    try {
      await BroadcastsAPI.destroy(id);
      commit('REMOVE_RECORD', id); // Panggil mutasi untuk update tabel
    } catch (error) {
      throw new Error(error);
    }
  },
};

const mutations = {
  SET_UI_FLAG($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  SET_RECORDS($state, data) {
    $state.records = data;
  },
  ADD_RECORD($state, data) {
    $state.records.unshift(data); // Tambah data baru ke urutan paling atas tabel
  },
  REMOVE_RECORD($state, id) {
    // Saring ulang array, buang ID yang baru saja dihapus
    $state.records = $state.records.filter(record => record.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};