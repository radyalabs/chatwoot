<script>
import { mapState, mapGetters } from 'vuex';
import { useAlert, useTrack } from 'dashboard/composables';
import ReportFilterSelector from './components/FilterSelector.vue';
import ReportHeader from './components/ReportHeader.vue';
import LineChart2 from '../../../../../shared/components/charts/LineChart2.vue';
import BarChart from '../../../../../shared/components/charts/BarChart.vue';
import MetricCard from './components/overview/MetricCard.vue';
import MetricCardFull from './components/overview/MetricCardFull.vue';
import AgentTable from './components/overview/AgentTableDet.vue';
import ReportsFiltersAgents from './components/Filters/Agents.vue';
import ReportsFiltersDateRange from './components/Filters/DateRange.vue';
import { GROUP_BY_FILTER, DATE_RANGE_OPTIONS } from './constants';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import ReportsAPI from 'dashboard/api/reports';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import DonutChart from '../../../../../shared/components/charts/DonutChart.vue';

export default {
  name: 'AgentReports',
  components: {
    ReportHeader,
    ReportFilterSelector,
    LineChart2,
    BarChart,
    DonutChart,
    MetricCard,
    MetricCardFull,
    AgentTable,
    ReportsFiltersAgents,
    ReportsFiltersDateRange,
  },
  data() {
    return {
      from: 0,
      to: 0,
      selectedDateRange: DATE_RANGE_OPTIONS.LAST_7_DAYS,
      selectedAgents: [],
      customDateRange: [new Date(), new Date()],
      groupBy: GROUP_BY_FILTER[1],
      dropdownOpen: false,
      metrics: {
        totalConversations: 0,
        avgFirstResponseTime: 0,
        avgResolutionTime: 0,
      },
      reportKeys: {
        CONVERSATIONS: 'conversations_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
      },
    };
  },
  computed: {
    ...mapGetters({
       handoverDataFromStore: 'getHandoverData',
       agentDailyDataFromStore: 'getAgentDailyData',
       agentPerformanceFromStore: 'getAgentPerformanceData',
    }),
    // Get user tier from route meta (passed from routes.js)
    userTier() {
      return this.$route.meta?.userTier || 'free';
    },
    // Get available export options based on tier
    availableExportOptions() {
      if (this.userTier === 'pertamax_turbo') {
        return [
          { key: 'csv', label: 'OVERVIEW_REPORTS.EXPORT_TO_CSV' },
          { key: 'pdf', label: 'OVERVIEW_REPORTS.EXPORT_TO_PDF' },
          { key: 'excel', label: 'OVERVIEW_REPORTS.EXPORT_TO_EXCEL' }
        ];
      } else if (this.userTier === 'pertamax') {
        return [
          { key: 'csv', label: 'OVERVIEW_REPORTS.EXPORT_TO_CSV' }
        ];
      }
      return [];
    },

    isDateRangeSelected() {
      return (
        this.selectedDateRange.id === DATE_RANGE_OPTIONS.CUSTOM_DATE_RANGE.id
      );
    },
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
        selectedAgents: this.selectedAgents,
        groupBy: this.groupBy?.period,
      };
    },
    handoverData() {
      const defaultData = {
        totalHandover: 0,
        handoverRate: 0,
        byAgent: [],
        reasons: { labels: [], data: [], colors: [], details: [] }
      };
      
      const data = this.handoverDataFromStore || defaultData;
      
      // Map format reasons dari backend ke format UI
      if (data.reasons && data.reasons.labels) {
        data.reasons.details = data.reasons.labels.map((label, idx) => ({
           label: label,
           value: `${data.reasons.data[idx]}%`,
           colorClass: idx === 0 ? 'bg-[#389947]' : idx === 1 ? 'bg-[#86EFAC]' : 'bg-[#D1FAE5]'
        }));
      }
      
      return data;
    },
    conversationsBarChartData() {
       if (this.agentDailyDataFromStore) {
         return this.agentDailyDataFromStore;
       }
       return { labels: [], datasets: [] };
    },
    firstResponseTimeChartData() {
      // Generate dynamic line chart data for first response time for any number of agents
      const endDate = this.to ? new Date(this.to * 1000) : new Date();
      const startDate = this.from ? new Date(this.from * 1000) : new Date(Date.now() - 6 * 24 * 60 * 60 * 1000);
      const daysDiff = Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24));
      const numDays = Math.max(1, Math.min(daysDiff, 30));
      
      // Generate timestamps
      const timestamps = [];
      for (let i = numDays - 1; i >= 0; i--) {
        const date = new Date(endDate);
        date.setDate(date.getDate() - i);
        timestamps.push(Math.floor(date.getTime() / 1000));
      }
      
      // Generate data for selected agents (or default agents if none selected)
      const agentsToShow = this.selectedAgents.length > 0 ? this.selectedAgents : [
        { id: 1, name: 'Agent 1' },
        { id: 2, name: 'Agent 2' },
        { id: 3, name: 'Agent 3' }
      ];
      
      // Generate datasets for all agents
      const datasets = agentsToShow.map((agent, index) => ({
        label: `AGENT_REPORTS.METRICS.FIRST_RESPONSE_TIME.NAME_${agent.name?.toUpperCase().replace(/\s+/g, '_') || `AGENT_${agent.id}`}`,
        data: timestamps.map(timestamp => ({
          value: Math.floor(Math.random() * 120) + 30, // 30-150 seconds
          timestamp: timestamp,
        })),
      }));
      
      return datasets;
    },
    resolutionTimeChartData() {
      // Generate dynamic line chart data for resolution time for any number of agents
      const endDate = this.to ? new Date(this.to * 1000) : new Date();
      const startDate = this.from ? new Date(this.from * 1000) : new Date(Date.now() - 6 * 24 * 60 * 60 * 1000);
      const daysDiff = Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24));
      const numDays = Math.max(1, Math.min(daysDiff, 30));
      
      // Generate timestamps
      const timestamps = [];
      for (let i = numDays - 1; i >= 0; i--) {
        const date = new Date(endDate);
        date.setDate(date.getDate() - i);
        timestamps.push(Math.floor(date.getTime() / 1000));
      }
      
      // Generate data for selected agents (or default agents if none selected)
      const agentsToShow = this.selectedAgents.length > 0 ? this.selectedAgents : [
        { id: 1, name: 'Agent 1' },
        { id: 2, name: 'Agent 2' },
        { id: 3, name: 'Agent 3' }
      ];
      
      // Generate datasets for all agents
      const datasets = agentsToShow.map((agent, index) => ({
        label: `AGENT_REPORTS.METRICS.RESOLUTION_TIME.NAME_${agent.name?.toUpperCase().replace(/\s+/g, '_') || `AGENT_${agent.id}`}`,
        data: timestamps.map(timestamp => ({
          value: Math.floor(Math.random() * 300) + 60, // 60-360 minutes
          timestamp: timestamp,
        })),
      }));
      
      return datasets;
    },
    // Agent performance table data
    agentTableData() {
      return this.agentPerformanceFromStore || [];
    },
    
    agentMetricsData() {
      return this.agentPerformanceFromStore || [];
    },
    agentPerformanceDetails() {
      // Generate performance details for each agent
      return this.agentMetricsData.map(agentMetric => {
        const agent = this.agentTableData.find(a => a.id === agentMetric.id);
        return {
          ...agent,
          ...agentMetric.metric,
        };
      });
    },
  },
  watch: {
    requestPayload(value) {
      this.fetchMetrics(value);
    },
  },
  methods: {
    fetchAllData() {
      const reportObj = {
        id: this.$route.params.accountId,
        from: this.from,
        to: this.to
      };
      
      this.$store.dispatch('fetchHandoverMetrics', reportObj);
      this.$store.dispatch('fetchAgentDailyMetrics', reportObj);
      this.$store.dispatch('fetchAgentPerformanceMetrics', reportObj);
    },
    fetchMetrics(filters) {
      if (!filters.to || !filters.from) {
        return;
      }
      
      // TODO: Implement real API call for agent metrics
      // 
      // const agentIds = filters.selectedAgents.map(agent => agent.id);
      // if (agentIds.length === 0) {
      //   // If no agents selected, fetch metrics for all agents
      //   agentIds = null; // or fetch all agents data
      // }
      //
      // ReportsAPI.getAgentMetrics({
      //   ...filters,
      //   agentIds: agentIds
      // }).then(response => {
      //   this.metrics = {
      //     totalConversations: response.data.total_conversations,
      //     avgFirstResponseTime: response.data.avg_first_response_time,
      //     avgResolutionTime: response.data.avg_resolution_time,
      //   };
      // }).catch(error => {
      //   console.error('Failed to fetch agent metrics:', error);
      //   useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
      // });
      
      // Dummy data for now
      const numAgents = this.selectedAgents.length || 3;
      this.metrics = {
        totalConversations: Math.floor(Math.random() * 500 * numAgents) + 100,
        avgFirstResponseTime: Math.floor(Math.random() * 60) + 30,
        avgResolutionTime: Math.floor(Math.random() * 180) + 60,
      };
      
      console.log('Fetching metrics for agents:', this.selectedAgents);
    },
    fetchChartData() {
      // TODO: Implement real API calls for agent-specific chart data
      // For multiple agents, we need to fetch data for each selected agent
      
      // Example of how to fetch data for multiple agents:
      // const agentIds = this.selectedAgents.map(agent => agent.id);
      // 
      // if (agentIds.length === 0) {
      //   // If no agents selected, fetch data for all agents or default set
      //   agentIds = [1, 2, 3]; // default agent IDs
      // }
      //
      // agentIds.forEach(async agentId => {
      //   Object.keys(this.reportKeys).forEach(async key => {
      //     try {
      //       await this.$store.dispatch('fetchAgentReport', {
      //         metric: this.reportKeys[key],
      //         agentId: agentId,
      //         ...this.getRequestPayload(),
      //       });
      //     } catch {
      //       useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
      //     }
      //   });
      // });
      
      console.log('Fetching chart data for agents:', this.selectedAgents);
    },
    getRequestPayload() {
      const { from, to, groupBy, selectedAgents } = this;
      return {
        from,
        to,
        groupBy: groupBy?.period,
        selectedAgents: selectedAgents.map(agent => agent.id),
        type: 'agent',
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
    onAgentsFilterSelection(selectedAgents) {
      this.selectedAgents = selectedAgents;
      this.fetchAllData();
      
      useTrack(REPORTS_EVENTS.FILTER_REPORT, {
        filterValue: selectedAgents,
        reportType: 'agent',
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
      const hasPermission = this.availableExportOptions.some(option => option.key === format);
      if (!hasPermission) {
        this.$bus.$emit('newToastMessage', {
          message: this.$t('OVERVIEW_REPORTS.EXPORT_NOT_ALLOWED'),
          type: 'error'
        });
        this.closeDropdown();
        return;
      }
      
      console.log(`Exporting data to ${format}`);
      // TODO: Implement actual export functionality
      this.closeDropdown();
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
    window.addEventListener('click', this.closeDropdownOnOutsideClick);
  },
  beforeUnmount() {
    window.removeEventListener('click', this.closeDropdownOnOutsideClick);
  },
};
</script>

<template>
  <div class="flex flex-col gap-4 pb-6">
    <ReportHeader :header-title="$t('AGENT_REPORTS.HEADER')" class="sticky">
      <div class="flex items-center gap-4">
        <!-- Filters on the left -->
        <div class="flex-grow flex gap-4">
          <ReportsFiltersDateRange @on-range-change="onDateRangeChange" />
          <ReportsFiltersAgents @agents-filter-selection="onAgentsFilterSelection" />
        </div>
        
        <!-- Export dropdown on the right -->
        <div v-if="userTier === 'pertamax' || userTier === 'pertamax_turbo'" class="relative inline-block text-left" ref="dropdownContainer">
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
            class="origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-n-solid-2 dark:bg-gray-800 ring-1 ring-black dark:ring-gray-600 ring-opacity-5 focus:outline-none"
          >
            <div class="py-1">
              <a
                v-for="option in availableExportOptions"
                :key="option.key"
                href="#"
                class="block px-4 py-2 text-sm text-gray-700 dark:text-gray-200 hover:bg-green-100 dark:hover:bg-gray-700"
                @click="exportData(option.key)"
              >
                {{ $t(option.label) }}
              </a>
            </div>
          </div>
        </div>
        <!-- <div v-else-if="userTier && userTier !== 'pertamax_turbo' && userTier !== 'pertamax'" 
            class="text-sm text-gray-500 dark:text-gray-400">
          {{ $t('OVERVIEW_REPORTS.UPGRADE_FOR_EXPORT') }}
        </div> -->
      </div>
    </ReportHeader>

    <!-- Handover Report Chart -->
    <div v-if="userTier === 'pertalite' || userTier === 'pertamax' || userTier === 'pertamax_turbo'" class="flex flex-col gap-6 w-full">
      
      <MetricCardFull class="w-full">
        <template #header>
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            {{ $t('AGENT_REPORTS.HANDOVER_REPORT.TITLE') }}
          </h3>
        </template>
        
        <div class="p-4 pt-0">
          <div class="flex flex-col sm:flex-row gap-4 mb-8">
            <div class="flex-1 p-4 bg-gray-50 dark:bg-gray-800/50 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm">
              <span class="block text-sm font-medium text-gray-500 mb-1">{{ $t('AGENT_REPORTS.HANDOVER_REPORT.TOTAL') }}</span>
              <div class="flex items-end gap-2">
                <span class="text-2xl font-bold text-green-700 dark:text-green-500">
                  {{ handoverData.totalHandover.toLocaleString() }}
                </span>
                <span class="text-xs text-gray-400 mb-1">chat</span>
              </div>
            </div>
            
            <div class="flex-1 p-4 bg-gray-50 dark:bg-gray-800/50 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm">
              <span class="block text-sm font-medium text-gray-500 mb-1">{{ $t('AGENT_REPORTS.HANDOVER_REPORT.RATE') }}</span>
              <div class="flex items-end gap-2">
                <span class="text-2xl font-bold text-green-700 dark:text-green-500">
                  {{ handoverData.handoverRate }}%
                </span>
              </div>
            </div>
          </div>

          <div class="flex flex-col gap-4 p-5 border border-gray-100 dark:border-gray-700 rounded-xl bg-gray-50 dark:bg-gray-800/50">
            <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-200 mb-2">{{ $t('AGENT_REPORTS.HANDOVER_REPORT.TOP_AGENT') }}</h4>
            <div 
              v-for="(agent, idx) in handoverData.byAgent" 
              :key="idx" 
              class="flex items-center w-full"
            >
              <div class="w-12 text-sm font-semibold text-gray-600 dark:text-gray-300">
                {{ agent.name }}
              </div>
              
              <div class="flex-1 h-8 bg-gray-200 dark:bg-gray-700 rounded-r-lg rounded-bl-lg relative ml-2 overflow-hidden shadow-inner border border-gray-200 dark:border-gray-600">
                <div 
                  class="absolute top-0 left-0 h-full bg-green-600 dark:bg-green-500 flex items-center px-3 transition-all duration-500"
                  :style="{ width: `${agent.percentage}%` }"
                >
                  <span class="text-xs font-bold text-white whitespace-nowrap drop-shadow-sm">
                    {{ agent.count }} chat
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </MetricCardFull>

      <MetricCardFull class="w-full">
        <template #header>
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
            {{ $t('AGENT_REPORTS.HANDOVER_REPORT.DISTRIBUTION') }}
          </h3>
        </template>
        
        <div class="p-4 pt-0 flex flex-col md:flex-row items-center justify-center gap-8 h-full">
          <div class="h-56 w-56 relative flex-shrink-0">
             <DonutChart
                :data="handoverData.reasons.data"
                :labels="handoverData.reasons.labels"
                :colors="handoverData.reasons.colors"
                :options="{
                  cutout: '0%', 
                  plugins: { legend: { display: false } },
                  maintainAspectRatio: false
                }"
              />
          </div>

          <div class="w-full md:w-auto flex flex-col gap-3 flex-grow justify-center">
            <div 
              v-for="(item, i) in handoverData.reasons.details" 
              :key="i"
              class="flex items-start justify-between text-sm p-2 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors"
            >
              <div class="flex items-start gap-3">
                <span :class="['w-4 h-4 rounded-md mt-0.5 flex-shrink-0 shadow-sm', item.colorClass]"></span>
                <span class="text-gray-700 dark:text-gray-200 font-medium leading-tight">
                  {{ item.label }}
                </span>
              </div>
              <span class="font-bold text-gray-900 dark:text-white ml-4">
                {{ item.value }}
              </span>
            </div>
          </div>
        </div>
      </MetricCardFull>
    </div>

    <!-- Conversations Handled Bar Chart -->
    <div class="flex flex-row flex-wrap max-w-full">
      <MetricCardFull class="w-full max-w-full">
        <div class="p-4">
          <div class="rounded-lg">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                {{ $t('AGENT_REPORTS.METRICS.CONVERSATIONS.NAME') }}
              </h3>
            </div>
            <div class="h-80">
              <BarChart
                v-if="conversationsBarChartData.datasets.length > 0"
                :data="conversationsBarChartData"
                :options="{
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: {
                    legend: {
                      display: true,
                      position: 'top',
                    },
                  },
                  scales: {
                    y: {
                      beginAtZero: true,
                      grid: {
                        display: true,
                      },
                    },
                    x: {
                      grid: {
                        display: false,
                      },
                    },
                  },
                }"
              />
              <div v-else class="flex items-center justify-center h-full">
                <span class="text-sm text-gray-600 dark:text-gray-400">
                  {{ $t('REPORT.NO_ENOUGH_DATA') }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </MetricCardFull>
    </div>

    <!-- First Response Time Line Chart -->
    <!-- <div class="flex flex-row flex-wrap max-w-full">
      <MetricCardFull class="w-full max-w-full">
        <div class="p-4">
          <div class="rounded-lg p-6">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                {{ $t('AGENT_REPORTS.METRICS.FIRST_RESPONSE_TIME.NAME') }}
              </h3>
            </div>
            <div class="h-80">
              <LineChart2
                v-if="firstResponseTimeChartData.length > 0"
                :datasets="firstResponseTimeChartData"
              />
              <div v-else class="flex items-center justify-center h-full">
                <span class="text-sm text-gray-600 dark:text-gray-400">
                  {{ $t('REPORT.NO_ENOUGH_DATA') }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </MetricCardFull>
    </div> -->

    <!-- Average Resolution Time Line Chart -->
    <!-- <div v-if="userTier === 'pertalite' || userTier === 'pertamax' || userTier === 'pertamax_turbo'" class="flex flex-row flex-wrap max-w-full">
      <MetricCardFull class="w-full max-w-full">
        <div class="p-4">
          <div class="rounded-lg p-6">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                {{ $t('AGENT_REPORTS.METRICS.RESOLUTION_TIME.NAME') }}
              </h3>
            </div>
            <div class="h-80">
              <LineChart2
                v-if="resolutionTimeChartData.length > 0"
                :datasets="resolutionTimeChartData"
              />
              <div v-else class="flex items-center justify-center h-full">
                <span class="text-sm text-gray-600 dark:text-gray-400">
                  {{ $t('REPORT.NO_ENOUGH_DATA') }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </MetricCardFull>
    </div> -->

    <!-- Agent Performance Table -->
    <div v-if="userTier === 'pertamax' || userTier === 'pertamax_turbo'" class="flex flex-row flex-wrap max-w-full">
      <MetricCard :header="$t('AGENT_REPORTS.AGENT_PERFORMANCE_TABLE.HEADER')">
        <AgentTable
          :agents="agentTableData"
          :agent-metrics="agentMetricsData"
          :page-index="0"
          :is-loading="false"
          @page-change="() => {}"
        />
      </MetricCard>
    </div>
  </div>
</template>