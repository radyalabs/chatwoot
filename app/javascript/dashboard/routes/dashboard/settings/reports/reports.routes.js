import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import store from 'dashboard/store';

import ReportsWrapper from './components/ReportsWrapper.vue';
import Index from './Index.vue';

import AgentReportsIndex from './AgentReportsIndex.vue';
import InboxReportsIndex from './InboxReportsIndex.vue';
import TeamReportsIndex from './TeamReportsIndex.vue';

import AgentReportsShow from './AgentReportsShow.vue';
import InboxReportsShow from './InboxReportsShow.vue';
import TeamReportsShow from './TeamReportsShow.vue';

import AiAgentReports from './AiAgentReports.vue';
import AgentReports from './AgentReports.vue';
import InboxReports from './InboxReports.vue';
import LabelReports from './LabelReports.vue';
import TeamReports from './TeamReports.vue';

import CsatResponses from './CsatResponses.vue';
import BotReports from './BotReports.vue';
import LiveReports from './LiveReports.vue';
import SLAReports from './SLAReports.vue';

const isFeatureEnabled = (featureFlag) => {
  if (!featureFlag) return true;
  
  const state = store.state;
  
  // Try multiple ways to get account ID
  const accountId = state.route?.params?.accountId || 
                    state.auth?.currentAccountId ||
                    state.accounts?.currentAccountId;
  
  if (!accountId) return false;
  
  const accounts = state.accounts?.accounts;
  const account = accounts?.find(acc => acc.id === parseInt(accountId) || acc.account_id === parseInt(accountId));
  const features = account?.features || {};
  
  // If features object is empty or feature flag not defined, default to FALSE (hidden)
  if (!features || Object.keys(features).length === 0) {
    return false;
  }
  
  return features[featureFlag] === true;
};

// Function to check user tier access
const checkTierAccess = (requiredTiers) => {
  return (to, from, next) => {
    const state = store.state;
    const activeSubscription = state.billing?.billing?.myActiveSubscription || state.billing?.billing?.latestSubscription;
    
    // Get plan name from subscription
    // const planName = activeSubscription?.plan_name?.toLowerCase() || '';
    const planName = 'pertamax turbo'
    // Determine user tier
    let userTier = 'free';
    if (planName.includes('pertamax turbo') || planName.includes('unlimited')) {
      userTier = 'pertamax_turbo';
    } else if (planName.includes('pertamax') || planName.includes('enterprise')) {
      userTier = 'pertamax';
    } else if (planName.includes('pertalite') || planName.includes('business')) {
      userTier = 'pertalite';
    } else if (planName.includes('premium')) {
      userTier = 'premium';
    }
    
    // Check if user tier is in required tiers
    if (requiredTiers.includes(userTier)) {
      next();
    } else {
      // Redirect to overview if access denied
      next({ name: 'account_overview_reports', params: to.params });
    }
  };
};

const getUserTier = () => {
  const state = store.state;
  const activeSubscription = state.billing?.billing?.myActiveSubscription || state.billing?.billing?.latestSubscription;
  const planName = 'pertamax turbo'; // TEMPORARY 
  // const planName = activeSubscription?.plan_name?.toLowerCase() || ''; 
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
  return requiredTiers.includes(userTier);
};

const baseOldReportRoutes = [
  {
    path: 'agent',
    name: 'agent_reports',
    meta: {
      permissions: ['administrator', 'report_manage'],
      userTier: getUserTier(), // Pass the current user tier to the component
      featureFlag: FEATURE_FLAGS.REPORT_AGENT, 
    },
    component: AgentReports,
  },
  // {
  //   path: 'inboxes',
  //   name: 'inbox_reports',
  //   meta: {
  //     permissions: ['administrator', 'report_manage'],
  //   },
  //   component: InboxReports,
  // },
  {
    path: 'label',
    name: 'label_reports',
    meta: {
      permissions: ['administrator', 'report_manage'],
      requiresTier: ['pertalite', 'pertamax', 'pertamax_turbo'], // Add tier requirement
      userTier: getUserTier(), // Pass the current user tier to the component
      featureFlag: FEATURE_FLAGS.REPORT_CHAT_ANALYTICS,
    },
    beforeEnter: checkTierAccess(['pertalite', 'pertamax', 'pertamax_turbo']),
    component: LabelReports,
  },
  // {
  //   path: 'teams',
  //   name: 'team_reports',
  //   meta: {
  //     permissions: ['administrator', 'report_manage'],
  //   },
  //   component: TeamReports,
  // },
];

// Filter routes based on user tier
const oldReportRoutes = baseOldReportRoutes.filter(route => {
  // Check tier access
  if (route.meta.requiresTier && !hasTierAccess(route.meta.requiresTier)) {
    return false;
  }
  
  // Check feature flag
  if (route.meta.featureFlag && !isFeatureEnabled(route.meta.featureFlag)) {
    return false;
  }
  
  return true;
});

const revisedReportRoutes = [
  {
    path: 'agents_overview',
    name: 'agent_reports_index',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: AgentReportsIndex,
  },
  {
    path: 'agents/:id',
    name: 'agent_reports_show',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: AgentReportsShow,
  },

  {
    path: 'inboxes_overview',
    name: 'inbox_reports_index',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: InboxReportsIndex,
  },
  {
    path: 'inboxes/:id',
    name: 'inbox_reports_show',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: InboxReportsShow,
  },
  {
    path: 'teams_overview',
    name: 'team_reports_index',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: TeamReportsIndex,
  },
  {
    path: 'teams/:id',
    name: 'team_reports_show',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: TeamReportsShow,
  },
];

// Base CSAT route
const csatRoute = {
  path: 'csat',
  name: 'csat_reports',
  meta: {
    permissions: ['administrator', 'report_manage'],
    requiresTier: ['pertalite', 'pertamax', 'pertamax_turbo'], // Add tier requirement
    userTier: getUserTier(), // Pass the current user tier to the component
  },
  beforeEnter: checkTierAccess(['pertalite', 'pertamax', 'pertamax_turbo']),
  component: CsatResponses,
};

// Filter CSAT route based on tier
const filteredCsatRoutes = hasTierAccess(['pertalite', 'pertamax', 'pertamax_turbo']) ? [csatRoute] : [];

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/reports'),
      component: ReportsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'account_overview_reports', params: to.params };
          },
        },
        {
          path: 'overview',
          name: 'account_overview_reports',
          meta: {
            permissions: ['administrator', 'report_manage'],
            userTier: getUserTier(),
          },
          component: LiveReports,
        },
        // {
        //   path: 'conversation',
        //   name: 'conversation_reports',
        //   meta: {
        //     permissions: ['administrator', 'report_manage'],
        //   },
        //   component: Index,
        // },
        {
          path: 'ai-agent',
          name: 'ai_agent__reports',
          meta: {
            permissions: ['administrator', 'report_manage'],
            userTier: getUserTier(), // Pass the current user tier to the component
          },
          component: AiAgentReports,
        },
        ...oldReportRoutes,
        ...revisedReportRoutes,
        {
          path: 'sla',
          name: 'sla_reports',
          meta: {
            permissions: ['administrator', 'report_manage'],
            featureFlag: FEATURE_FLAGS.SLA,
          },
          component: SLAReports,
        },
        ...filteredCsatRoutes, // Use filtered CSAT routes instead of hardcoded one
        {
          path: 'bot',
          name: 'bot_reports',
          meta: {
            permissions: ['administrator', 'report_manage'],
          },
          component: BotReports,
        },
      ],
    },
  ],
};