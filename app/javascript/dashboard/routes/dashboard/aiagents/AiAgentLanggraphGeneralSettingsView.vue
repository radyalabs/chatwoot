<script setup>
import {
  computed,
  nextTick,
  reactive,
  ref,
  useTemplateRef,
  watch,
  watchEffect,
} from 'vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { required } from '@vuelidate/validators';
import useVuelidate from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import aiAgents from '../../../api/aiAgents';
import aiAgentsLanggraph from '../../../api/aiAgentsLanggraph';
import MarkdownIt from 'markdown-it';
import account from '../../../api/account';

const md = new MarkdownIt();

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const chatflowId = ref();
const chatInput = ref('');
const messages = ref([]);
const sessionId = ref(crypto.randomUUID());
const loadingChat = ref(false);
const chatContainer = ref(null);

watch(
  () => props.data,
  v => {
    chatflowId.value = v?.chat_flow_id;
  },
  {
    immediate: true,
  }
);

const state = reactive({
  name: '',
  description: '',
  type: '',
  agents: [],
  flow_data: {},
  is_public: false,
  deployed: false,
  api_config: {},
  // welcoming_message: '',
  // routing_condition: '',
});

const rules = {
  name: { required },
  // system_prompts: { required },
};

const v$ = useVuelidate(rules, state);

watch(
  () => props.data,
  v => {
    if (v) {
      Object.assign(state, {
        name: v.name || '',
        description: v.description || '',
        type: v.flow_data?.type || '',
        agents: v.flow_data?.type === 'single-agent' ? [{agent:v.flow_data?.agent_type}] : v.flow_data?.enabled_agents.map(agent => ({ agent: agent })) || [],
        flow_data: v.flow_data || {},
        is_public: v.is_public || false,
        deployed: v.deployed || false,
        api_config: v.api_config || {},
        // welcoming_message: v.welcoming_message || '',
        // routing_conditions: v.routing_conditions || '',
      });
    }
  },
  {
    immediate: true,
  }
);

const loadingSave = ref(false);
async function submit() {
  if (loadingSave.value) {
    return;
  }

  if (!(await v$.value.$validate())) {
    return;
  }

  try {
    loadingSave.value = true;
    const { agents, type, ...request } = state;
    await aiAgentsLanggraph.update(props.data.chat_flow_id, request);
    const detailAgent = await aiAgentsLanggraph
      .show(props.data.chat_flow_id)
      .then(v => v?.data);
    chatflowId.value = undefined;
    nextTick(() => {
      chatflowId.value = detailAgent?.chat_flow_id;
    });
    useAlert('Berhasil disimpan');
  } catch (error) {
    const errorMessage = error?.response?.data?.error || error.message;
    useAlert(errorMessage, { type: 'error' });
  } finally {
    loadingSave.value = false;
  }
}

function scrollToBottom() {
  nextTick(() => {
    if (chatContainer.value) {
      chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
    }
  });
}


function renderMarkdown(text) {
  return md.render(text);
}

async function chat() {
  if (loadingChat.value || !chatInput.value.trim()) return;

  const question = chatInput.value.trim();
  messages.value.push({
    role: 'user',
    content: question,
  });
  chatInput.value = '';
  scrollToBottom();

  try {
    loadingChat.value = true;
    const res = await aiAgentsLanggraph.chat({
      question: question,
      session_id: sessionId.value,
      chat_flow_id: props.data.chat_flow_id,
      account_id: String(props.data.account_id),
    });

    res.data.split('\n').forEach(line => {
        if (line.startsWith('data: ')) {
          try {
            const data = JSON.parse(line.slice(6));
            messages.value.push({
              role: 'assistant',
              content: data.response || '',
            });
          } catch (e) {
            console.error('JSON parsing error', e);
          }
        }
      })

    scrollToBottom();
  } catch (error) {
    messages.value.push({
      role: 'assistant',
      content: 'Maaf, terjadi kesalahan saat memproses pertanyaan Anda.',
    });
    scrollToBottom();
  } finally {
    loadingChat.value = false;
  }
}

function resetChat() {
  messages.value = [];
  sessionId.value = crypto.randomUUID();
}

// agent list
const selectedAgent = ref();
watchEffect(() => {
  if (state.agents.length && !selectedAgent.value) {
    selectedAgent.value = state.agents[0];
  }
});

