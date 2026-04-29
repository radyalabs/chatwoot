<script setup>
import { computed } from 'vue';
import BarChart from 'shared/components/charts/BarChart.vue';

const props = defineProps({
  componentData: { type: Object, default: () => ({}) },
});

const prepareData = sourceData => {
  const labels = [], data = [];
  sourceData.forEach(item => { labels.push(item[0]); data.push(item[1]); });
  return {
    labels,
    datasets: [{
      type: 'bar',
      backgroundColor: 'rgba(55,138,221,0.85)',
      borderRadius: 6,
      borderSkipped: false,
      yAxisID: 'y',
      label: 'Conversations',
      data,
    }],
  };
};

const chartData = computed(() => prepareData(props.componentData.chartData));

const {
  accountsCount, accountsSubscriptionsCount,
  accountsActiveCount, accountsExpiredCount,
  administratorsCount, agentsCount,
  usersCount, inboxesCount, conversationsCount,
} = props.componentData;

const cardGroups = [
  {
    group: 'Accounts',
    color: 'blue',
    cards: [
      { label: 'Total',         value: accountsCount },
      { label: 'Subscriptions', value: accountsSubscriptionsCount },
      { label: 'Active',        value: accountsActiveCount },
      { label: 'Expired',       value: accountsExpiredCount },
    ],
  },
  {
    group: 'Users',
    color: 'teal',
    cards: [
      { label: 'Total',          value: usersCount },
      { label: 'Administrators', value: administratorsCount },
      { label: 'Agents',         value: agentsCount },
    ],
  },
  {
    group: 'Activity',
    color: 'amber',
    cards: [
      { label: 'Inboxes',        value: inboxesCount,        color: 'amber' },
      { label: 'Conversations',  value: conversationsCount,  color: 'coral' },
    ],
  },
];
</script>

<template>
  <div class="w-full h-full p-6">
    <header class="main-content__header" role="banner">
      <h1 id="page-title" class="main-content__page-title">Admin Dashboard</h1>
    </header>

    <section v-for="group in cardGroups" :key="group.group" class="card-group">
      <div class="card-group__label">{{ group.group }}</div>
      <div class="cards-grid">
        <div
          v-for="card in group.cards"
          :key="card.label"
          :class="['metric-card', `metric-card--${card.color ?? group.color}`]"
        >
          <div class="metric-card__accent" />
          <div class="metric-card__value">{{ card.value?.toLocaleString() ?? '—' }}</div>
          <div class="metric-card__label">{{ card.label }}</div>
        </div>
      </div>
    </section>

    <section class="chart-section">
      <div class="chart-title">Conversations over time</div>
      <BarChart class="w-full" :collection="chartData" style="max-height: 400px" />
    </section>
  </div>
</template>

<style scoped>
.card-group { margin-bottom: 1.5rem; }

.card-group__label {
  font-size: 11px;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.07em;
  color: #6b7280;
  margin-bottom: 8px;
  padding-left: 2px;
}

.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
  gap: 10px;
}

.metric-card {
  background: #fff;
  border: 0.5px solid #e5e7eb;
  border-radius: 12px;
  padding: 0.875rem 1rem;
  position: relative;
  overflow: hidden;
  transition: border-color 0.2s;
}
.metric-card:hover { border-color: #d1d5db; }

.metric-card__accent {
  position: absolute;
  top: 0; left: 0; right: 0;
  height: 3px;
  border-radius: 12px 12px 0 0;
}
.metric-card--blue  .metric-card__accent { background: #378ADD; }
.metric-card--teal  .metric-card__accent { background: #1D9E75; }
.metric-card--amber .metric-card__accent { background: #EF9F27; }
.metric-card--coral .metric-card__accent { background: #D85A30; }

.metric-card__value {
  font-size: 24px;
  font-weight: 500;
  color: #111;
  line-height: 1;
  margin-bottom: 5px;
}

.metric-card__label {
  font-size: 12px;
  color: #6b7280;
}

.chart-section {
  background: #fff;
  border: 0.5px solid #e5e7eb;
  border-radius: 12px;
  padding: 1.25rem;
}

.chart-title {
  font-size: 14px;
  font-weight: 500;
  color: #111;
  margin-bottom: 1rem;
}
</style>