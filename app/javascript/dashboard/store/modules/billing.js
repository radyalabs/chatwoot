import types from '../mutation-types';
import authAPI from '../../api/auth';
import billingAPI from '../../api/billing';

import { setUser, clearCookiesOnLogout } from '../utils/api';

const initialState = {
  currentUser: {
    id: null,
    account_id: null,
    accounts: [],
    email: null,
    name: null,
  },
  uiFlags: {
    isFetching: true,
  },
  billing: {
    myActiveSubscription: {},
    latestSubscription: {},
    subscriptionHistories: [],
  },
};

// actions
export const actions = {
  createTopup: async ({ commit }, topupData) => {
    try {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: true });
      const response = await billingAPI.createTopup(topupData);
      // (Opsional) commit ke mutation jika mau update state
      // commit(types.ADD_NEW_SUBSCRIPTION, response.data);
      return response.data; // Ensure the action returns the response data
    } catch (error) {
      console.error('Error creating subscription topup:', error);
    } finally {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: false });
    }
  },
  createSubscription: async ({ commit }, subscriptionData) => {
    try {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: true });
      const response = await billingAPI.createSubscription(subscriptionData);
      // (Opsional) commit ke mutation jika mau update state
      // commit(types.ADD_NEW_SUBSCRIPTION, response.data);
      return response.data; // Ensure the action returns the response data
    } catch (error) {
      console.error('Error creating subscription:', error);
      return error;
    } finally {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: false });
    }
  },
  myActiveSubscription: async ({ commit, rootGetters }, accountId) => {
    const id = accountId || rootGetters.getCurrentAccountId;
    if (!id) return;
    try {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: false });
      const response = await axios.get(`/api/v1/accounts/${id}/subscriptions/active`);
      commit(types.SET_BILLING_MY_ACTIVE_SUBSCRIPTION, response.data);
      return response.data;
    } catch (error) {
      console.error('Error fetching subscription:', error);
    } finally {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: false });
    }
  },
  getLatestSubscription: async ({ commit }) => {
    try {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: true }); // Set loading
      const response = await billingAPI.latestSubscription();
      commit(types.SET_BILLING_LATEST_SUBSCRIPTION, response.data);
      return response.data;
    } catch (error) {
      console.error('Error fetching subscription:', error);
    } finally {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: false }); // Selesai loading
    }
  },
  subscriptionHistories: async ({ commit }) => {
    try {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: false }); // Set loading
      const response = await billingAPI.transactionHistories();
      commit(types.SET_BILLING_SUBSCRIPTION_HISTORIES, response.data);
      return response.data;
    } catch (error) {
      console.error('Error fetching subscription:', error);
    } finally {
      commit(types.SET_CURRENT_USER_UI_FLAGS, { isFetching: false }); // Selesai loading
    }
  },
};

// mutations
export const mutations = {
  [types.SET_CURRENT_USER_UI_FLAGS](_state, { isFetching }) {
    _state.uiFlags = { isFetching };
  },
  [types.SET_BILLING_MY_ACTIVE_SUBSCRIPTION](state, subscriptionData) {
    state.billing.myActiveSubscription = subscriptionData;
  },
  [types.SET_BILLING_LATEST_SUBSCRIPTION](state, subscriptionData) {
    state.billing.latestSubscription = subscriptionData;
  },
  [types.SET_BILLING_SUBSCRIPTION_HISTORIES](state, subscriptionData) {
    state.billing.subscriptionHistories = subscriptionData;
  },
};

export const getters = {
  isSubscriptionActive(state) {
    const subscription = state?.billing?.myActiveSubscription;
    if (!subscription || !subscription.ends_at) return true;
    return new Date(subscription.ends_at) > new Date();
  },
};

export default {
  state: initialState,
  actions,
  mutations,
  getters,
};
