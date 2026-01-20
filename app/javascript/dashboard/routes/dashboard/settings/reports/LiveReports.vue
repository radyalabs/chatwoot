<script>
import { mapGetters, mapState } from 'vuex';
import AgentTable from './components/overview/AgentTable.vue';
import MetricCard from './components/overview/MetricCard.vue';
import MetricCardFull from './components/overview/MetricCardFull.vue';
import { OVERVIEW_METRICS } from './constants';
import ReportHeatmap from './components/Heatmap.vue';
import ReportHeader from './components/ReportHeader.vue';
import ReportFilterSelector from './components/FilterSelector.vue';
import LineChart2 from '../../../../../shared/components/charts/LineChart2.vue';
import { GROUP_BY_FILTER } from './constants';
import endOfDay from 'date-fns/endOfDay';
import getUnixTime from 'date-fns/getUnixTime';
import startOfDay from 'date-fns/startOfDay';
import subDays from 'date-fns/subDays';
export const FETCH_INTERVAL = 60000;
import ConversationAnalytics from './Index.vue';
import Csat from './CsatResponses.vue';
import AgentReports from './AgentReports.vue';
import V4Button from 'dashboard/components-next/button/Button.vue';
import ReportsAPI from '../../../../api/reports';
import LabelReports from './LabelReports.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export default {
  name: 'LiveReports',
  components: {
    ReportHeader,
    ReportFilterSelector,
    AgentTable,
    MetricCard,
    MetricCardFull,
    ReportHeatmap,
    ConversationAnalytics,
    Csat,
    AgentReports,
    V4Button,
    LineChart2,
    LabelReports,
  },
  data() {
    return {
      // always start with 0, this is to manage the pagination in tanstack table
      // when we send the data, we do a +1 to this value
      activeIndex: 0,
      activeTab: 'summary',
      pageIndex: 0,
      dropdownOpen: false,
      // Filter properties
      from: 0,
      to: 0,
      groupBy: GROUP_BY_FILTER[1],
      businessHours: false,
      // heatmapData: [],
    };
  },
  computed: {
    ...mapGetters({
      agentStatus: 'agents/getAgentStatus',
      agents: 'agents/getAgents',
      accountConversationMetric: 'getAccountConversationMetric',
      agentConversationMetric: 'getAgentConversationMetric',
      accountConversationHeatmap: 'getAccountConversationHeatmapData',
      uiFlags: 'getOverviewUIFlags',
      creditUsageMetric: 'getCreditUsageMetric',
      funnelData: 'getFunnelData',
      trendData: 'getTrendData',
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    // User tier based on subscription plan
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
    hasFunnelData() {
      return this.funnelData && Number(this.funnelData.total_starter) > 0;
    },
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
        groupBy: this.groupBy?.period,
        businessHours: this.businessHours,
      };
    },
    agentStatusMetrics() {
      let metric = {};
      Object.keys(this.agentStatus).forEach(key => {
        const metricName = this.$t(
          `OVERVIEW_REPORTS.AGENT_STATUS.${OVERVIEW_METRICS[key]}`
        );
        metric[metricName] = this.agentStatus[key];
      });
      return metric;
    },
    conversationMetrics() {
      let metric = {};
      Object.keys(this.accountConversationMetric).forEach(key => {
        const metricName = this.$t(
          `OVERVIEW_REPORTS.ACCOUNT_CONVERSATIONS.${OVERVIEW_METRICS[key]}`
        );
        metric[metricName] = this.accountConversationMetric[key];
      });
      return metric;
    },
    conversationTrendData() {
      const rawData = Array.isArray(this.trendData) ? this.trendData : [];

      if (rawData.length === 0) {
        return { data1: {}, data2: {}, data3: {} };
      }

      return {
        data1: {
          label: 'OVERVIEW_REPORTS.CONVERSATION_TRENDS_LINE_CHART.TOTAL_CHATS',
          data: rawData.map(d => ({ timestamp: d.timestamp, value: d.total || 0 }))
        },
        data2: {
          label: 'OVERVIEW_REPORTS.CONVERSATION_TRENDS_LINE_CHART.BOT_CHATS', 
          data: rawData.map(d => ({ timestamp: d.timestamp, value: d.bot || 0 }))
        },
        data3: {
          label: 'OVERVIEW_REPORTS.CONVERSATION_TRENDS_LINE_CHART.AGENT_CHATS',
          data: rawData.map(d => ({ timestamp: d.timestamp, value: d.agent || 0 }))
        }
      };
    },  
    // Data untuk Funnel Chart
    funnelStats() {
      const data = this.funnelData || {};
      const num = (val) => Number(val) || 0;
      const fmt = (val) => num(val).toLocaleString();

      const totalStarter = num(data.total_starter);
      const engageUser = num(data.engage_user);
      const highIntent = num(data.high_intent);
      const assistedBot = num(data.assisted_bot);
      const assistedCs = num(data.assisted_cs);
      const repeatBuyer = num(data.repeat_buyer);
      const assistedTotal = assistedBot + assistedCs;

      const calcPercent = (val, total) => {
        if (num(total) === 0) return 0;
        return Math.round((num(val) / num(total)) * 100);
      };

      const calcWidth = (percent) => {
        return percent + '%'; 
      };

      return [
        { 
          label: this.$t('OVERVIEW_REPORTS.CONVERSATION_FUNNEL.TOTAL_STARTER'),
          description: "Jumlah total pengunjung yang memulai percakapan.",
          count: fmt(totalStarter), 
          percentVal: 100,
          displayPercent: '100%',
          colorClass: '#2563EB',
          widthStyle: '100%'
        },
        { 
          label: this.$t('OVERVIEW_REPORTS.CONVERSATION_FUNNEL.ENGAGE_USER'),
          description: "Pengunjung yang berinteraksi lebih lanjut.",
          count: fmt(engageUser), 
          percentVal: calcPercent(engageUser, totalStarter),
          displayPercent: `${calcPercent(engageUser, totalStarter)}%`,
          colorClass: '#4F46E5',
          widthStyle: calcWidth(calcPercent(engageUser, totalStarter))
        },
        { 
          label: this.$t('OVERVIEW_REPORTS.CONVERSATION_FUNNEL.HIGH_INTENT'),
          description: "Pengguna yang menunjukkan ketertarikan tinggi.",
          count: fmt(highIntent), 
          percentVal: calcPercent(highIntent, totalStarter),
          displayPercent: `${calcPercent(highIntent, totalStarter)}%`,
          colorClass: '#0D9488',
          widthStyle: calcWidth(calcPercent(highIntent, totalStarter))
        },
        { 
          label: this.$t('OVERVIEW_REPORTS.CONVERSATION_FUNNEL.ASSISTED_USER'),
          description: "Pengguna yang berhasil dibantu.",
          count: fmt(assistedTotal), 
          percentVal: calcPercent(assistedTotal, totalStarter), 
          displayPercent: `${calcPercent(assistedTotal, totalStarter)}%`,
          colorClass: '#059669',
          widthStyle: calcWidth(calcPercent(assistedTotal, totalStarter)),
          botPct: calcPercent(assistedBot, assistedTotal),
          csPct: calcPercent(assistedCs, assistedTotal)
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    // Fetch active subscription for tier checking
    this.initalizeReport();
    window.addEventListener('click', this.closeDropdownOnOutsideClick);
  },
  beforeUnmount() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
    }
    window.removeEventListener('click', this.closeDropdownOnOutsideClick);
  },
  methods: {
    onTabChange(index) {
      this.activeIndex = index;
      const tabs = ['summary', 'analytics', 'agents'];
      this.activeTab = tabs[index];
    },
    initalizeReport() {
      this.fetchAllData();
      this.scheduleReportRefresh();
    },
    scheduleReportRefresh() {
      this.timeoutId = setTimeout(async () => {
        await this.fetchAllData();
        this.scheduleReportRefresh();
      }, FETCH_INTERVAL);
    },
    fetchAllData() {
      this.fetchAccountConversationMetric();
      this.fetchAgentConversationMetric();
      this.fetchHeatmapData();
      this.fetchCreditUsageMetric();
      let currentFrom = this.from;
      let currentTo = this.to;

      const now = new Date();
      const startOfToday = getUnixTime(startOfDay(now));
      
      if (currentTo >= startOfToday) {
        currentTo = getUnixTime(endOfDay(now));
      }

      const reportObj = {
        id: this.$route.params.accountId,
        from: currentFrom,
        to: currentTo
      };
      this.$store.dispatch('fetchFunnelData', reportObj);
      this.$store.dispatch('fetchTrendData', reportObj);
    },
    fetchHeatmapData() {
      if (this.uiFlags.isFetchingAccountConversationsHeatmap) {
        return;
      }
      let to = endOfDay(new Date());
      let from = startOfDay(subDays(to, 6));

      if (this.accountConversationHeatmap.length) {
        to = endOfDay(new Date());
        from = startOfDay(to);
      }

      this.$store.dispatch('fetchAccountConversationHeatmap', {
        metric: 'conversations_count',
        from: getUnixTime(from),
        to: getUnixTime(to),
        groupBy: 'hour',
        businessHours: false,
      });
    },
    downloadHeatmapData() {
      let to = endOfDay(new Date());

      this.$store.dispatch('downloadAccountConversationHeatmap', {
        to: getUnixTime(to),
      });
    },
    fetchAccountConversationMetric() {
      this.$store.dispatch('fetchAccountConversationMetric', {
        type: 'account',
      });
    },
    fetchAgentConversationMetric() {
      this.$store.dispatch('fetchAgentConversationMetric', {
        type: 'agent',
        page: this.pageIndex + 1,
      });
    },
    fetchCreditUsageMetric() {
      this.$store.dispatch('fetchCreditUsageMetric', {
        type: 'account',
      });
    },
    onFilterChange({ from, to, groupBy, businessHours }) {
      if (
        this.from === from && 
        this.to === to && 
        this.groupBy?.period === groupBy?.period && 
        this.businessHours === businessHours
      ) {
        return;
      }
      this.from = from;
      this.to = to;
      this.groupBy = groupBy;
      this.businessHours = businessHours;
      this.fetchAllData();
    },
    onPageNumberChange(pageIndex) {
      this.pageIndex = pageIndex;
      this.fetchAgentConversationMetric();
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
};
</script>

<template>
  <div class="flex flex-col gap-4 pb-6 w-full h-full bg-slate-25 dark:bg-slate-900 overflow-auto">
    <div class="sticky top-0 z-50 bg-slate-25 dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 pt-6 shadow-sm mb-0">
      
      <div class="max-w-[960px] mx-auto w-full px-4 md:px-0">
        <div class="mb-4">
          <h1 class="text-2xl font-bold text-slate-900 dark:text-white">
            {{ $t('REPORT.TITLE') }}
          </h1>
        </div>

        <woot-tabs
          :index="activeIndex"
          class="tabs-rm-margin"
          @change="onTabChange"
        >
          <woot-tabs-item
            :index="0"
            :name="$t('OVERVIEW_REPORTS.HEADER')"
            :show-badge="false"
          />
          <woot-tabs-item
            v-if="isLabelReportsEnabled"
            :index="1"
            :name="$t('LABEL_REPORTS.HEADER')"
            :show-badge="false"
          />
          <woot-tabs-item
            :index="2"
            :name="$t('AGENT_REPORTS.HEADER')"
            :show-badge="false"
          />
        </woot-tabs>
      </div>
    </div>

    <div v-if="activeTab === 'summary'" class="flex flex-col gap-4 max-w-[960px] mx-auto w-full px-4 md:px-0">
      <ReportHeader :header-title="$t('OVERVIEW_REPORTS.HEADER')">
        <div class="flex flex-row items-center gap-2">
          
          <ReportFilterSelector
            :show-agents-filter="false"
            :show-group-by-filter="false"
            :show-business-hours-switch="false"
            :show-labels-filter="false"
            :show-inbox-filter="false"
            :show-rating-filter="false"
            :show-team-filter="false"
            :custom-date-range="{ from, to }"
            @filter-change="onFilterChange"
            class="m-0"
          />

          <div v-if="false" class="relative inline-block text-left" ref="dropdownContainer">
            <button
              @click="toggleDropdown"
              class="inline-flex justify-center w-full rounded-md border border-gray-300 dark:border-gray-600 shadow-sm px-4 py-2 text-white hover:opacity-90 transition-opacity"
              style="background-color: #389947"
            >
              {{ $t('OVERVIEW_REPORTS.DOWNLOAD') }}
              <svg xmlns="http://www.w3.org/2000/svg" class="-mr-1 ml-2 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
            
            <div v-if="dropdownOpen" class="origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-n-solid-2 dark:bg-gray-800 ring-1 ring-black dark:ring-gray-600 ring-opacity-5 focus:outline-none z-50">
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

      <div class="flex flex-col gap-4">
        <div class="w-full conversation-metric">
          <MetricCard
            :header="$t('OVERVIEW_REPORTS.CHAT_SUMMARY.HEADER')"
            :is-loading="uiFlags.isFetchingAccountConversationMetric"
            :loading-message="$t('OVERVIEW_REPORTS.ACCOUNT_CONVERSATIONS.LOADING_MESSAGE')"
          >
            <template v-if="hasFunnelData">
              <div class="flex-1 min-w-0 pb-2 pr-2">
                <h3 class="text-sm">
                  {{ $t('OVERVIEW_REPORTS.CHAT_SUMMARY.CHAT_IN') }}
                </h3>
                <p class="text-n-slate-12 text-3xl mb-0 mt-1">
                  {{ Number(funnelData?.total_starter || 0).toLocaleString() }}
                </p>
              </div>
              <div class="flex-1 min-w-0 pb-2 pr-2">
                <h3 class="text-sm">
                  {{ $t('OVERVIEW_REPORTS.CHAT_SUMMARY.CHAT_ANSWERED_BY_AI') }}
                </h3>
                <p class="text-n-slate-12 text-3xl mb-0 mt-1">
                  {{ Number(funnelData?.assisted_bot || 0).toLocaleString() }}
                </p>
              </div>
              <div class="flex-1 min-w-0 pb-2 pr-2">
                <h3 class="text-sm">
                  {{ $t('OVERVIEW_REPORTS.CHAT_SUMMARY.RESOLVED_PERCENTAGE') }}
                </h3>
                <p class="text-n-slate-12 text-3xl mb-0 mt-1">
                  {{ 
                    (funnelData?.total_starter && Number(funnelData.total_starter) > 0)
                      ? Math.round((Number(funnelData?.assisted_bot || 0) / Number(funnelData.total_starter)) * 100) 
                      : 0 
                  }}%
                </p>
              </div>
              <div class="flex-1 min-w-0 pb-2 pr-2">
                <h3 class="text-sm">
                  {{ $t('OVERVIEW_REPORTS.CHAT_SUMMARY.CHAT_HANDOVERED') }}
                </h3>
                <p class="text-n-slate-12 text-3xl mb-0 mt-1">
                  {{ Number(funnelData?.assisted_cs || 0).toLocaleString() }}
                </p>
              </div>
            </template>

            <div v-else class="flex items-center justify-center w-full py-10">
              <span class="text-sm text-gray-600 dark:text-gray-400">
                {{ $t('REPORT.NO_ENOUGH_DATA') }}
              </span>
            </div>
          </MetricCard>
        </div>
      </div>
      
      <div class="w-full">
        <MetricCardFull class="w-full max-w-full overflow-visible">
          <template #header>
            <div class="flex flex-col gap-4 w-full">
              <div class="flex items-center gap-2 flex-row">
                <h5 class="mb-0 text-n-slate-12 font-medium text-lg">
                  {{ $t('OVERVIEW_REPORTS.CONVERSATION_FUNNEL.HEADER') }}
                </h5>
                <span class="flex flex-row items-center py-0.5 px-2 rounded bg-green-700 text-white text-xs">
                  <span class="bg-white h-1 w-1 rounded-full mr-1"/>
                  {{ $t('OVERVIEW_REPORTS.LIVE') }}
                </span>
              </div>
            </div>
          </template>
          
          <div class="flex flex-col w-full items-center justify-center px-4 py-8">
            <div v-if="hasFunnelData" class="flex flex-col items-center w-full max-w-4xl">
              
              <div 
                v-for="(item, index) in funnelStats" 
                :key="index"
                class="relative group flex justify-center mb-2 transition-all duration-500 ease-in-out hover:z-50"
                :style="{ width: item.percentVal > 0 ? item.widthStyle : '100%' }"
              >
                <div 
                  v-if="item.percentVal > 0"
                  class="w-full h-16 sm:h-20 flex items-center justify-center shadow-sm text-white cursor-pointer relative rounded-md"
                  :style="{ backgroundColor: item.colorClass }"
                >
                  <div class="flex flex-col items-center justify-center leading-tight p-1">
                    <span class="text-xl sm:text-2xl font-bold drop-shadow-md whitespace-nowrap">
                      {{ item.count }} / {{ item.displayPercent }}
                    </span>
                    <span class="text-[10px] sm:text-xs font-semibold opacity-90 text-center uppercase tracking-wide px-2 whitespace-nowrap overflow-hidden text-ellipsis max-w-full">
                      {{ item.label }}
                    </span>
                  </div>
                </div>

                <div 
                  v-else
                  class="w-full h-16 sm:h-20 flex items-center justify-center rounded-md text-gray-400 dark:text-gray-500 cursor-default"
                >
                  <div class="flex flex-col items-center justify-center leading-tight p-1">
                    <span class="text-xl sm:text-2xl font-bold">
                      0 / 0%
                    </span>
                    <span class="text-[10px] sm:text-xs font-semibold text-center uppercase tracking-wide px-2">
                      {{ item.label }}
                    </span>
                  </div>
                </div>

                <div class="absolute left-[95%] top-1/2 transform -translate-y-1/2 ml-4 w-64 invisible opacity-0 group-hover:visible group-hover:opacity-100 transition-all duration-200 z-50">
                  <div class="bg-[#111827] text-white text-sm rounded-lg p-4 shadow-2xl border border-gray-700 relative z-50">
                    <div class="absolute right-[100%] top-1/2 transform -translate-y-1/2 border-y-[9px] border-y-transparent border-r-[9px] border-r-gray-700"></div>
                    
                    <div class="font-bold text-base mb-2 border-b border-gray-700 pb-2 text-white">
                      {{ item.label }}
                    </div>
                    <p class="text-gray-300 mb-3 leading-relaxed text-xs">
                      {{ item.description }}
                    </p>
                    <div class="flex justify-between items-center bg-gray-800 p-2 rounded">
                      <span class="text-gray-400 text-xs uppercase font-bold tracking-wider">Total</span>
                      <span class="font-mono text-green-400 font-bold text-lg">{{ item.count }}</span>
                    </div>
                  </div>
                </div>

              </div>
            </div>

            <div v-else class="flex items-center justify-center h-40">
              <span class="text-sm text-gray-600 dark:text-gray-400">
                {{ $t('REPORT.NO_ENOUGH_DATA') }}
              </span>
            </div>

          </div>
        </MetricCardFull>
      </div>

      <div class="flex flex-row flex-wrap max-w-full">
        <MetricCardFull class="w-full max-w-full">
          <template #header>
            <div class="flex flex-col gap-4 w-full">
              <div class="flex items-center gap-2 flex-row">
                <h5 class="mb-0 text-n-slate-12 font-medium text-lg">
                  {{ $t('OVERVIEW_REPORTS.CONVERSATION_TRENDS_LINE_CHART.HEADER') }}
                </h5>
                <span class="flex flex-row items-center py-0.5 px-2 rounded bg-green-700 dark:bg-green-700 text-white text-xs">
                  <span class="bg-white dark:bg-white h-1 w-1 rounded-full mr-1 rtl:mr-0 rtl:ml-0" />
                  <span class="text-xs text-grey-700 dark:text-grey-700">
                    {{ $t('OVERVIEW_REPORTS.LIVE') }}
                  </span>
                </span>
              </div>
              </div>
          </template>
          <div class="p-4">
            <div class="h-80">
              <LineChart2
                v-if="conversationTrendData.data1.data?.length"
                :data1="conversationTrendData.data1"
                :data2="conversationTrendData.data2"
                :data3="conversationTrendData.data3"
              />
              <div v-else class="flex items-center justify-center h-full">
                <span class="text-sm text-gray-600 dark:text-gray-400">
                  {{ $t('REPORT.NO_ENOUGH_DATA') }}
                </span>
              </div>
            </div>
          </div>
        </MetricCardFull>
      </div>
      
      <div class="flex flex-row flex-wrap max-w-full">
        <MetricCard :header="$t('OVERVIEW_REPORTS.CONVERSATION_HEATMAP.HEADER')">
          <!-- <template #control>
            <woot-button
              icon="arrow-download"
              size="small"
              variant="smooth"
              color-scheme="secondary"
              @click="downloadHeatmapData"
            >
              {{ $t('OVERVIEW_REPORTS.CONVERSATION_HEATMAP.DOWNLOAD_REPORT') }}
            </woot-button>
          </template> -->
          <ReportHeatmap
            :heat-data="accountConversationHeatmap"
            :is-loading="uiFlags.isFetchingAccountConversationsHeatmap"
          />
        </MetricCard>
      </div>

      <div v-if="userTier === 'pertamax' || userTier === 'pertamax_turbo' || userTier === 'pertalite'" class="flex flex-row flex-wrap max-w-full">
        <MetricCard :header="$t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.HEADER')">
          <AgentTable
            :agents="agents"
            :agent-metrics="agentConversationMetric"
            :page-index="pageIndex"
            :is-loading="uiFlags.isFetchingAgentConversationMetric"
            @page-change="onPageNumberChange"
          />
        </MetricCard>
      </div>
    </div>
    <div v-if="activeTab === 'analytics' && isLabelReportsEnabled" class="max-w-[960px] mx-auto w-full px-4 md:px-0">
      <LabelReports />
    </div>

    <div v-if="activeTab === 'agents'" class="max-w-[960px] mx-auto w-full px-4 md:px-0">
      <AgentReports />
    </div>
  </div>
</template>

<style lang="scss" scoped>
/* Memaksa padding kiri tab menjadi 0 agar rata dengan judul */
.tabs-rm-margin {
  ::v-deep .tabs {
    padding-left: 0px !important;
    justify-content: flex-start; /* Memastikan tab mulai dari kiri */
    margin-bottom: 0px !important; /* Menghapus margin bawah bawaan tabs jika ada */
  }
}
/* FIX: Memperbaiki posisi panah dropdown agar vertikal di tengah */
::v-deep .multiselect__select {
  top: 50% !important;
  transform: translateY(-50%) !important;
  height: auto !important;
  padding: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
}

/* Opsional: Memastikan ikon panah di dalamnya (jika menggunakan pseudo-element) juga rapi */
::v-deep .multiselect__select:before {
  top: 0 !important;
  margin-top: 0 !important;
  position: relative !important;
}
</style>