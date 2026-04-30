<script setup>
import {
  computed,
  nextTick,
  reactive,
  ref,
  watch,
} from 'vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { required } from '@vuelidate/validators';
import useVuelidate from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import aiAgents from '../../../api/aiAgents';
import captainTranslator from '../../../api/captainTranslator';
import MarkdownIt from 'markdown-it';
import { useRoute } from 'vue-router';

const md = new MarkdownIt({ linkify: true });
md.renderer.rules.link_open = (tokens, idx, options, env, self) => {
  tokens[idx].attrSet('target', '_blank');
  tokens[idx].attrSet('rel', 'noopener noreferrer');
  return self.renderToken(tokens, idx, options);
};
const route = useRoute();

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
  botType: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:data']);

const { t } = useI18n();

// Check if debug mode is enabled via URL parameter
// ?debugmode=true
const isDebugMode = computed(() => route.query.debugmode === 'true');

// custom agent type
const isCustomAgent = computed(() => props.botType === 'custom_agent');

const chatflowId = ref();
const chatInput = ref('');
const messages = ref([]);
const sessionId = ref(crypto.randomUUID());
const loadingChat = ref(false);
const chatContainer = ref(null);

// Variables for attachment feature in Chat Preview
const pendingAttachments = ref([]);
const fileInput = ref(null);
const failedImages = ref(new Set());

const state = reactive({
  name: '',
  description: '',
  instructions: '',
  business_info: '',
  welcoming_message: '',
  routing_conditions: '',
  enable_handover: true,
  has_website: '',
  website_url: '',
  full_prompt: '',
  temperature: '',
});

// Greeting image uploads via ActiveStorage direct uploads
const greetingImageInput = ref(null);
const greetingAttachments = ref([]);
const accountId = useMapGetter('getCurrentAccountId');

const { onFileUpload: onGreetingFileUpload } = useFileUpload({
  uploadUrl: computed(
    () => `/api/v1/accounts/${accountId.value}/direct_uploads`
  ).value,
  attachFile: ({ file, uploading = false, tempId = null }) => {
    const reader = new FileReader();
    reader.readAsDataURL(file.file);
    reader.onloadend = () => {
      greetingAttachments.value.push({
        thumb: reader.result,
        blobSignedId: undefined,
        uploading,
        tempId,
      });
    };
  },
  updateAttachment: (tempId, blob) => {
    const idx = greetingAttachments.value.findIndex(a => a.tempId === tempId);
    if (idx !== -1) {
      greetingAttachments.value[idx] = {
        ...greetingAttachments.value[idx],
        blobSignedId: blob.signed_id,
        uploading: false,
      };
    }
  },
  removeAttachment: tempId => {
    greetingAttachments.value = greetingAttachments.value.filter(
      a => a.tempId !== tempId
    );
  },
});

function handleGreetingImageUpload(event) {
  if (greetingAttachments.value.length >= 1) {
    useAlert(t('AGENT_MGMT.FORM_CREATE.IMAGE_LIMIT_ONE'), 'alert-danger');
    event.target.value = '';
    return;
  }

  const file = event.target.files[0];
  if (!file) return;

  if (!file.type.startsWith('image/')) {
    useAlert(
      `${file.name}: ${t('AGENT_MGMT.FORM_CREATE.IMAGE_ONLY_ALLOWED')}`,
      'alert-danger'
    );
    event.target.value = '';
    return;
  }

  if (file.size > 5 * 1024 * 1024) {
    useAlert(`${file.name}: ${t('AGENT_MGMT.FORM_CREATE.IMAGE_SIZE_LIMIT')}`, 'alert-danger');
    event.target.value = '';
    return;
  }

  onGreetingFileUpload({ file, size: file.size, type: file.type });
  event.target.value = '';
}

function removeGreetingImage(index) {
  greetingAttachments.value.splice(index, 1);
}

const previewImageSrc = ref('');
function openImagePreview(src) {
  previewImageSrc.value = src;
}
function closeImagePreview() {
  previewImageSrc.value = '';
}
const rules = {
  name: { required },
  description: {},
  instructions: {},
  business_info: {},
  welcoming_message: {},
  routing_conditions: {},
  has_website: {},
  website_url: {},
  full_prompt: {},
  temperature: {},
};

