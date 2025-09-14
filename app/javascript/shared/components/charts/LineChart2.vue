<script setup>
import { computed } from 'vue';
import { Line } from 'vue-chartjs';
import {
  Chart as ChartJS,
  Title,
  Tooltip,
  Legend,
  BarElement,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
} from 'chart.js';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  chartOptions: {
    type: Object,
    default: () => ({}),
  },
  data1: {
    type: Object,
  },
  data2: {
    type: Object,
  },
  data3: {
    type: Object,
  },
});

ChartJS.register(
  Title,
  Tooltip,
  Legend,
  BarElement,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement
);

const fontFamily =
  'Inter,-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';

const defaultChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      display: true,
      position: 'top',
      labels: {
        fontFamily,
        usePointStyle: true,
        padding: 20,
      },
    },
  },
  animation: {
    duration: 0,
  },
  datasets: {
    bar: {
      barPercentage: 1.0,
    },
  },
  scales: {
    x: {
      ticks: {
        fontFamily: fontFamily,
      },
      grid: {
        drawOnChartArea: false,
      },
    },
    y: {
      type: 'linear',
      position: 'left',
      beginAtZero: true,
      ticks: {
        fontFamily: fontFamily,
        beginAtZero: true,
        stepSize: 1,
      },
      grid: {
        drawOnChartArea: false,
      },
    },
  },
};

const options = computed(() => {
  return { ...defaultChartOptions, ...props.chartOptions };
});

const { t } = useI18n();

const tension = 0.35;

const data = computed(() => {
  if (!props.data1) {
    return undefined;
  }
  
  const datasets = [];
  
  // Add data1 (Total Chats) - Blue
  if (props.data1?.data?.length) {
    datasets.push({
      label: t(props.data1.label),
      backgroundColor: 'rgb(59, 130, 246)', // Blue
      borderColor: 'rgb(59, 130, 246)',
      data: props.data1.data?.map(e => e.value) || [],
      tension: tension,
    });
  }
  
  // Add data2 (Bot Chats) - Green
  if (props.data2?.data?.length) {
    datasets.push({
      label: t(props.data2.label),
      backgroundColor: 'rgb(34, 197, 94)', // Green
      borderColor: 'rgb(34, 197, 94)',
      data: props.data2.data?.map(e => e.value) || [],
      tension: tension,
    });
  }
  
  // Add data3 (Agent Chats) - Orange
  if (props.data3?.data?.length) {
    datasets.push({
      label: t(props.data3.label),
      backgroundColor: 'rgb(249, 115, 22)', // Orange
      borderColor: 'rgb(249, 115, 22)',
      data: props.data3.data?.map(e => e.value) || [],
      tension: tension,
    });
  }
  
  return {
    labels:
      props.data1?.data?.map(e => {
        const date = new Date(e.timestamp * 1000);
        return `${date.getDate().toString().padStart(2, '0')}/${(date.getMonth() + 1).toString().padStart(2, '0')}`;
      }) || [],
    datasets: datasets,
  };
});
</script>

<template>
  <Line v-if="data" :data="data" :options="options" />
</template>