// bot name model
const botNameModel = computed({
  get() {
    if (state.type === 'single-agent') {
      return state.flow_data.agents_config.bot_name;
    } else if (state.type === 'multi-agent') {
      return state.flow_data.agents_config?.[selectedAgent.value.agent]?.bot_name || '';
    }
    return '';
  },
  set(val) {
    if (state.type === 'single-agent') {
      state.flow_data.agents_config.bot_name = val;
    } else if (state.type === 'multi-agent') {
      const key = selectedAgent.value?.agent;
      if (key && state.flow_data.agents_config[key]) {
        state.flow_data.agents_config[key].bot_name = val;
      }
    }
  }
});

// get description model
const botDescriptionModel = computed({
  get() {
    if (state.type === 'single-agent') {
      return state.flow_data.agents_config.bot_description;
    } else if (state.type === 'multi-agent') {
      return state.flow_data.agents_config?.[selectedAgent.value.agent]?.bot_description || '';
    }
    return '';
  },
  set(val) {
    if (state.type === 'single-agent') {
      state.flow_data.agents_config.bot_description = val;
    } else if (state.type === 'multi-agent') {
      const key = selectedAgent.value?.agent;
      if (key && state.flow_data.agents_config[key]) {
        state.flow_data.agents_config[key].bot_description = val;
      }
    }
  }
});

// get system prompts model
const botSystemPromptsModel = computed({
  get() {
    if (state.type === 'single-agent') {
      return state.flow_data.agents_config.bot_prompt;
    } else if (state.type === 'multi-agent') {
      return state.flow_data.agents_config?.[selectedAgent.value.agent]?.bot_prompt || '';
    }
    return '';
  },
  set(val) {
    if (state.type === 'single-agent') {
      state.flow_data.agents_config.bot_prompt = val;
    } else if (state.type === 'multi-agent') {
      const key = selectedAgent.value?.agent;
      if (key && state.flow_data.agents_config[key]) {
        state.flow_data.agents_config[key].bot_prompt = val;
      }
    }
  }
});

// get configuration model
const botConfigurationModel = computed({
  get() {
    if (state.type === 'single-agent') {
      return state.flow_data.agents_config.configuration;
    } else if (state.type === 'multi-agent') {
      return state.flow_data.agents_config?.[selectedAgent.value.agent]?.configuration || '';
    }
    return '';
  },
  set(val) {
    if (state.type === 'single-agent') {
      state.flow_data.agents_config.configuration = val;
    } else if (state.type === 'multi-agent') {
      const key = selectedAgent.value?.agent;
      if (key && state.flow_data.agents_config[key]) {
        state.flow_data.agents_config[key].configuration = val;
      }
    }
  }
});

// get knowledge sources model
const botKnowledgeSourcesModel = computed({
  get() {
    if (state.type === 'single-agent') {
      return state.flow_data.agents_config.knowledge_sources || [];
    } else if (state.type === 'multi-agent') {
      return state.flow_data.agents_config?.[selectedAgent.value.agent]?.knowledge_sources || [];
    }
    return [];
  },
  set(val) {
    if (state.type === 'single-agent') {
      state.flow_data.agents_config.knowledge_sources = val;
    } else if (state.type === 'multi-agent') {
      const key = selectedAgent.value?.agent;
      if (key && state.flow_data.agents_config[key]) {
        state.flow_data.agents_config[key].knowledge_sources = val;
      }
    }
  }
});

</script>

