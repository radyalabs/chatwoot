import ContactAttributeKeysAPI from '../../api/contactAttributeKeys';

const state = {
  records: [],
};

const getters = {
  getContactAttributeKeys: $state => $state.records,
};

const actions = {
  get: async ({ commit }) => {
    const response = await ContactAttributeKeysAPI.get();
    commit('SET_KEYS', response.data);
  },

  create: async ({ commit }, { key, dataType = 'text' }) => {
    const response = await ContactAttributeKeysAPI.create(key, dataType);
    commit('ADD_KEY', response.data);
    return response.data;
  },

  destroy: async ({ commit, state, dispatch }, id) => {
    const key = state.records.find(r => r.id === id)?.key;
    await ContactAttributeKeysAPI.delete(id);
    commit('REMOVE_KEY', id);
    if (key) {
      dispatch('contacts/removeCustomAttrKey', key, { root: true });
    }
  },
};

const mutations = {
  SET_KEYS($state, keys) {
    $state.records = keys;
  },
  ADD_KEY($state, key) {
    if (!$state.records.find(r => r.id === key.id)) {
      $state.records = [...$state.records, key];
    }
  },
  REMOVE_KEY($state, id) {
    $state.records = $state.records.filter(r => r.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
