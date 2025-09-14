<script>
import { useAlert, useTrack } from 'dashboard/composables';
import ReportHeader from './components/ReportHeader.vue';
import BarChart from '../../../../../shared/components/charts/BarChart.vue';
import MetricCardFull from './components/overview/MetricCardFull.vue';
import ReportsFiltersLabels from './components/Filters/Labels.vue';
import ReportsFiltersDateRange from './components/Filters/DateRange.vue';
import { GROUP_BY_FILTER, DATE_RANGE_OPTIONS } from './constants';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import ReportsAPI from 'dashboard/api/reports';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import VueWordCloud from 'vuewordcloud';

export default {
  name: 'LabelReports',
  components: {
    [VueWordCloud.name]: VueWordCloud,
    ReportHeader,
    BarChart,
    MetricCardFull,
    ReportsFiltersLabels,
    ReportsFiltersDateRange,
    VueWordCloud,
  },
  data() {
    return {
      from: 0,
      to: 0,
      selectedDateRange: DATE_RANGE_OPTIONS.LAST_7_DAYS,
      selectedLabels: [],
      customDateRange: [new Date(), new Date()],
      groupBy: GROUP_BY_FILTER[1],
      dropdownOpen: false,
      showWordCloud: false,
      metrics: {
        totalTopics: 0,
        mostPopularTopic: '',
        averageTopicsPerConversation: 0,
      },
      reportKeys: {
        LABEL_USAGE: 'label_usage_count',
        POPULAR_TOPICS: 'popular_topics',
      },
      // Dummy data for word cloud
      wordCloudData: [
        ['Billing Issues', 45], 
        ['Account Access', 38], 
        ['Product Support', 32], 
        ['Technical Issues', 28], 
        ['Order Status', 24], 
        ['Refund Requests', 18], 
        ['Feature Requests', 15], 
        ['Payment Issues', 12], 
        ['Login Problems', 10], 
        ['API Questions', 8], 
        ['Integration Help', 7], 
        ['Documentation', 6], 
        ['Bug Reports', 5], 
        ['Security Concerns', 4], 
        ['Performance Issues', 3],
      ]
    };
  },
  computed: {
    isDateRangeSelected() {
      return (
        this.selectedDateRange.id === DATE_RANGE_OPTIONS.CUSTOM_DATE_RANGE.id
      );
    },
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
        selectedLabels: this.selectedLabels,
        groupBy: this.groupBy?.period,
      };
    },
    topicsBarChartData() {
      // Generate dummy data for most popular topics
      const topics = [
        { topic: 'Billing Issues', count: 45 },
        { topic: 'Account Access', count: 38 },
        { topic: 'Product Support', count: 32 },
        { topic: 'Technical Issues', count: 28 },
        { topic: 'Order Status', count: 24 },
        { topic: 'Refund Requests', count: 18 },
        { topic: 'Feature Requests', count: 15 },
        { topic: 'Payment Issues', count: 12 },
      ];

      return {
        labels: topics.map(t => t.topic),
        datasets: [
          {
            label: 'Topic Frequency',
            data: topics.map(t => t.count),
            backgroundColor: '#3B82F6',
            borderColor: '#2563EB',
            borderWidth: 1,
          }
        ]
      };
    },
    topicsBarChartOptions() {
      return {
        indexAxis: 'y', // This makes it horizontal
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false,
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: {
              stepSize: 5,
            },
            grid: {
              display: true,
            },
          },
          y: {
            grid: {
              display: false,
            },
          },
        },
      };
    },
  },
  watch: {
    requestPayload(value) {
      this.fetchMetrics(value);
    },
  },
  methods: {
    fetchAllData() {
      this.fetchMetrics(this.requestPayload);
      this.fetchChartData();
    },
    fetchMetrics(filters) {
      if (!filters.to || !filters.from) {
        return;
      }
      
      // TODO: Implement real API call for label metrics
      // 
      // const labelIds = filters.selectedLabels.map(label => label.id);
      // if (labelIds.length === 0) {
      //   // If no labels selected, fetch metrics for all labels
      //   labelIds = null; // or fetch all labels data
      // }
      //
      // ReportsAPI.getLabelMetrics({
      //   ...filters,
      //   labelIds: labelIds
      // }).then(response => {
      //   this.metrics = {
      //     totalTopics: response.data.total_topics,
      //     mostPopularTopic: response.data.most_popular_topic,
      //     averageTopicsPerConversation: response.data.avg_topics_per_conversation,
      //   };
      // }).catch(error => {
      //   console.error('Failed to fetch label metrics:', error);
      //   useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
      // });
      
      // Dummy data for now
      const numLabels = this.selectedLabels.length || 8;
      this.metrics = {
        totalTopics: Math.floor(Math.random() * 50 * numLabels) + 20,
        mostPopularTopic: 'Billing Issues',
        averageTopicsPerConversation: (Math.random() * 3 + 1).toFixed(1),
      };
      
      console.log('Fetching metrics for labels:', this.selectedLabels);
    },
    fetchChartData() {
      // TODO: Implement real API calls for label-specific chart data
      // For multiple labels, we need to fetch data for each selected label
      
      // Example of how to fetch data for multiple labels:
      // const labelIds = this.selectedLabels.map(label => label.id);
      // 
      // if (labelIds.length === 0) {
      //   // If no labels selected, fetch data for all labels or default set
      //   labelIds = [1, 2, 3, 4, 5, 6, 7, 8]; // default label IDs
      // }
      //
      // labelIds.forEach(async labelId => {
      //   Object.keys(this.reportKeys).forEach(async key => {
      //     try {
      //       await this.$store.dispatch('fetchLabelReport', {
      //         metric: this.reportKeys[key],
      //         labelId: labelId,
      //         ...this.getRequestPayload(),
      //       });
      //     } catch {
      //       useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
      //     }
      //   });
      // });
      
      console.log('Fetching chart data for labels:', this.selectedLabels);
    },
    getRequestPayload() {
      const { from, to, groupBy, selectedLabels } = this;
      return {
        from,
        to,
        groupBy: groupBy?.period,
        selectedLabels: selectedLabels.map(label => label.id),
        type: 'label',
      };
    },
    onDateRangeChange(selectedRange) {
      this.selectedDateRange = selectedRange;
      this.calculateDateRange();
      this.fetchAllData();
    },
    onCustomDateRangeChange(value) {
      this.customDateRange = value;
      this.calculateDateRange();
      this.fetchAllData();
    },
    onLabelsFilterSelection(selectedLabels) {
      this.selectedLabels = selectedLabels;
      this.fetchAllData();
      
      useTrack(REPORTS_EVENTS.FILTER_REPORT, {
        filterValue: selectedLabels,
        reportType: 'label',
      });
    },
    calculateDateRange() {
      if (this.isDateRangeSelected) {
        this.to = getUnixEndOfDay(this.customDateRange[1]);
        this.from = getUnixStartOfDay(this.customDateRange[0]);
      } else {
        this.to = getUnixEndOfDay(new Date());
        const { offset } = this.selectedDateRange;
        const fromDate = subDays(new Date(), offset);
        this.from = getUnixStartOfDay(fromDate);
      }
    },
    toggleDropdown() {
      this.dropdownOpen = !this.dropdownOpen;
    },
    closeDropdown() {
      this.dropdownOpen = false;
    },
    exportData(format) {
      console.log(`Exporting label data to ${format}`);
      this.closeDropdown();
    },
    toggleWordCloud() {
      this.showWordCloud = !this.showWordCloud;
    },
    closeDropdownOnOutsideClick(event) {
      if (!this.dropdownOpen) return;
      const dropdownContainer = this.$refs.dropdownContainer;
      if (dropdownContainer && !dropdownContainer.contains(event.target)) {
        this.closeDropdown();
      }
    },
  },
  mounted() {
    this.calculateDateRange();
    this.fetchAllData();
    console.log('Word cloud data:', this.wordCloudData);
    window.addEventListener('click', this.closeDropdownOnOutsideClick);
  },
  beforeUnmount() {
    window.removeEventListener('click', this.closeDropdownOnOutsideClick);
  },
};
</script>

