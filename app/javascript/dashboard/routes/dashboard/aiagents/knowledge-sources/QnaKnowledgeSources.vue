<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import aiAgents from '../../../../api/aiAgents';
import { useAlert } from 'dashboard/composables';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n()

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
  context: {
    type: String,
    default: 'general',
    validator: (value) => ['booking', 'customer_service', 'general', 'lead_generation', 'sales', 'event_organizer', 'restaurant'].includes(value)
  }
});

const maxQna = 25
const qnas = ref([]);
const expandedQnas = ref({}); // Track expanded state for each QnA

// Helper function to strip existing prefix from question (for cleanup)
const stripPrefix = (question) => {
  if (!question) return question;
  
  // Remove "pertanyaan:" prefix and trim
  if (question.toLowerCase().startsWith('pertanyaan:')) {
    return question.slice('pertanyaan:'.length).trim();
  }
  
  // Remove any existing prefix like [BOOKING], [CS], etc. (for backward compatibility)
  const prefixPattern = /^\[[A-Z_]+\]\s*/;
  return question.replace(prefixPattern, '');
};

// Helper function to strip prefix from answer
const stripAnswerPrefix = (answer) => {
  if (!answer) return answer;
  
  // Remove "jawaban:" prefix and trim
  if (answer.toLowerCase().startsWith('jawaban:')) {
    return answer.slice('jawaban:'.length).trim();
  }
  
  return answer;
};

// Helper function to add prefix to question for saving
const addQuestionPrefix = (question) => {
  if (!question?.trim()) return 'pertanyaan:';
  
  const cleanQuestion = question.trim();
  // Check if prefix already exists
  if (cleanQuestion.toLowerCase().startsWith('pertanyaan:')) {
    return cleanQuestion;
  }
  
  return `pertanyaan: ${cleanQuestion}`;
};

// Helper function to add prefix to answer for saving
const addAnswerPrefix = (answer) => {
  if (!answer?.trim()) return 'jawaban:';
  
  const cleanAnswer = answer.trim();
  // Check if prefix already exists
  if (cleanAnswer.toLowerCase().startsWith('jawaban:')) {
    return cleanAnswer;
  }
  
  return `jawaban: ${cleanAnswer}`;
};

// Filter QnAs based on ai_agent_name_id
const contextQnas = computed(() => {
  if (props.context === 'general') {
    return qnas.value;
  }
  
  // Get current context agent_id
  const currentAgentId = getAgentId();
  if (!currentAgentId) {
    return qnas.value;
  }
  
  // Filter based on ai_agent_name_id
  return qnas.value.filter(qna => {
    return qna.ai_agent_name_id === currentAgentId;
  });
});

// Get display question (clean without any prefix)
const getDisplayQuestion = (item) => {
  return stripPrefix(item.question || '');
};

// Get display answer (clean without any prefix)
const getDisplayAnswer = (item) => {
  return stripAnswerPrefix(item.answer || '');
};

const reachedMaxQnas = computed(() => contextQnas.value.length >= maxQna)
const isFetching = ref(false);
async function fetchKnowledge() {
  try {
    isFetching.value = true;
    const data = await aiAgents.getKnowledgeSources(props.data.id);
    
    const unsavedItems = qnas.value.filter(qna => !qna.id);
    
    qnas.value = data.data?.knowledge_source_qnas || [];
    
    if (unsavedItems.length > 0) {
      qnas.value = [...qnas.value, ...unsavedItems];
    }
    
  } catch (e) {
    useAlert(t('AGENT_MGMT.QNA.FETCH_ERROR'));
  } finally {
    isFetching.value = false;
  }
}

// Add this computed property after the existing helper functions, around line 130-140
const collectionName = computed(() => {
  if (!props.data?.display_flow_data?.agents_config) return null;
  
  const agents = props.data.display_flow_data.agents_config;
  
  // For general context, return the first agent's collection_name
  if (props.context === 'general') {
    return agents[0]?.collection_name || null;
  }
  
  const targetType = props.context;
  if (!targetType) return null;
  
  // Find agent by type
  const agent = agents.find(agent => agent.type === targetType);
  return agent?.collection_name || null;
});

watch(
  () => props.data,
  v => {
    if (!v) {
      return;
    }
    fetchKnowledge();
  },
  {
    immediate: true,
    deep: true,
  }
);

