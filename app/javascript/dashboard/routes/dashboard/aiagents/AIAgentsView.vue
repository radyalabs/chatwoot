<script setup>
import { computed, onMounted, reactive, ref, watch, watchEffect } from 'vue';
import aiAgents from '../../../api/aiAgents';
import aiAgentsLanggraph from '../../../api/aiAgentsLanggraph';
import { useAccount } from 'dashboard/composables/useAccount';
import WootSubmitButton from 'dashboard/components/buttons/FormSubmitButton.vue';
import BaseSettingsHeader from '../settings/components/BaseSettingsHeader.vue';
import { useAlert } from 'dashboard/composables';
import { minLength, required } from '@vuelidate/validators';
import useVuelidate from '@vuelidate/core';
import { useI18n } from 'vue-i18n';

const { accountId } = useAccount();
const { t } = useI18n();

// Fetch AI Agents from Langgraph
const aiAgentsLanggraphRef = ref();
const aiAgentsLoadingLanggraph = ref(false);
async function fetchAgentsLanggraph() {
  try {
    aiAgentsLoadingLanggraph.value = true;
    const resp = await aiAgentsLanggraph.getAll();
    aiAgentsLanggraphRef.value = resp?.data;
  } catch (error) {
    console.error('Error fetching Langgraph agents:', error);
  } finally {
    aiAgentsLoadingLanggraph.value = false;
  }
}

// Fetch AI Agents from Flowise
const aiAgentsRef = ref();
const aiAgentsLoading = ref();
async function fetchAiAgents() {
  try {
    aiAgentsLoading.value = true;

    const resp = await aiAgents.getAiAgents();
    aiAgentsRef.value = resp?.data;
  } finally {
    aiAgentsLoading.value = false;
  }
}

// Fetch List of AI Agents flowise
const aiTemplates = ref();
async function fetchAiAgentTemplates() {
  aiTemplates.value = await aiAgents.listAiTemplate().then(v => v?.data);
}

onMounted(() => {
  fetchAiAgents();
  fetchAiAgentTemplates();
  fetchAgentsLanggraph();
});


// Delete AI Agent modal from Flowise
const loadingCards = ref({});
const dataToDelete = ref();
const showDeleteModal = ref();
async function deleteData() {
  showDeleteModal.value = false;
  if (!dataToDelete.value) {
    return;
  }

  const aiAgentId = dataToDelete.value.id;
  try {
    loadingCards.value[aiAgentId] = true;
    await aiAgents.removeAiAgent(aiAgentId);
    aiAgentsRef.value = aiAgentsRef.value?.filter(v => v.id !== aiAgentId);
  } finally {
    loadingCards.value[aiAgentId] = false;
  }
}

// Delete AI Agent modal from Langgraph
// const dataToDeleteLanggraph = ref();
const isLanggraphAgent = ref(false);
async function deleteDataLanggraph() {
  showDeleteModal.value = false;
  if (!dataToDelete.value) {
    return;
  }

  const aiAgentId = dataToDelete.value.chat_flow_id;
  try {
    loadingCards.value[aiAgentId] = true;
    console.log('Deleting Langgraph AI Agent with ID:', aiAgentId);
    await aiAgentsLanggraph.delete(aiAgentId);
    aiAgentsLanggraphRef.value = aiAgentsLanggraphRef.value?.filter(v => v.chat_flow_id !== aiAgentId);
  } catch (e) {
    const errorMessage = e?.response?.data?.error || e.message;
    useAlert(errorMessage || t('AGENT_MGMT.FORM_CREATE.FAILED_ADD'));
  } finally {
    loadingCards.value[aiAgentId] = false;
  }
}


// Create AI Agent modal
const showCreateAgentModal = ref(false);
const state = reactive({
  agentName: '',
});
const rules = {
  agentName: { required, minLength: minLength(1) },
};
const v$ = useVuelidate(rules, state);
watch(showCreateAgentModal, v => {
  if (!v) {
    state.agentName = undefined;
  }
});
const loadingCreate = ref(false);
async function createAiAgent() {
  const valid = await v$.value.$validate();
  if (!valid) {
    return;
  }
  const templateId = selectedTemplate.value;
  const name = state.agentName?.trim();
  if (loadingCreate.value || !templateId || !name) {
    return;
  }

  try {
    loadingCreate.value = true;
    await aiAgents.createAiAgent(name, templateId);
    fetchAiAgents();
    showCreateAgentModal.value = false;
  } catch (e) {
    const errorMessage = e?.response?.data?.error;
    useAlert(errorMessage || t('AGENT_MGMT.FORM_CREATE.FAILED_ADD'));
  } finally {
    loadingCreate.value = false;
  }
}

