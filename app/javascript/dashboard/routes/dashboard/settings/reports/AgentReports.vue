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
    userTier() {
      return this.$route.meta?.userTier || 'free';
    },
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
    agentTableData() {
      return this.agentPerformanceFromStore || [];
    },
    agentMetricsData() {
      return this.agentPerformanceFromStore || [];
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
      // Dummy implementation for metrics if needed
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
    // Debug logging removed
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
    <ReportHeader :header-title="$t('AGENT_REPORTS.HEADER')" class="sticky top-0 z-40">
      <div class="flex items-center gap-4">
        <div class="flex-grow flex gap-4">
          <ReportsFiltersDateRange @on-range-change="onDateRangeChange" />
          <ReportsFiltersAgents @agents-filter-selection="onAgentsFilterSelection" />
        </div>
        
        <div v-if="false" class="relative inline-block text-left" ref="dropdownContainer">
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
      </div>
    </ReportHeader>

    <div class="flex flex-col gap-6 w-full">
      
      <MetricCardFull class="w-full">
        <template #header>
          <div class="flex flex-col gap-4 w-full mb-4">
            <div class="flex items-center gap-2 flex-row">
              <h3 class="text-lg font-bold text-gray-900 dark:text-white">
                {{ $t('AGENT_REPORTS.HANDOVER_REPORT.TITLE') }}
              </h3>
              <span class="flex flex-row items-center py-0.5 px-2 rounded bg-green-700 text-white text-xs">
                <span class="bg-white h-1 w-1 rounded-full mr-1"/>
                {{ $t('OVERVIEW_REPORTS.LIVE') }}
              </span>
            </div>
          </div>
        </template>
        
        <div class="p-4 pt-0">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            
            <div class="flex flex-col gap-4 lg:col-span-1 h-full">
              
              <div class="relative overflow-hidden p-5 text-gray-900 dark:text-white rounded-xl border border-gray-100 dark:border-gray-700 shadow-sm group transition-all flex-1 flex flex-col justify-center">
                <div class="absolute right-0 top-0 p-3 opacity-20 dark:opacity-10 transition-transform duration-500">
                  <svg class="w-16 h-16 text-green-600" fill="currentColor" viewBox="0 0 20 20"><path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z"/></svg>
                </div>
                <span class="block text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">
                  {{ $t('AGENT_REPORTS.HANDOVER_REPORT.TOTAL') }}
                </span>
                <div class="flex items-baseline gap-2 relative z-10">
                  <span class="text-3xl font-extrabold text-gray-900 dark:text-white">
                    {{ handoverData.totalHandover.toLocaleString() }}
                  </span>
                  <span class="text-sm font-medium text-gray-400">chat</span>
                </div>
              </div>

              <div class="relative overflow-hidden p-5 text-gray-900 dark:text-white rounded-xl border border-gray-100 dark:border-gray-700 shadow-sm group transition-all flex-1 flex flex-col justify-center">
                <span class="block text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">
                  {{ $t('AGENT_REPORTS.HANDOVER_REPORT.RATE') }}
                </span>
                <div class="flex items-center gap-3">
                   <div class="relative w-16 h-16">
                      <svg class="w-full h-full transform -rotate-90">
                        <circle cx="32" cy="32" r="28" stroke="currentColor" stroke-width="6" fill="transparent" class="text-gray-500 dark:text-gray-700" />
                        <circle cx="32" cy="32" r="28" stroke="currentColor" stroke-width="6" fill="transparent" 
                          :stroke-dasharray="2 * Math.PI * 28" 
                          :stroke-dashoffset="2 * Math.PI * 28 * (1 - handoverData.handoverRate / 100)"
                          class="text-green-600 dark:text-green-500 transition-all duration-1000 ease-out" />
                      </svg>
                      <div class="absolute inset-0 flex items-center justify-center text-xs font-bold text-gray-900 dark:text-white">
                        {{ handoverData.handoverRate }}%
                      </div>
                   </div>
                   <div class="flex flex-col">
                      <span class="text-xs text-gray-400">{{ $t('AGENT_REPORTS.CON_RATE') }}</span>
                   </div>
                </div>
              </div>
            </div>

            <div class="lg:col-span-2 bg-gray-50 dark:bg-gray-800/50 rounded-xl border border-gray-200 dark:border-gray-700 p-5 flex flex-col gap-4">
              
              <div class="flex items-center justify-between">
                <h4 class="text-sm font-bold text-gray-700 dark:text-gray-200 uppercase tracking-wide text-xs">
                  {{ $t('AGENT_REPORTS.HANDOVER_REPORT.TOP_AGENT') }}
                </h4>
              </div>

              <div class="flex flex-col gap-6 overflow-y-auto max-h-[280px] pr-2 custom-scrollbar">
                <div 
                  v-for="(agent, idx) in handoverData.byAgent" 
                  :key="idx" 
                  class="group w-full"
                >
                  <div class="flex justify-between items-start mb-3">
                    <div class="flex items-center gap-4">
                        <div class="w-12 h-12 rounded-full bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-400 flex items-center justify-center text-lg font-bold shadow-sm border border-green-200 dark:border-green-800">
                            {{ agent.name.charAt(0) }}
                        </div>
                        <div class="flex flex-col">
                            <span class="text-base font-bold text-gray-900 dark:text-white leading-tight">
                                {{ agent.name }}
                            </span>
                            <span class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                                {{ agent.count }} {{ $t('AGENT_REPORTS.HANDOVER_REPORT.CHAT_REDIRECTED') }}
                            </span>
                        </div>
                    </div>
                    <div class="text-right">
                        <div class="text-lg font-extrabold text-green-600 dark:text-green-400 leading-tight">
                            {{ agent.percentage }}%
                        </div>
                        <span class="text-xs font-medium text-gray-400">
                            dari total
                        </span>
                    </div>
                  </div>

                  <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3 overflow-hidden shadow-inner">
                    <div 
                      class="bg-[#389947] h-3 rounded-full transition-all duration-1000 ease-out relative"
                      :style="{ width: `${agent.percentage}%` }"
                    >
                        <div class="absolute top-0 left-0 bottom-0 right-0 bg-gradient-to-r from-transparent via-white/20 to-transparent w-full -translate-x-full group-hover:animate-shimmer"></div>
                    </div>
                  </div>
                  </div>
                
                <div v-if="!handoverData.byAgent.length" class="flex flex-col items-center justify-center py-10 text-center h-full">
                   <div class="inline-flex items-center justify-center w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 mb-3 text-gray-400">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path></svg>
                    </div>
                    <p class="text-sm text-gray-500 dark:text-gray-400 font-medium">
                        {{ $t('REPORT.NO_ENOUGH_DATA') }}
                    </p>
                </div>
              </div>
            </div>

          </div>
        </div>
      </MetricCardFull>

      <MetricCardFull v-if="false" class="w-full">
        <template #header>
          <div class="flex flex-col gap-4 w-full mb-4">
            <div class="flex items-center gap-2 flex-row">
              <h3 class="text-lg font-bold text-gray-900 dark:text-white">
                {{ $t('AGENT_REPORTS.HANDOVER_REPORT.DISTRIBUTION') }}
              </h3>
              <span class="flex flex-row items-center py-0.5 px-2 rounded bg-green-700 text-white text-xs">
                <span class="bg-white h-1 w-1 rounded-full mr-1"/>
                {{ $t('OVERVIEW_REPORTS.LIVE') }}
              </span>
            </div>
          </div>
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

    <div class="flex flex-row flex-wrap max-w-full">
      <MetricCardFull class="w-full max-w-full">
        <div class="p-4">
          <div class="rounded-lg">
            <div class="flex flex-col gap-4 w-full mb-4">
              <div class="flex items-center gap-2 flex-row">
                <h3 class="text-lg font-bold text-gray-900 dark:text-white">
                  {{ $t('AGENT_REPORTS.METRICS.CONVERSATIONS.NAME') }}
                </h3>
                <span class="flex flex-row items-center py-0.5 px-2 rounded bg-green-700 text-white text-xs">
                  <span class="bg-white h-1 w-1 rounded-full mr-1"/>
                  {{ $t('OVERVIEW_REPORTS.LIVE') }}
                </span>
              </div>
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

    <div class="flex flex-row flex-wrap max-w-full">
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