const showDeleteModal = ref();
const deleteModalData = ref();
const deleteModalIndex = ref();
function deleteQna(data, index) {
  const contextQna = contextQnas.value[index];
  const actualIndex = qnas.value.findIndex(qna => qna === contextQna);
  
  deleteModalData.value = contextQna;
  deleteModalIndex.value = actualIndex;
  showDeleteModal.value = true;
}
const deleteLoadingIds = ref({});
async function deleteData() {
  const dataToDelete = deleteModalData.value;
  const dataId = dataToDelete?.id;
  const indexToDelete = deleteModalIndex.value;
  
  const collection_name = collectionName.value;
  
  try {
    showDeleteModal.value = false;
    deleteLoadingIds.value[dataId] = true;
    // If it has an ID, delete from server
    if (dataId) {
      await aiAgents.deleteKnowledgeQna(props.data.id, dataId, { collection_name });
      if (indexToDelete !== -1) {
        qnas.value.splice(indexToDelete, 1);
      }
    } else {
      // If no ID (newly created
      if (indexToDelete !== -1) {
        qnas.value.splice(indexToDelete, 1);
      }
    }
    
    useAlert(t('AGENT_MGMT.QNA.SAVE_SUCCESS'));
  } catch (e) {
    useAlert(t('AGENT_MGMT.QNA.SAVE_ERROR'));
  } finally {
    deleteLoadingIds.value[dataId] = false;
  }
}

