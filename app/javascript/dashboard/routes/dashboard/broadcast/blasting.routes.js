import { frontendURL } from '../../../helper/URLHelper';

// Lazy load komponen
const BlastingWrapper = () => import('./Index.vue');
const BroadcastList = () => import('./BroadcastList.vue'); // File baru yang akan kita buat
const BroadcastForm = () => import('./BroadcastForm.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/blasting'),
      component: BlastingWrapper,
      children: [
        {
          path: '', // Rute default saat menu sidebar diklik
          name: 'blasting_index',
          component: BroadcastList,
          meta: { permissions: ['administrator'] },
        },
        {
          path: 'new',
          name: 'new_broadcast',
          component: BroadcastForm,
          meta: { permissions: ['administrator'] },
        },
        {
          path: ':id',
          name: 'broadcast_detail',
          meta: { permissions: ['administrator'] },
          component: () => import('./BroadcastDetail.vue'),
        },
      ],
    },
  ],
};