<template>
  <div class="flex flex-col lg:flex-row justify-stretch gap-4">
    <form class="lg:flex-1 lg:min-w-0" @submit.prevent="() => submit()">
      <div class="flex flex-col space-y-3 gap-4">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div>
            <!-- <label for="name">{{ t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME') }}</label> -->
            <label for="name">Nama</label>
            <Input id="name" v-model="state.name" placeholder="Nama" />
          </div>
          <div>
            <label for="description">Deskripsi</label>
            <Input
              id="description"
              v-model="state.description"
              placeholder="Deskripsi"
            />
          </div>
        </div>
        <div mt-6 mb-0>
          <label for="agent">{{ t('AGENT_MGMT.FORM_CREATE.AI_AGENT_TYPE') }}</label>
          <multiselect
            id="agent"
            v-model="selectedAgent"
            :options=state.agents
            placeholder="Pilih agent"
            label="agent"
            track-by="agent"
            :close-on-select="true"
            :allow-empty="false"
            :class="'w-full mt-2'"
          />
        </div>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div>
            <label>{{ t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME') }}</label>
            <!-- <Input v-model="state.flow_data.agents_config" :placeholder="t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME')" /> -->
            <Input
              v-model="botNameModel"
              :placeholder="t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME')"
            />
          </div>
          <div>
            <label for="description">{{ t('AGENT_MGMT.FORM_CREATE.AI_AGENT_DESC') }}</label>
            <Input
              id="description"
              v-model="botDescriptionModel"
              :placeholder="t('AGENT_MGMT.FORM_CREATE.AI_AGENT_DESC')"
            />
          </div>
        </div>
        <div>
          <label for="system_prompts">{{ t('AGENT_MGMT.FORM_CREATE.AI_AGENT_SYSTEM_PROMPT') }}</label>
          <TextArea
            id="system_prompts"
            v-model="botSystemPromptsModel"
            custom-text-area-wrapper-class=""
            custom-text-area-class="!outline-none"
            auto-height
          />
        </div>
        <!-- <div>
          <label for="welcome_message">{{ t('AGENT_MGMT.FORM_CREATE.WELCOME_MESSAGE') }}</label>
          <TextArea
            id="welcome_message"
            v-model="state.welcoming_message"
            custom-text-area-wrapper-class=""
            custom-text-area-class="!outline-none"
            auto-height
          />
        </div>
        <div>
          <label for="routing_conditions">{{ t('AGENT_MGMT.FORM_CREATE.ROUTING_CONDITION') }}</label>
          <TextArea
            id="routing_conditions"
            v-model="state.routing_conditions"
            custom-text-area-wrapper-class=""
            custom-text-area-class="!outline-none"
            :placeholder="t('AGENT_MGMT.FORM_CREATE.ROUTING_CONDITION_PLACEHOLDER')"
            auto-height
          />
        </div> -->
        <button class="button self-start" type="submit" :disabled="loadingSave">
          <span v-if="loadingSave" class="mt-4 mb-4 spinner" />
          <span v-else>Simpan</span>
        </button>
      </div>
    </form>
    <!-- Chat Preview Section -->
    <div class="h-[600px] w-full lg:h-[500px] lg:w-[350px]">
      <div class="w-full rounded-xl dark:bg-black-900/80 shadow-lg dark:shadow-slate-700 overflow-hidden flex flex-col h-full">
        <div class="bg-green-600 px-4 py-2 flex justify-end items-center">
          <button @click="resetChat" class="text-white hover:text-gray-200 flex items-center space-x-1">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
        </div>
        <div ref="chatContainer" class="flex-1 flex flex-col space-y-4 p-4 overflow-y-auto">
          <div class="flex justify-start">
            <div class="bg-slate-50 dark:bg-slate-800 px-4 py-3 rounded-lg text-sm max-w-[90%]">
              <span class="text-[#000000] dark:text-white">Hai! Ada yang bisa saya bantu?</span>
            </div>
          </div>
          <div
            v-for="(message, index) in messages"
            :key="index"
            :class="message.role === 'user' ? 'flex justify-end' : 'flex justify-start'"
          >
            <div
              :class="[
                'px-4 py-2 rounded-lg text-sm max-w-[90%]',
                message.role === 'user' ? 'bg-green-600 text-white' : 'bg-slate-50 dark:bg-slate-800 text-[#000000] dark:text-white',
              ]"
              v-html="message.role === 'user' ? message.content.replace(/\n/g, '<br>') : renderMarkdown(message.content)"
            ></div>
          </div>
        </div>
        <form class="flex items-center p-4" @submit.prevent="chat">
          <Input v-model="chatInput" class="w-full" type="text" placeholder="Type your question" />
          <button 
            class="ml-3 bg-green-600 text-white p-2 rounded-lg hover:bg-green-700 relative"
            type="submit"
            :disabled="loadingChat"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12l15-6-6 15-2.25-6-6.75-3z" />
            </svg>
          </button>
        </form>
      </div>
    </div>
    <!-- Chat Preview Section -->
  </div>
</template>