const v$ = useVuelidate(rules, state);

watch(
  () => props.data,
  v => {
    if (!v) return;

    chatflowId.value = v?.chat_flow_id;
    state.name = v.name || '';

    const flowData = v.display_flow_data || {};

    if (flowData.greeting_config) {
      state.greeting_enabled = flowData.greeting_config.enabled || false;
      state.greeting_message = flowData.greeting_config.message || '';

      const savedImages = flowData.greeting_config.images || [];
      const legacyImage = flowData.greeting_config.image || '';
      const imageUrls = v.greeting_image_urls || [];
      const allImages = savedImages.length > 0
        ? savedImages
        : legacyImage ? [legacyImage] : [];

      const currentAttachments = [...greetingAttachments.value];

      greetingAttachments.value = allImages.map((val, idx) => {
        const isBase64 = typeof val === 'string' && val.startsWith('data:');
        let thumbUrl = '';

        if (isBase64) {
          thumbUrl = val;
        } else if (imageUrls[idx]) {
          thumbUrl = imageUrls[idx];
        } else if (currentAttachments[idx] && currentAttachments[idx].thumb) {
          thumbUrl = currentAttachments[idx].thumb; 
        }

        return {
          thumb: thumbUrl,
          blobSignedId: isBase64 ? null : val,
          rawValue: val,
          uploading: false,
          tempId: null,
        };
      });
    }

    console.log('flowData:', flowData);

    if (flowData?.agents_config) {
      const firstAgent = flowData.agents_config[0];
      state.enable_handover =
        firstAgent?.configurations?.enable_handover ?? true;

      flowData.agents_config.forEach(agent_config => {
        if (agent_config.bot_prompt) {
          state.welcoming_message = agent_config.bot_prompt.persona || '';
          state.routing_conditions =
            agent_config.bot_prompt.handover_conditions || '';
          state.instructions = agent_config.bot_prompt.instructions || '';
          state.business_info = agent_config.bot_prompt.business_info || '';
        }
      });
    }
  },
  { immediate: true }
);

const loadingSave = ref(false);
const captainTranslatorEnabled =
  window.chatwootConfig?.captainTranslatorEnabled || 'false';

async function translateToEnglish(text) {
  if (!text || text.trim() === '') return text;
  console.log('Captain Translator Enabled:', captainTranslatorEnabled);
  if (captainTranslatorEnabled !== 'true') return text;

  try {
    const response = await captainTranslator.translate(text, 'en');
    return response.data.translated_text;
  } catch (error) {
    console.error('Translation error:', error);
    return text;
  }
}

