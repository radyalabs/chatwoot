import { createRouter, createWebHistory } from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import store from 'dashboard/store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import AnalyticsHelper from '../helper/AnalyticsHelper';
import { buildPermissionsFromRouter } from '../helper/permissionsHelper';

const routes = [...dashboard.routes];

export const router = createRouter({ history: createWebHistory(), routes });
export const routesWithPermissions = buildPermissionsFromRouter(routes);

const SUBSCRIPTION_EXEMPT_PREFIXES = ['billing', 'profile_settings'];

const isSubscriptionExemptRoute = routeName => {
  if (!routeName) return false;
  return SUBSCRIPTION_EXEMPT_PREFIXES.some(prefix => routeName.startsWith(prefix));
};

export const validateAuthenticateRoutePermission = async (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  if (!isLoggedIn) {
    window.location.assign('/app/login');
    return '';
  }

  if (!to.name) {
    return next(frontendURL(`accounts/${user.account_id}/dashboard`));
  }

  // Check subscription status (cached in Vuex store, fetched on boot)
  const isActive = store.getters.isSubscriptionActive;
  if (!isActive && !isSubscriptionExemptRoute(to.name)) {
    return next({
      name: 'billing_settings_index',
      params: { accountId: user.account_id },
      query: { expired: 'true' },
    });
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

export const initalizeRouter = () => {
  const userAuthentication = store.dispatch('setUser');
  let subscriptionLoaded = false;

  router.beforeEach((to, _from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    userAuthentication.then(async () => {
      // Load subscription data once on first navigation
      if (!subscriptionLoaded) {
        await store.dispatch('myActiveSubscription');
        subscriptionLoaded = true;
      }
      return validateAuthenticateRoutePermission(to, next, store);
    });
  });
};

export default router;