// Check if the selected template is for Langgraph
const isMultiAgent = computed(() => selectedType.value?.id === 'multi-agent');

function buildFlowData() {
  if (!isMultiAgent.value) {
    return {
      type: 'single-agent',
      agent_type: selectedTemplateLanggraph.value.id,
      agents_config: {
        bot_name: selectedTemplateLanggraph.value.label?.trim() || '',
        bot_description: selectedTemplateLanggraph.value.description?.trim() || '',
        bot_prompt: selectedTemplateLanggraph.value.prompt?.trim() || '',
        configurations: {},
        knowledge_sources: [],
      },
    };
  } else {
    const agents_config = {};
    selectedTemplateLanggraph.value.forEach(agent => {
      agents_config[agent.id] = {
        bot_name: agent.label || '',
        bot_prompt: agent.bot_prompt || '',
        configurations: {},
        knowledge_sources: [],
      };
    });
    return {
      type: 'multi-agent',
      enabled_agents: selectedTemplateLanggraph.value.map(a => a.id),
      supervisor_prompt: selectedTemplateLanggraph.value.supervisorPrompt?.trim() || '',
      agents_config: agents_config,
    };
  }
}

async function createAiAgentLanggraph() {
  const valid = await v$.value.$validate();
  if (!valid) return;
  
  if (loadingCreate.value) return;
  const name = state.agentName?.trim();

  if (!name || !selectedTemplateLanggraph.value) return;

  try {
    loadingCreate.value = true;

    const payload = {
      name,
      description: selectedTemplateLanggraph.value.description?.trim() || '',
      chat_flow_id: "CTW-" + Date.now(),
      flow_data: buildFlowData(),
      is_public: true,
      deployed: true,
      api_config: {},
    };

    await aiAgentsLanggraph.create(payload);
    fetchAgentsLanggraph();
    useAlert(t('AGENT_MGMT.FORM_CREATE.SUCCESS_ADD'));
    showCreateAgentModal.value = false;
  } catch (e) {
    const errorMessage = e?.response?.data?.error || e.message;
    useAlert(t('AGENT_MGMT.FORM_CREATE.FAILED_ADD'));
  } finally {
    loadingCreate.value = false;
  }
}

// List of AI Agent templates
const templates = computed(() =>
  aiTemplates.value?.map(e => ({
    label: e.name,
    id: `${e.id}`,
  }))
);
const selectedTemplate = ref();
watchEffect(() => {
  if (templates.value && templates.value.length && !selectedTemplate.value) {
    selectedTemplate.value = templates.value[0].id;
  }
});

// List for type for the agent (single-agent, multi(max 3))
const typeAgent = computed(() => {
  return [
    { id: 'single-agent', name: t('AGENT_MGMT.FORM_CREATE.SINGLE_AGENT') },
    { id: 'multi-agent', name: t('AGENT_MGMT.FORM_CREATE.MULTI_AGENT') },
  ]
});

const selectedType = ref(typeAgent.value[0]);

// List of sources for the agent
const sourceAgent = computed(() => {
  return [
    { id: 'flowise', name: t('AGENT_MGMT.FORM_CREATE.SOURCES.FLOWISE') },
    { id: 'langgraph', name: t('AGENT_MGMT.FORM_CREATE.SOURCES.LANGGRAPH') },
    { id: 'webhook', name: t('AGENT_MGMT.FORM_CREATE.SOURCES.WEBHOOK') },
  ]
});
const selectedSource = ref(sourceAgent.value[0]);

// Reset selected template when type changes
watch(selectedType, () => {
  selectedTemplateLanggraph.value = null; // Reset ke default
});

// Reset selected template when source changes
watch(selectedSource, () => {
  selectedTemplate.value = null; // Reset ke default
  selectedTemplateLanggraph.value = null; // Reset ke default
});

