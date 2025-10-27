import NumberFormatConfigAPI from '../../api/numberFormatConfig';

const state = {
  config: {
    id: null,
    format: 'INV/',
    currentNumber: 1,
    resetEvery: 'never',
  },
  loading: false,
  error: null,
};

const getters = {
  // Getter ini aman jika state.config null
  errorMessage: state => {
    if (!state.error) return '';
    // ... (sisa logika error) ...
  },
  // Kita biarkan getter ini di sini untuk referensi,
  // tapi kita buat aman
  sampleOutput: state => {
    if (!state.config) return '...'; // <-- AMAN
    // ... (sisa logika sampleOutput) ...
  }
};

const actions = {
  // 1. fetchConfig HARUS aman dari 'null'
  async fetchConfig({ commit }) {
    commit('SET_LOADING', true);
    commit('SET_ERROR', null);
    try {
      const response = await NumberFormatConfigAPI.getConfig();
      const config = response.data; // <-- Bisa 'null'

      if (config) {
        // Data ada
        commit('SET_CONFIG', {
          id: config.id,
          format: config.format,
          currentNumber: config.current_number, 
          resetEvery: config.reset_every,
        });
      } else {
        // Data 'null', JANGAN commit(null)
        // Commit state default agar tidak crash
        commit('SET_CONFIG', state.config);
      }
    } catch (err) {
      commit('SET_ERROR', state.config);
    } finally {
      commit('SET_LOADING', false);
    }
  },

  // 2. saveConfig sekarang menerima 'formPayload' dari komponen
  async saveConfig({ commit, dispatch }, formPayload) {
    commit('SET_LOADING', true);
    commit('SET_ERROR', null);
    
    // Normalisasi payload untuk API
    const apiPayload = {
      id: formPayload.id,
      format: formPayload.format,
      current_number: Number(formPayload.currentNumber),
      reset_every: formPayload.resetEvery,
    };

    try {
      if (apiPayload.id) {
        await NumberFormatConfigAPI.updateConfig(apiPayload);
      } else {
        await NumberFormatConfigAPI.createConfig(apiPayload);
      }
      // Panggil 'fetchConfig' lagi untuk refresh data
      await dispatch('fetchConfig'); 
    } catch (err) {
      commit('SET_ERROR', err);
    } finally {
      commit('SET_LOADING', false);
    }
  },
};

const mutations = {
  SET_LOADING(state, value) {
    state.loading = value;
  },
  SET_ERROR(state, error) {
    state.error = error;
  },
  SET_CONFIG(state, configPayload) {
    state.config = configPayload;
  },
  // MUTASI UPDATE_FORM_FIELD BISA DIHAPUS
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};