<template>
  <div class="flex flex-col gap-4 pb-6">
    <ReportHeader :header-title="$t('LABEL_REPORTS.HEADER')" class="sticky">
      <div class="flex items-center gap-4">
        <!-- Filters on the left -->
        <div class="flex-grow flex gap-4">
          <ReportsFiltersDateRange @on-range-change="onDateRangeChange" />
          <ReportsFiltersLabels @labels-filter-selection="onLabelsFilterSelection" />
        </div>
        
        <!-- Export dropdown on the right -->
        <div class="relative inline-block text-left" ref="dropdownContainer">
          <button
            @click="toggleDropdown"
            class="inline-flex justify-center w-full rounded-md border border-gray-300 dark:border-gray-600 shadow-sm px-4 py-2 text-white hover:opacity-90 transition-opacity"
            style="background-color: #389947"
          >
            {{ $t('OVERVIEW_REPORTS.DOWNLOAD') }}
            <svg
              class="-mr-1 ml-2 h-5 w-5"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                clip-rule="evenodd"
              />
            </svg>
          </button>
          <div
            v-if="dropdownOpen"
            class="origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black dark:ring-gray-600 ring-opacity-5 focus:outline-none"
          >
            <div class="py-1">
              <button
                @click="exportData('csv')"
                class="block w-full text-left px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
              >
                {{ $t('OVERVIEW_REPORTS.EXPORT_TO_CSV') }}
              </button>
              <button
                @click="exportData('pdf')"
                class="block w-full text-left px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
              >
                {{ $t('OVERVIEW_REPORTS.EXPORT_TO_PDF') }}
              </button>
              <button
                @click="exportData('excel')"
                class="block w-full text-left px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
              >
                {{ $t('OVERVIEW_REPORTS.EXPORT_TO_EXCEL') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </ReportHeader>
    
    <!-- Topics Analysis Section -->
    <div class="flex flex-row flex-wrap max-w-full">
      <MetricCardFull>
        <div class="p-4 pt-0">
          <div class="rounded-lg p-6">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                {{ $t('LABEL_REPORTS.TOPICS_ANALYSIS.HEADER') }}
              </h3>
              
              <!-- Toggle button for word cloud -->
              <button
                @click="toggleWordCloud"
                class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
              >
                <svg
                  class="w-4 h-4 mr-2"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 0h10M7 4v16a1 1 0 001 1h8a1 1 0 001-1V4M7 4H5a1 1 0 00-1 1v16a1 1 0 001 1h2"
                  />
                </svg>
                {{ showWordCloud ? $t('LABEL_REPORTS.SHOW_CHART') : $t('LABEL_REPORTS.SHOW_WORD_CLOUD') }}
              </button>
            </div>
            
            <!-- Bar Chart View -->
            <div v-if="!showWordCloud" class="h-80">
              <BarChart
                v-if="topicsBarChartData.datasets[0].data.length > 0"
                :data="topicsBarChartData"
                :options="topicsBarChartOptions"
              />
              <div v-else class="flex items-center justify-center h-full">
                <span class="text-sm text-gray-600 dark:text-gray-400">
                  {{ $t('REPORT.NO_ENOUGH_DATA') }}
                </span>
              </div>
            </div>

            <!-- Word Cloud View -->
            <div v-else class="h-80 flex items-center justify-center">
              <vue-word-cloud
                style="
                  height: 480px;
                  width: 640px;
                "
                :words="wordCloudData"
                :color="([, weight]) => weight > 10 ? 'Green' : weight > 5 ? 'RoyalBlue' : 'Indigo'"
                font-family="Roboto"
              />
            </div>
          </div>
        </div>
      </MetricCardFull>
    </div>
  </div>
</template>