// List of Langgraph templates
const templateLanggraph = computed(() => {
  return [
    { id: 'sales', label: 'Sales Agent' },
    { id: 'booking', label: 'Booking Agent' },
    { id: 'customer_service', label: 'Customer Service Agent' },
    { id: 'supervisor', label: 'Supervisor Agent' },
  ]
});
const selectedTemplateLanggraph = ref();
watchEffect(() => {
  if (templateLanggraph.value && templateLanggraph.value.length && !selectedTemplateLanggraph.value) {
    selectedTemplateLanggraph.value = isMultiAgent.value
      ? [templateLanggraph.value[0]]
      : templateLanggraph.value[0];
  }
});

// Input for webhook URL
const inputWebhookUrl = ref('');
async function createAiAgentWebhook() {
  const valid = await v$.value.$validate();
  if (!valid) return;

  if (loadingCreate.value) return;
  const name = state.agentName?.trim();
  const webhookUrl = inputWebhookUrl.value?.trim();

  if (!name || !webhookUrl) return;

  try {
    loadingCreate.value = true;
    // implement the API call to create the AI agent with webhook
    // ....

    showCreateAgentModal.value = false;
    // useAlert(t('AGENT_MGMT.FORM_CREATE.SUCCESS_ADD'));
    console.log('Webhook AI Agent created:', {
      name,
      webhookUrl,
    });
    useAlert('TODO: Implement createAiAgentWebhook, Temporary implementation');
  } catch (e) {
    const errorMessage = e?.response?.data?.error || e.message;
    useAlert(errorMessage || t('AGENT_MGMT.FORM_CREATE.FAILED_ADD'));
  } finally {
    loadingCreate.value = false;
  }
}

</script>

