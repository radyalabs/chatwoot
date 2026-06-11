import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import store from 'dashboard/store';

import AgentReportsIndex from './AgentReportsIndex.vue';
import InboxReportsIndex from './InboxReportsIndex.vue';
import TeamReportsIndex from './TeamReportsIndex.vue';

import AgentReportsShow from './AgentReportsShow.vue';
import InboxReportsShow from './InboxReportsShow.vue';
import TeamReportsShow from './TeamReportsShow.vue';

import AiAgentReports from './AiAgentReports.vue';
import AgentReports from './AgentReports.vue';
import LabelReports from './LabelReports.vue';

import CsatResponses from './CsatResponses.vue';
import BotReports from './BotReports.vue';
import LiveReports from './LiveReports.vue';
import SLAReports from './SLAReports.vue';

// --- HELPER FUNCTIONS ---

const determineTierFromText = (text) => {
  if (!text) return null;
  const lowerText = text.toString().toLowerCase();
  
  if (lowerText.includes('pertamax turbo') || lowerText.includes('unlimited')) {
    return 'pertamax_turbo';
  } else if (lowerText.includes('pertamax') || lowerText.includes('enterprise')) {
    return 'pertamax';
  } else if (lowerText.includes('pertalite') || lowerText.includes('business')) {
    return 'pertalite';
  } else if (lowerText.includes('premium')) {
    return 'premium';
  }
  return null;
};

const isCustomPlan = (subscription) => {

  if (subscription?.is_custom === true) return true;

  if (subscription?.plan?.is_custom === true) return true;

  if (subscription?.custom_attributes?.is_custom === true) return true;
  
  return false;
};

const getUserTier = () => {
  const state = store.state;
  const activeSubscription = state.billing?.billing?.myActiveSubscription || state.billing?.billing?.latestSubscription;
  
  if (isCustomPlan(activeSubscription)) {
    return 'custom';
  }

  const planName = activeSubscription?.plan_name?.toLowerCase() || ''; 
  if (planName.includes('pertamax turbo') || planName.includes('unlimited')) {
    return 'pertamax_turbo';
  } else if (planName.includes('pertamax') || planName.includes('enterprise')) {
    return 'pertamax';
  } else if (planName.includes('pertalite') || planName.includes('business')) {
    return 'pertalite';
  } else if (planName.includes('premium')) {
    return 'premium';
  }
  return 'free';
};

const hasTierAccess = (requiredTiers) => {
  const userTier = getUserTier();
  if (userTier === 'custom') return true;
  return requiredTiers.includes(userTier);
};

const checkTierAccess = (requiredTiers) => {
  return (to, from, next) => {
    if (hasTierAccess(requiredTiers)) {
      next();
    } else {
      next({ name: 'account_overview_reports', params: to.params });
    }
  };
};

// --- ROUTES DEFINITION ---

const baseOldReportRoutes = [
  {
    path: 'agent',
    name: 'agent_reports',
    meta: {
      permissions: ['administrator', 'report_manage'],
      userTier: getUserTier(),
    },
    component: AgentReports,
  },
  {
    path: 'label',
    name: 'label_reports',
    meta: {
      permissions: ['administrator', 'report_manage'],
      requiresTier: ['pertalite', 'pertamax', 'pertamax_turbo'],
      userTier: getUserTier(),
      featureFlag: FEATURE_FLAGS.REPORT_CHAT_ANALYTICS,
    },
    beforeEnter: checkTierAccess(['pertalite', 'pertamax', 'pertamax_turbo']),
    component: LabelReports,
  },
];

const revisedReportRoutes = [
  {
    path: 'agents_overview',
    name: 'agent_reports_index',
    meta: { permissions: ['administrator', 'report_manage'] },
    component: AgentReportsIndex,
  },
  {
    path: 'agents/:id',
    name: 'agent_reports_show',
    meta: { permissions: ['administrator', 'report_manage'] },
    component: AgentReportsShow,
  },
  {
    path: 'inboxes_overview',
    name: 'inbox_reports_index',
    meta: { permissions: ['administrator', 'report_manage'] },
    component: InboxReportsIndex,
  },
  {
    path: 'inboxes/:id',
    name: 'inbox_reports_show',
    meta: { permissions: ['administrator', 'report_manage'] },
    component: InboxReportsShow,
  },
  {
    path: 'teams_overview',
    name: 'team_reports_index',
    meta: { permissions: ['administrator', 'report_manage'] },
    component: TeamReportsIndex,
  },
  {
    path: 'teams/:id',
    name: 'team_reports_show',
    meta: { permissions: ['administrator', 'report_manage'] },
    component: TeamReportsShow,
  },
];

const csatRoute = {
  path: 'csat',
  name: 'csat_reports',
  meta: {
    permissions: ['administrator', 'report_manage'],
    requiresTier: ['pertalite', 'pertamax', 'pertamax_turbo'],
    userTier: getUserTier(),
  },
  beforeEnter: checkTierAccess(['pertalite', 'pertamax', 'pertamax_turbo']),
  component: CsatResponses,
};

const filteredCsatRoutes = hasTierAccess(['pertalite', 'pertamax', 'pertamax_turbo']) ? [csatRoute] : [];

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/reports'),
      component: LiveReports,
      name: 'account_overview_reports',
      meta: {
        permissions: ['administrator', 'report_manage'],
        userTier: 'free',
      },
      beforeEnter: async (to, from, next) => {
        try {
          let finalTier = 'free';
          const routeAccountId = parseInt(to.params.accountId);

          let allAccounts = store.state.accounts.records || [];
          
          if (allAccounts.length === 0) {
            try {
              await store.dispatch('accounts/get');
              allAccounts = store.state.accounts.records || [];
            } catch (err) {}
          }

          const activeAccount = allAccounts.find(acc => acc.id === routeAccountId);
          let subscription = store.state.billing?.billing?.myActiveSubscription;

          if (!subscription || !subscription.plan_name) {
             try {
                await store.dispatch(
                  'myActiveSubscription',
                  routeAccountId
                );
                subscription = store.state.billing?.billing?.myActiveSubscription;
             } catch (e) {}
          }

          const accountCustomAttrs = activeAccount?.custom_attributes || {};
          
          if (
            isCustomPlan(subscription) || 
            accountCustomAttrs.is_custom === true || 
            accountCustomAttrs.plan_is_custom === true
          ) {
            finalTier = 'custom';
          } 
          else {
            if (activeAccount) {
              const planFromAccount = accountCustomAttrs.plan_name || 
                                      accountCustomAttrs.plan_type || 
                                      accountCustomAttrs.subscription_plan || 
                                      accountCustomAttrs.pricing_plan ||
                                      accountCustomAttrs.current_plan;
              
              const accountTier = determineTierFromText(planFromAccount);
              if (accountTier) {
                finalTier = accountTier;
              }
            }

            if (finalTier === 'free' && subscription) {
              const planName = subscription.plan_name || subscription.plan?.name || '';
              const billingTier = determineTierFromText(planName);
              if (billingTier) finalTier = billingTier;
            }
          }
          
          to.meta.userTier = finalTier;

        } catch (error) {
          console.error('[Reports Route] Error checking tier:', error);
          to.meta.userTier = 'free'; 
        }
        
        next();
      }
    },
  ],
};