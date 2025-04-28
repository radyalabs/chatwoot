<script setup>
import { computed } from 'vue';
import LineChart from '../../../../../shared/components/charts/LineChart.vue';
import ChartStats2 from './components/ChartElements/ChartStats2.vue';
import { useMapGetter } from 'dashboard/composables/store';

const accountReports = useMapGetter('getAccountReports')

const aiUsage = computed(() => {
    const data1 = accountReports.value?.data?.ai_agent_credit_usage || []
    return {
        data1: {
            label: 'REPORT.METRICS.AI_CREDIT_USE.NAME',
            data: data1,
        },
        data2: {
            label: 'REPORT.METRICS.AI_MESSAGE_SEND.NAME',
            data: accountReports.value?.data?.ai_agent_message_send_count || [],
        },
        totalAiAgentCreditUsage: 9,
    }
})
const agentHandoff = computed(() => {
    const data1 = accountReports.value?.data?.ai_agent_handoff_count || []
    return {
        data1: {
            label: 'REPORT.METRICS.HANDOFF_AI_AGENT.NAME',
            data: data1,
        },
        data2: {
            label: 'REPORT.METRICS.HANDOFF_HUMAN_AGENT.NAME',
            data: accountReports.value?.data?.agent_handoff_count || [],
        },
        totalAiAgentCreditUsage: 9,
    }
})
</script>

<template>
    <div
        class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
        <div class="p-4 mb-3 rounded-md">
            <ChartStats2 :title="$t('REPORT.METRICS.AI_MESSAGE_USAGE.NAME')"
                :desc="`${aiUsage.totalAiAgentCreditUsage}`" :legend1="aiUsage.data1.label"
                :legend2="aiUsage.data2.label" />
            <div class="mt-4 h-72">
                <woot-loading-state v-if="accountReports.isFetching.ai_agent_message_send_count" class="text-xs"
                    :message="$t('REPORT.LOADING_CHART')" />
                <div v-else class="flex items-center justify-center h-72">
                    <LineChart v-if="aiUsage.data1.data?.length" :data1="aiUsage.data1" :data2="aiUsage.data2" />
                    <span v-else class="text-sm text-slate-600">
                        {{ $t('REPORT.NO_ENOUGH_DATA') }}
                    </span>
                </div>
            </div>
        </div>
        <div class="p-4 mb-3 rounded-md">
            <ChartStats2 :title="$t('REPORT.METRICS.AI_MESSAGE_USAGE.NAME')"
                :desc="`${agentHandoff.totalAiAgentCreditUsage}`" :legend1="agentHandoff.data1.label"
                :legend2="agentHandoff.data2.label" />
            <div class="mt-4 h-72">
                <woot-loading-state v-if="accountReports.isFetching.ai_agent_message_send_count" class="text-xs"
                    :message="$t('REPORT.LOADING_CHART')" />
                <div v-else class="flex items-center justify-center h-72">
                    <LineChart v-if="agentHandoff.data1.data?.length" :data1="agentHandoff.data1"
                        :data2="agentHandoff.data2" />
                    <span v-else class="text-sm text-slate-600">
                        {{ $t('REPORT.NO_ENOUGH_DATA') }}
                    </span>
                </div>
            </div>
        </div>
    </div>
</template>