async function submit() {
  if (loadingSave.value) return;

  const isValid = await v$.value.$validate();
  if (!isValid) return;

  try {
    loadingSave.value = true;

    const agentId = props.data.id;

    const [
      translatedInstructions,
      translatedPersona,
      translatedRoutingConditions,
      translatedBusinessInfo,
    ] = await Promise.all([
      translateToEnglish(state.instructions),
      translateToEnglish(state.welcoming_message),
      translateToEnglish(state.routing_conditions),
      translateToEnglish(state.business_info),
    ]);

    const flowData = JSON.parse(JSON.stringify(props.data.flow_data || {}));
    flowData.agents_config?.forEach(agent_config => {
      if (agent_config.bot_prompt) {
        agent_config.bot_prompt.persona =
          translatedPersona || agent_config.bot_prompt.persona;
        agent_config.bot_prompt.handover_conditions =
          translatedRoutingConditions || '';
        agent_config.bot_prompt.instructions = translatedInstructions || '';
        agent_config.bot_prompt.business_info = translatedBusinessInfo || '';
      }
      agent_config.configurations = agent_config.configurations || {};
      agent_config.configurations.enable_handover = !!state.enable_handover;
    });

    const displayFlowData = JSON.parse(
      JSON.stringify(props.data.display_flow_data || {})
    );
    displayFlowData.agents_config?.forEach(agent_config => {
      if (agent_config.bot_prompt) {
        agent_config.bot_prompt.persona =
          state.welcoming_message || agent_config.bot_prompt.persona;
        agent_config.bot_prompt.handover_conditions =
          state.routing_conditions || '';
        agent_config.bot_prompt.instructions = state.instructions || '';
        agent_config.bot_prompt.business_info = state.business_info || '';
      }
      agent_config.configurations = agent_config.configurations || {};
      agent_config.configurations.enable_handover = !!state.enable_handover;
    });

    const payload = {
      flow_data: flowData,
      display_flow_data: displayFlowData,
    };

    await aiAgents.updateAgent(props.data.id, payload);

    const detailAgent = await aiAgents.detailAgent(agentId).then(v => v?.data);

    emit('update:data', detailAgent);

    chatflowId.value = undefined;
    nextTick(() => {
      chatflowId.value = detailAgent?.chat_flow_id;
    });

    useAlert('Berhasil disimpan');
  } catch (error) {
    console.error('Error updating agent:', error);
    if (error.response) {
      console.error('Response data:', error.response.data);
      console.error('Status code:', error.response.status);
    } else if (error.request) {
      console.error('No response received:', error.request);
    } else {
      console.error('Error:', error.message);
    }
    useAlert('Gagal menyimpan data. Cek konsol untuk detail.', 'alert-danger');
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

// Function handling images and errors in Chat Preview
function toDirectImageUrl(url) {
  if (!url) return url;
  try {
    const parsed = new URL(url);
    if (
      parsed.hostname === 'drive.google.com' &&
      parsed.pathname === '/uc' &&
      parsed.searchParams.get('id')
    ) {
      const fileId = parsed.searchParams.get('id');
      return `https://lh3.googleusercontent.com/d/${encodeURIComponent(fileId)}=s1000`;
    }
    return url;
  } catch {
    return url;
  }
}

function onImageError(url) {
  failedImages.value = new Set([...failedImages.value, url]);
}

// Function handling attachment uploads in Chat Preview
function onFileSelected(event) {
  const file = event.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = e => {
    pendingAttachments.value.push({
      file,
      preview: e.target.result,
      name: file.name,
    });
  };
  reader.readAsDataURL(file);
  event.target.value = '';
}

function removeAttachment(index) {
  pendingAttachments.value.splice(index, 1);
}

// Chat Function utilizing FormData for Attachments
async function chat() {
  const question = chatInput.value.trim();
  const attachments = [...pendingAttachments.value];
  if (loadingChat.value || (!question && !attachments.length)) return;

  messages.value.push({
    role: 'user',
    content: question,
    attachments: attachments.map(a => ({
      data_url: a.preview,
      filename: a.name,
      file_type: a.file.type,
    })),
  });
  chatInput.value = '';
  pendingAttachments.value = [];
  scrollToBottom();

  try {
    loadingChat.value = true;

    const formData = new FormData();
    formData.append('question', question);
    formData.append('session_id', sessionId.value);
    attachments.forEach(att => {
      formData.append('attachments[]', att.file);
    });

    const res = await aiAgents.chat(props.data.id, formData);

    const resAttachments = res.data.attachments || [];

    let responseText = res.data.response;
    if (resAttachments.length > 0) {
      responseText = responseText
        .replace(/!\[[^\]]*\]\([^)]+\)/g, '')
        .replace(/\n{3,}/g, '\n\n')
        .trim();
    }

    messages.value.push({
      role: 'assistant',
      content: responseText,
    });
    resAttachments.forEach(att => {
      messages.value.push({
        role: 'assistant',
        content: att.title || '',
        imageUrl: toDirectImageUrl(att.url) || att.data_url || null,
      });
    });
    scrollToBottom();
  } catch (error) {
    console.error('Chat error:', error);
    messages.value.push({
      role: 'assistant',
      content: 'Maaf, terjadi kesalahan saat memproses pertanyaan Anda.',
    });
    scrollToBottom();
  } finally {
    loadingChat.value = false;
  }
}

function handleChatKeydown(event) {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    chat();
  }
}

function resetChat() {
  messages.value = [];
  sessionId.value = crypto.randomUUID();
}
</script>