const isSaving = ref(false);
async function save() {
  const collection_name = collectionName.value;
  try {
    isSaving.value = true;

    // Get current agent_id for context
    const currentAgentId = getAgentId();
    
    const itemsToSave = qnas.value
      .filter(e => {
        // For general context, save all QnAs
        if (props.context === 'general') return true;
        
        // For specific context, only save QnAs with matching ai_agent_name_id
        return e.ai_agent_name_id === currentAgentId || !e.id; // Include new items without ID
      })
      .map(e => {
        const question = e.question?.trim() || '';
        const answer = e.answer?.trim() || '';
        
        return {
          originalItem: e,
          id: e.id || null,
          question: question,
          answer: answer,
          hasContent: question.length > 0 && answer.length > 0
        };
      })
      .filter(t => t.hasContent);
    
    const request = itemsToSave.map(t => ({ 
      id: t.id, 
      question: addQuestionPrefix(t.question), 
      answer: addAnswerPrefix(t.answer),
      agent_id: currentAgentId,
      collection_name: collection_name // Include collection_name here
    }));
    
    // Store items that will be saved (to exclude them from unsaved items later)
    const itemsThatWillBeSaved = itemsToSave.map(t => t.originalItem);
    

    // Add collection_name parameter here
    await aiAgents.createOrUpdateKnowledgeQna(props.data.id, request);
    
    qnas.value = qnas.value.filter(qna => !itemsThatWillBeSaved.includes(qna));
    
    fetchKnowledge();
    useAlert(t('AGENT_MGMT.QNA.SAVE_SUCCESS'));
  } catch (e) {
    useAlert(t('AGENT_MGMT.QNA.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
}

function addQna() {
  if (reachedMaxQnas.value) {
    return
  }
  
  const newQna = {
    question: '',
    answer: '',
    ai_agent_name_id: getAgentId() // Set agent_id for new QnA
  };
  
  qnas.value.push(newQna);
  const newIndex = contextQnas.value.length - 1;
  
  // Auto-expand the newly added QnA
  expandedQnas.value[newIndex] = true;
  nextTick(() => {
    document.getElementById('btnAddQna').scrollIntoView({
      behavior: 'smooth',
      block: 'end',
    });
  });
}

function updateQuestion(item, displayValue) {
  item.question = displayValue || '';
}

function updateAnswer(item, displayValue) {
  item.answer = displayValue || '';
}

function toggleQnaExpand(index) {
  expandedQnas.value[index] = !expandedQnas.value[index];
}

const contextLabel = computed(() => {
  switch(props.context) {
    case 'booking': return 'Booking Bot';
    case 'cs': return 'CS Bot';
    case 'sales': return 'Sales Bot';
    case 'lead_generation': return 'Lead Generation Bot';
    case 'event_organizer': return 'Event Organizer Bot';
    case 'restaurant': return 'Restaurant Bot';
    default: return 'General';
  }
});

const maxCharQuestion = 150
const maxCharAnswer = 700

// Helper function to get agent_id based on context
const getAgentId = () => {
  if (!props.data?.display_flow_data?.agents_config) return null;
  
  const agents = props.data.display_flow_data.agents_config;
  
  // For general context, return the first agent's id
  if (props.context === 'general') {
    return agents[0]?.agent_id || null;
  }
  
  const targetType = props.context;
  if (!targetType) return null;
  
  // Find agent by type
  const agent = agents.find(agent => agent.type === targetType);
  return agent?.agent_id || null;
};
</script>

<template>
  <div class="flex flex-row gap-4">
    <div class="flex-1 min-w-0 flex flex-col justify-stretch gap-4">
      <div v-if="isFetching" class="text-center">
        <span class="mt-4 mb-4 spinner" />
      </div>

      <div class="space-y-4">
        <div
          v-for="(item, index) in contextQnas"
          :key="index"
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl hover:shadow-md transition-all duration-200 hover:border-slate-300 dark:hover:border-slate-600"
        >
          <div 
            class="flex items-center justify-between p-4 cursor-pointer"
            @click="() => toggleQnaExpand(index)"
          >
            <div class="flex items-center gap-3">
              <div class="w-2 h-2 bg-green-500 rounded-full"></div>
              <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300">
                QnA #{{ index + 1 }}
              </h3>
              <span v-if="getDisplayQuestion(item)" class="text-xs text-slate-500 dark:text-slate-400 truncate max-w-xs">
                - {{ getDisplayQuestion(item) }}
              </span>
            </div>
            <div class="flex items-center gap-2">
              <Button
                variant="ghost"
                color="ruby"
                icon="i-lucide-trash"
                size="sm"
                :is-loading="deleteLoadingIds[item.id]"
                :disabled="deleteLoadingIds[item.id]"
                @click.stop="() => deleteQna(item, index)"
                class="opacity-70 hover:opacity-100"
              />
              <svg 
                class="w-4 h-4 text-slate-400 transition-transform duration-200"
                :class="{ 'rotate-180': expandedQnas[index] }"
                fill="none" 
                stroke="currentColor" 
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
              </svg>
            </div>
          </div>
          
          <div 
            v-show="expandedQnas[index]"
            class="px-4 pb-4 border-t border-slate-200 dark:border-slate-700"
          >
            <div class="pt-4 grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div class="space-y-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {{ $t('AGENT_MGMT.QUESTION_LABEL') }} <span class="text-red-500">*</span>
                </label>
                <div class="relative">
                  <TextArea 
                    :model-value="getDisplayQuestion(item)"
                    showCharacterCount="true" 
                    :maxLength="maxCharQuestion" 
                    :placeholder="$t('AGENT_MGMT.QNA_PLACEHOLDER.QUESTION')"
                    class="w-full"
                    @update:model-value="(value) => updateQuestion(item, value)"
                  />
                </div>
              </div>
              
              <div class="space-y-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {{ $t('AGENT_MGMT.ANSWER_LABEL') }} <span class="text-red-500">*</span>
                </label>
                <div class="relative">
                  <TextArea 
                    :model-value="getDisplayAnswer(item)"
                    showCharacterCount="true" 
                    :maxLength="maxCharAnswer" 
                    :placeholder="$t('AGENT_MGMT.QNA_PLACEHOLDER.ANSWER')"
                    class="w-full"
                    @update:model-value="(value) => updateAnswer(item, value)"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div v-if="contextQnas.length === 0 && !isFetching" class="text-center py-8 text-gray-500 dark:text-gray-400">
          <svg class="w-12 h-12 mx-auto mb-3 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <p class="text-sm">Belum ada QnA untuk {{ contextLabel }}</p>
        </div>
      </div>

      <Button 
        id="btnAddQna" 
        :disabled="reachedMaxQnas" 
        class="w-full py-3 border-2 border-dashed border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-400 hover:border-green-400 hover:text-green-600 transition-all duration-200 rounded-xl bg-transparent hover:bg-green-50 dark:hover:bg-green-900/10 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:border-slate-300 disabled:hover:text-slate-500 disabled:hover:bg-transparent" 
        variant="ghost"
        @click="addQna"
      >
        <span class="flex items-center gap-2">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
          </svg>
          {{ $t('AGENT_MGMT.QNA.ADD_QNA') }}
        </span>
      </Button>

      <woot-delete-modal
        v-if="showDeleteModal"
        v-model:show="showDeleteModal"
        class="context-menu--delete-modal"
        :on-close="
          () => {
            showDeleteModal = false;
          }
        "
        :on-confirm="() => deleteData()"
        title="Apakah kamu akan menghapus data ini?"
        message="Kamu tidak akan mengembalikan data ini"
        :confirm-text="
          $t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')
        "
        :reject-text="
          $t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')
        "
      />
    </div>
    <div class="w-[240px] flex flex-col gap-3">
      <div class="sticky top-4 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm">
        <div class="flex items-center gap-3 mb-4">
          <div class="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div class="min-w-0">
            <h3 class="font-semibold text-slate-700 dark:text-slate-300 truncate">{{ contextLabel }}</h3>
            <p class="text-sm text-slate-500 dark:text-slate-400">{{ contextQnas.length }}/{{ maxQna }}</p>
          </div>
        </div>
        
        <Button
          class="w-full"
          :is-loading="isSaving"
          :disabled="isSaving"
          @click="() => save()"
        >
          <span class="flex items-center gap-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
            </svg>
            {{ $t('AGENT_MGMT.CSBOT.TICKET.SAVE_BUTTON') }}
          </span>
        </Button>
      </div>
    </div>
  </div>
</template>

<style lang="css">
.note-editing-area {
  background: white;
}
</style>