<template>
  <div class="w-full px-8 py-8 bg-n-background overflow-auto">
    <BaseSettingsHeader
      :title="$t('SIDEBAR.AI_AGENTS')"
      :description="$t('SIDEBAR.AI_AGENTS_DESC')"
    >
      <template #actions>
        <woot-button
          class="rounded-md button nice"
          icon="add-circle"
          @click="() => (showCreateAgentModal = true)"
        >
          {{ $t('AI_AGENTS.CREATE_NEW') }}
        </woot-button>
      </template>
    </BaseSettingsHeader>
    <div>
      <!-- <h3 class="text-lg font-medium mt-4">Default AI Agents</h3> -->
      <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-2 border-b pb-2 border-slate-200 dark:border-slate-700 mt-8">
        {{ $t('AGENT_MGMT.FORM_CREATE.DEFAULT_AI_AGENTS') }}
      </h3>
      <div v-if="aiAgentsLoading" class="text-center">
        <span class="mt-4 mb-4 spinner" />
      </div>
      <div v-else-if="!aiAgentsRef || !aiAgentsRef.length">
        <span>{{ $t('AGENT_MGMT.FORM_CREATE.EMPTY_AI_AGENT') }}</span>
      </div>
      <div v-else>
        <!-- {{ aiAgentsRef }}
        {{ aiAgentsLanggraphRef[0] }} -->
        <table class="divide-y divide-slate-75 dark:divide-slate-700">
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr v-for="(agent, _) in aiAgentsRef" :key="agent.id">
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <div class="flex flex-row items-center gap-4">
                  <!-- <Thumbnail
                    :src="agent.thumbnail"
                    :username="agent.name"
                    size="40px"
                    :status="agent.availability_status"
                  /> -->
                  <div>
                    <span
                      class="block font-medium text-lg text-slate-900 dark:text-slate-25"
                    >
                      {{ agent.name }}
                    </span>
                    <span>{{ agent.description }}</span>
                  </div>
                </div>
              </td>

              <td class="py-4">
                <div class="flex justify-end gap-1">
                  <RouterLink
                    :to="`/app/accounts/${accountId}/ai-agents/${agent.id}`"
                  >
                    <woot-button
                      v-tooltip.top="$t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
                      variant="smooth"
                      color-scheme="secondary"
                      icon="edit"
                      class-names="grey-btn"
                    />
                  </RouterLink>
                  <woot-button
                    v-tooltip.top="$t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
                    variant="smooth"
                    color-scheme="alert"
                    icon="dismiss-circle"
                    class-names="grey-btn"
                    :is-loading="loadingCards[agent.id]"
                    @click="
                      () => {
                        dataToDelete = agent;
                        showDeleteModal = true;
                      }
                    "
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- From Langgraph -->
      <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-2 border-b pb-2 border-slate-200 dark:border-slate-700 mt-4">
        {{ $t('AGENT_MGMT.FORM_CREATE.LANGGRAPH_AI_AGENTS') }}
      </h3>
      <div v-if="aiAgentsLoadingLanggraph" class="text-center">
        <span class="mt-4 mb-4 spinner" />
      </div>
      <div v-else-if="!aiAgentsLanggraphRef || !aiAgentsLanggraphRef.length">
        <span>{{ $t('AGENT_MGMT.FORM_CREATE.EMPTY_AI_AGENT') }}</span>
      </div>
      <div v-else>
        <table class="divide-y divide-slate-75 dark:divide-slate-700">
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr v-for="(agent, _) in aiAgentsLanggraphRef" :key="agent.chat_flow_id">
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <div class="flex flex-row items-center gap-4">
                  <div>
                    <span
                      class="block font-medium text-lg text-slate-900 dark:text-slate-25"
                    >
                      {{ agent.name }}
                    </span>
                    <span>{{ agent.description }}</span>
                  </div>
                </div>
              </td>

              <td class="py-4">
                <div class="flex justify-end gap-1">
                  <RouterLink
                    :to="{
                      path: `/app/accounts/${accountId}/ai-agents/${agent.chat_flow_id}`,
                      query: { source: 'langgraph' }
                    }"
                  >
                    <woot-button
                      v-tooltip.top="$t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
                      variant="smooth"
                      color-scheme="secondary"
                      icon="edit"
                      class-names="grey-btn"
                    />
                  </RouterLink>
                  <woot-button
                    v-tooltip.top="$t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
                    variant="smooth"
                    color-scheme="alert"
                    icon="dismiss-circle"
                    class-names="grey-btn"
                    :is-loading="loadingCards[agent.chat_flow_id]"
                    @click="
                      () => {
                        dataToDelete = agent;
                        showDeleteModal = true;
                        isLanggraphAgent = true;
                      }
                    "
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>    
    </div>
  </div>
  <woot-delete-modal
    v-if="showDeleteModal"
    v-model:show="showDeleteModal"
    class="context-menu--delete-modal"
    :on-close="
      () => {
        showDeleteModal = false;
        isLanggraphAgent = false;
      }
    "
    :on-confirm="() => {
      if (isLanggraphAgent) {
        deleteDataLanggraph();
      } else {
        deleteData();
      }
    }"
    title="Apakah kamu akan menghapus data ini?"
    message="You cannot undo this action"
    :confirm-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')"
    :reject-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')"
  />
  <!-- Add agent modal -->
  <woot-modal
    :show="showCreateAgentModal"
    :on-close="() => (showCreateAgentModal = false)"
  >
    <woot-modal-header :header-title="$t('AI_AGENTS.CREATE_NEW')" />
      <div class="px-8 pt-4">
          <!-- <span>SELECT: {{ selectedTemplate }}</span> -->
          <label>
            {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_SOURCE') }}
          </label>
          <multiselect 
          v-model="selectedSource"
          :options="sourceAgent"
          :placeholder="$t('AGENT_MGMT.FORM_CREATE.AI_AGENT_SOURCE')"
          label="name"
          track-by="id"
          deselect-label="Can't remove this value"
          :close-on-select="true"
          :allow-empty="false"
          class="!min-h !mb-2"
          >
          </multiselect>
      </div>

    <form v-if="selectedSource.id === 'flowise'" @submit.prevent="() => createAiAgent()">
      <div class="flex flex-col">
        <div class="w-full mb-2">
          <label>
            {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME') }}
            <input
              v-model="state.agentName"
              type="text"
              :placeholder="$t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME')"
              style="margin-bottom: 0px"
            />
          </label>
          <div
            v-for="error of v$.agentName.$errors"
            :key="error.$uid"
            class="input-errors"
          >
            <div class="text-red-500">{{ error.$message }}</div>
          </div>
        </div>

        <div class="w-full">
          <label>
            {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_TEMPLATE') }}
            <select v-model="selectedTemplate">
              <option
                v-for="template in templates"
                :key="template.id"
                :value="template.id"
              >
                {{ template.label }}
              </option>
            </select>
          </label>
        </div>
      </div>

      <div class="flex items-center justify-start gap-2 pt-2">
        <WootSubmitButton
          :disabled="loadingCreate || v$.$invalid"
          :button-text="$t('AI_AGENTS.CREATE_NEW')"
          :loading="loadingCreate"
          type="submit"
        />
      </div>
    </form>

    <form v-else-if="selectedSource.id === 'langgraph'" @submit.prevent="() => createAiAgentLanggraph()">
      <div class="w-full mb-2">
          <label>
            {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_TYPE') }}
          </label>
          <multiselect 
          v-model="selectedType"
          :options="typeAgent"
          :placeholder="$t('AGENT_MGMT.FORM_CREATE.AI_AGENT_TYPE')"
          label="name"
          track-by="id"
          deselect-label="Can't remove this value"
          :close-on-select="true"
          :allow-empty="false"
          class="!min-h !mb-2"
          >
          </multiselect>
      </div>
      <div class="flex flex-col">
        <div class="w-full mb-2">
          <label>
            {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME') }}
            <!-- {{ selectedType }} -->
            <input
              v-model="state.agentName"
              type="text"
              :placeholder="$t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME')"
              style="margin-bottom: 0px"
            />
          </label>
          <div
            v-for="error of v$.agentName.$errors"
            :key="error.$uid"
            class="input-errors"
          >
            <div class="text-red-500">{{ error.$message }}</div>
          </div>
        </div>

        <label>
          {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_TEMPLATE') }}
        </label>
        <div v-if="selectedType.id === 'single-agent'" class="w-full mb-2">
          <multiselect
            v-model="selectedTemplateLanggraph"
            :options="templateLanggraph"
            placeholder="Pilih template"
            label="label"
            track-by="id"
            :close-on-select="true"
            :allow-empty="false"
          />
        </div>

        <div v-else-if="selectedType.id === 'multi-agent'" class="w-full">
          <multiselect
            v-model="selectedTemplateLanggraph"
            :options="templateLanggraph"
            placeholder="Pilih hingga 3 template"
            label="label"
            track-by="id"
            :multiple="true"
            :max="3"
            :allowEmpty="false"
            :close-on-select="false"
          >
            <template #maxElements>
              <div class="text-red-500 text-sm mt-1">
                {{ $t('AGENT_MGMT.FORM_CREATE.LIMIT_TEXT') }}
              </div>
            </template>
          </multiselect>
        </div>
      </div>
      <div class="flex items-center justify-start gap-2 pt-2">
        <WootSubmitButton
          :disabled="loadingCreate || v$.$invalid"
          :button-text="$t('AI_AGENTS.CREATE_NEW')"
          :loading="loadingCreate"
          type="submit"
        />
      </div>
    </form>

    <form v-if="selectedSource.id === 'webhook'" @submit.prevent="() => createAiAgentWebhook()">
      <div class="flex flex-col">
        <div class="w-full mb-2">
          <label>
            {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME') }}
            <input
              v-model="state.agentName"
              type="text"
              :placeholder="$t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME')"
              style="margin-bottom: 0px"
            />
          </label>
          <div
            v-for="error of v$.agentName.$errors"
            :key="error.$uid"
            class="input-errors"
          >
            <div class="text-red-500">{{ error.$message }}</div>
          </div>
        </div>

        <div class="w-full">
          <label>
            {{ $t('AGENT_MGMT.FORM_CREATE.AI_AGENT_WEBHOOK') }}
            <input
              v-model="inputWebhookUrl"
              type="text"
              :placeholder="$t('AGENT_MGMT.FORM_CREATE.AI_AGENT_WEBHOOK_PLACEHOLDER')"
              style="margin-bottom: 0px"
            />
          </label>
        </div>
      </div>

      <div class="flex items-center justify-start gap-2 pt-2">
        <WootSubmitButton
          :disabled="loadingCreate || v$.$invalid"
          :button-text="$t('AI_AGENTS.CREATE_NEW')"
          :loading="loadingCreate"
          type="submit"
        />
      </div>
    </form>
  </woot-modal>
</template>