<template>
  <div class="flex flex-col lg:flex-row items-start gap-4">
    <form class="lg:flex-1 lg:min-w-0" @submit.prevent="() => submit()">
      <div class="flex flex-col space-y-3">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div>
            <label for="name">{{
              t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME')
            }}</label>
            <Input
              id="name"
              v-model="state.name"
              :disabled="isDebugMode || loadingSave"
              :placeholder="t('AGENT_MGMT.FORM_CREATE.AI_AGENT_NAME')"
            />
          </div>
        </div>

        <!-- Instruction Field -->
        <div>
          <label for="instruction">{{
            t('AGENT_MGMT.FORM_CREATE.INSTRUCTION')
          }}</label>
          <TextArea
            id="instruction"
            v-model="state.instructions"
            :disabled="isDebugMode || loadingSave"
            custom-text-area-wrapper-class=""
            custom-text-area-class="!outline-none"
            :placeholder="t('AGENT_MGMT.FORM_CREATE.INSTRUCTION_PLACEHOLDER')"
            auto-height
            min-height="80px"
            max-height="300px"
          />
        </div>

        <template v-if="!isCustomAgent">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label for="welcome_message">{{
                t('AGENT_MGMT.FORM_CREATE.AI_AGENT_PERSONA_LANG_STYLE')
              }}</label>
              <TextArea
                :placeholder="
                  t(
                    'AGENT_MGMT.FORM_CREATE.AI_AGENT_PERSONA_LANG_STYLE_PLACEHOLDER'
                  )
                "
                id="welcome_message"
                v-model="state.welcoming_message"
                :disabled="isDebugMode || loadingSave"
                custom-text-area-wrapper-class=""
                custom-text-area-class="!outline-none"
                auto-height
                min-height="80px"
                max-height="300px"
              />
            </div>
            <div>
              <label for="business_info">{{
                t('AGENT_MGMT.FORM_CREATE.AI_AGENT_BUSINESS_INFO')
              }}</label>
              <TextArea
                id="business_info"
                v-model="state.business_info"
                :disabled="isDebugMode || loadingSave"
                custom-text-area-wrapper-class=""
                custom-text-area-class="!outline-none"
                auto-height
                :placeholder="
                  t('AGENT_MGMT.FORM_CREATE.AI_AGENT_BUSINESS_INFO_PLACEHOLDER')
                "
                min-height="80px"
                max-height="300px"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 my-4">
            <div v-if="!isCustomAgent">
              <div class="mb-4">
                <label class="block font-medium mb-2">{{
                  t('AGENT_MGMT.FORM_CREATE.ENABLE_HANDOVER')
                }}</label>
                <label class="inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    v-model="state.enable_handover"
                    :disabled="isDebugMode || loadingSave"
                    class="sr-only peer"
                  />
                  <div
                    class="border solid w-11 h-6 bg-gray-200 rounded-full peer peer-checked:bg-green-500 relative after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full"
                  ></div>
                  <span class="ml-3 text-sm text-slate-700 dark:text-slate-300">
                    {{ state.enable_handover ? 'Aktif' : 'Tidak Aktif' }}
                  </span>
                </label>
                <p class="text-xs text-gray-500 mt-1">
                  {{ t('AGENT_MGMT.FORM_CREATE.HANDOVER_INSTRUCTION') }}
                </p>
              </div>

              <div v-if="state.enable_handover">
                <label for="routing_conditions">{{
                  t('AGENT_MGMT.FORM_CREATE.ROUTING_CONDITION')
                }}</label>
                <TextArea
                  id="routing_conditions"
                  v-model="state.routing_conditions"
                  :disabled="isDebugMode || loadingSave"
                  custom-text-area-wrapper-class=""
                  custom-text-area-class="!outline-none"
                  :placeholder="
                    t('AGENT_MGMT.FORM_CREATE.ROUTING_CONDITION_PLACEHOLDER')
                  "
                  auto-height
                  min-height="80px"
                  max-height="300px"
                />
              </div>
            </div>
          </div>

              <div v-if="state.greeting_enabled" class="space-y-4">
                <div>
                  <label for="greeting_message" class="block font-medium mb-2">
                    {{ t('AGENT_MGMT.FORM_CREATE.GREETING_CONDITION') }}
                  </label>
                  <div class="relative">
                    <TextArea
                      id="greeting_message"
                      v-model="state.greeting_message"
                      :disabled="isDebugMode || loadingSave"
                      custom-text-area-wrapper-class=""
                      custom-text-area-class="!outline-none"
                      :placeholder="t('AGENT_MGMT.FORM_CREATE.GREETING_CONDITION_PLACEHOLDER')"
                      auto-height
                      min-height="80px"
                      max-height="300px"
                    />
                    <div class="flex items-center mt-2">
                      <input
                        ref="greetingImageInput"
                        type="file"
                        accept="image/*"
                        class="hidden"
                        @change="handleGreetingImageUpload"
                      />
                      <button
                        type="button"
                        class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors border border-slate-300 dark:border-slate-600 rounded-md px-3 py-1.5"
                        :disabled="isDebugMode || loadingSave || greetingAttachments.length >= 1"
                        @click="greetingImageInput?.click()"
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="w-4 h-4"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          stroke-width="2"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"
                          />
                        </svg>
                        {{ t('AGENT_MGMT.FORM_CREATE.ATTACH_IMAGE') }}
                      </button>
                    </div>
                  </div>

                  <div
                    v-if="greetingAttachments.length > 0"
                    class="mt-3 flex flex-wrap gap-3"
                  >
                    <div
                      v-for="(attachment, index) in greetingAttachments"
                      :key="index"
                      class="relative group/image w-[72px] h-[72px]"
                    >
                      <img
                        v-if="attachment.thumb"
                        :src="attachment.thumb"
                        class="object-cover w-[72px] h-[72px] rounded-lg cursor-pointer"
                        :class="{ 'opacity-50': attachment.uploading }"
                        @click="openImagePreview(attachment.thumb)"
                      />
                      <div
                        v-if="attachment.uploading"
                        class="absolute inset-0 flex items-center justify-center"
                      >
                        <div
                          class="w-6 h-6 border-2 border-woot-500 border-t-transparent rounded-full animate-spin"
                        />
                      </div>
                      <button
                        v-else
                        type="button"
                        :disabled="loadingSave"
                        :title="t('AGENT_MGMT.FORM_CREATE.DELETE_IMAGE')"
                        class="absolute -top-2 -right-2 w-5 h-5 flex items-center justify-center rounded-full bg-red-500 text-white hover:bg-red-600 transition-colors shadow-sm"
                        @click.stop="removeGreetingImage(index)"
                      >
                        <span class="text-xs font-bold leading-none">&times;</span>
                      </button>
                    </div>
                  </div>

                  <!-- Image Lightbox -->
                  <Teleport to="body">
                    <div
                      v-if="previewImageSrc"
                      class="fixed inset-0 z-[9999] flex items-center justify-center"
                      style="background: rgba(0, 0, 0, 0.5)"
                      @click.self="closeImagePreview"
                    >
                      <div class="flex flex-col items-end gap-3">
                        <button
                          type="button"
                          class="w-10 h-10 flex items-center justify-center rounded-full bg-white/10 text-white hover:bg-white/20 transition-colors"
                          @click="closeImagePreview"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="w-6 h-6"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            stroke-width="2"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M6 18L18 6M6 6l12 12"
                            />
                          </svg>
                        </button>
                        <img
                          :src="previewImageSrc"
                          class="max-w-[90vw] max-h-[85vh] object-contain rounded-lg shadow-2xl"
                        />
                      </div>
                    </div>
                  </Teleport>
                </div>
              </div>
            </div>
          </div>

          <!-- Debug Mode Fields -->
          <template v-if="isDebugMode">
            <hr class="my-4 border-slate-200 dark:border-slate-700" />
            <div>
              <label for="full_prompt">Full Prompt</label>
              <TextArea
                id="full_prompt"
                v-model="state.full_prompt"
                custom-text-area-wrapper-class=""
                custom-text-area-class="!outline-none"
                placeholder="Full prompt will be displayed here"
                auto-height
                min-height="80px"
                max-height="300px"
              />
            </div>
            <div>
              <label for="temperature">Temperature</label>
              <Input
                id="temperature"
                v-model="state.temperature"
                placeholder="AI Agent temperature value"
              />
            </div>
          </template>
        </template>

        <button
          v-if="!isCustomAgent"
          class="button self-start"
          type="submit"
          :disabled="loadingSave"
        >
          <span v-if="loadingSave" class="spinner" />
          <span v-else>{{ t('AGENT_MGMT.FORM_CREATE.SUBMIT') }}</span>
        </button>
      </div>
    </form>
    <!-- Chat Preview Section -->
    <div class="h-[800px] w-full lg:h-[650px] lg:w-[350px] lg:sticky lg:top-4">
      <div
        class="w-full rounded-xl dark:bg-black-900/80 shadow-lg dark:shadow-slate-700 overflow-hidden flex flex-col h-full"
      >
        <div class="bg-green-600 px-4 py-2 flex justify-end items-center">
          <button
            @click="resetChat"
            class="text-white hover:text-gray-200 flex items-center space-x-1"
          >
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
                message.role === 'user'
                  ? 'bg-green-600 text-white'
                  : 'bg-slate-50 dark:bg-slate-800 text-[#000000] dark:text-white',
              ]"
            >
              <template v-if="message.imageUrl">
                <img
                  v-if="!failedImages.has(message.imageUrl)"
                  :src="message.imageUrl"
                  :alt="message.content || 'attachment'"
                  class="max-w-full rounded-lg my-2"
                  @error="onImageError(message.imageUrl)"
                />
                <a
                  v-else
                  :href="message.imageUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-blue-500 underline break-all"
                >
                  {{ message.imageUrl }}
                </a>
              </template>
              
              <template v-if="message.attachments?.length">
                <img
                  v-for="(att, ai) in message.attachments"
                  :key="ai"
                  :src="att.data_url"
                  :alt="att.filename || 'attachment'"
                  class="max-w-full rounded-lg my-2"
                />
              </template>
              
              <div
                v-if="message.content"
                v-dompurify-html="renderMarkdown(message.content)"
                class="chat-message-content"
              />
            </div>
          </div>
        </div>

        <!-- Pending attachments preview -->
        <div v-if="pendingAttachments.length" class="flex gap-2 px-4 pt-2 flex-wrap">
          <div v-for="(att, i) in pendingAttachments" :key="i" class="relative">
            <img
              :src="att.preview"
              :alt="att.name"
              class="w-16 h-16 object-cover rounded-lg border border-slate-200 dark:border-slate-600"
            />
            <button
              type="button"
              class="absolute -top-1.5 -right-1.5 bg-red-500 text-white rounded-full w-4 h-4 text-[10px] flex items-center justify-center leading-none hover:bg-red-600"
              @click="removeAttachment(i)"
            >
              ×
            </button>
          </div>
        </div>

        <form class="flex items-end p-4" @submit.prevent="chat">
          <input
            ref="fileInput"
            type="file"
            accept="image/*"
            class="hidden"
            @change="onFileSelected"
          />
          <button
            type="button"
            class="mr-2 text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 self-end mb-1"
            @click="fileInput.click()"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32m.009-.01l-.01.01m5.699-9.941l-7.81 7.81a1.5 1.5 0 002.112 2.13" />
            </svg>
          </button>
          
          <div class="flex-1" @keydown="handleChatKeydown">
            <TextArea
              v-model="chatInput"
              class="w-full"
              placeholder="Enter to send, Shift+Enter for new line"
              auto-height
              min-height="20px"
              max-height="120px"
              custom-text-area-class="resize-none"
              :rows="1"
            />
          </div>
          
          <button
            class="ml-3 bg-green-600 text-white p-2 rounded-lg hover:bg-green-700 relative self-end mb-1"
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
  </div>
</template>

<style scoped>
.chat-message-content :deep(ul),
.chat-message-content :deep(ol) {
  padding-left: 1.5em;
  margin: 0.25em 0;
}

.chat-message-content :deep(ul) {
  list-style-type: disc;
}

.chat-message-content :deep(ol) {
  list-style-type: decimal;
}

.chat-message-content :deep(li) {
  margin-bottom: 0.25em;
}

.chat-message-content :deep(p:last-child) {
  margin-bottom: 0;
}

.chat-message-content :deep(img) {
  max-width: 100%;
  border-radius: 0.5rem;
  margin: 0.5em 0;
}

.chat-message-content {
  overflow-wrap: break-word;
}

.chat-message-content :deep(a) {
  word-break: break-all;
}

.chat-message-content :deep(a:hover) {
  color: #3ecf8e; /* blue-700 */
}

.bg-green-600 .chat-message-content :deep(a) {
  color: inherit;
  text-decoration: underline;
}

.bg-green-600 .chat-message-content :deep(a:hover) {
  color: #c8f2de; /* green-200 */
}
</style>