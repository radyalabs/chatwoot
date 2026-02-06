<script setup>
import { reactive, ref, watch, inject } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAlert } from 'dashboard/composables'
import Button from 'dashboard/components-next/button/Button.vue'
import aiAgents from '../../../../../api/aiAgents'
import captainTranslator from '../../../../../api/captainTranslator'

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
  agentType: {
    type: String,
    default: 'customer_service',
  },
})

const { t } = useI18n()
const emitUpdate = inject('emitUpdate', () => {})

// Map agent types to their localization prefixes
const agentTypeLocaleMap = {
  customer_service: 'AGENT_MGMT.CSBOT.TICKET',
  sales_agent: 'AGENT_MGMT.SALES_AGENT.TICKET',
  support_agent: 'AGENT_MGMT.SUPPORT_AGENT.TICKET',
  sales: 'AGENT_MGMT.SALES.TICKET',
  lead_generation: 'AGENT_MGMT.LEAD_GENERATION.TICKET',
}

const getLocaleKey = (key) => {
  const prefix = agentTypeLocaleMap[props.agentType] || agentTypeLocaleMap.customer_service
  return `${prefix}.${key}`
}

const categories = reactive([
  { name: '', condition: '' },
  { name: '', condition: '' },
  { name: '', condition: '' }
])
const expandedCategories = ref({}) // Track expanded state for each category

// ✅ Load categories from backend when data arrives
watch(
  () => props.data,
  (newData) => {
    if (!newData?.display_flow_data) return

    const flowData = newData.display_flow_data
    const agentIndex = flowData.enabled_agents.indexOf(props.agentType)
    
    if (agentIndex === -1) return // Skip if agent not in flow

    const categoryConfig = flowData.agents_config?.[agentIndex]?.configurations?.category
    if (Array.isArray(categoryConfig)) {
      // Replace local categories with backend values
      categories.splice(0, categories.length, ...categoryConfig.map(c => ({
        name: c.key || '',
        condition: c.conditions || ''
      })))
    }

    // Auto-expand all loaded categories
    categories.forEach((_, i) => {
      expandedCategories.value[i] = true
    })
  },
  { immediate: true, deep: true }
)

const validation = reactive({
  categories: {}
})

const isSaving = ref(false)

function validateCategoryName(index) {
  const name = categories[index]?.name?.trim()
  if (!name) {
    validation.categories[index] = t(getLocaleKey('ERROR'))
    return false
  }
  
  const duplicateIndex = categories.findIndex((c, i) => 
    i !== index && c.name?.trim().toLowerCase() === name.toLowerCase()
  )
  if (duplicateIndex !== -1) {
    validation.categories[index] = t(getLocaleKey('DUPE_ERROR'))
    return false
  }
  
  delete validation.categories[index]
  return true
}

function addCategory() {
  const newIndex = categories.length;
  categories.push({ name: '', condition: '' })
  // Auto-expand the newly added category
  expandedCategories.value[newIndex] = true;
}

function toggleCategoryExpand(index) {
  expandedCategories.value[index] = !expandedCategories.value[index];
}

function removeCategory(index) {
  categories.splice(index, 1)
  delete validation.categories[index]
  const newValidation = {}
  Object.keys(validation.categories).forEach(key => {
    const keyIndex = parseInt(key)
    if (keyIndex > index) {
      newValidation[keyIndex - 1] = validation.categories[keyIndex]
    } else if (keyIndex < index) {
      newValidation[keyIndex] = validation.categories[keyIndex]
    }
  })
  validation.categories = newValidation
}

async function save() {
  try {
    isSaving.value = true;

    // Validate all categories
    let isValid = true;
    categories.forEach((_, index) => {
      if (!validateCategoryName(index)) {
        isValid = false;
      }
    });

    if (!isValid) {
      useAlert(t(getLocaleKey('VALIDATION_ERROR')));
      return;
    }
    // Build payloads
    let flowData = JSON.parse(JSON.stringify(props.data.flow_data)); 
    let displayFlowData = JSON.parse(JSON.stringify(props.data.display_flow_data)); 

    // Translate each category's key and conditions to English for flow_data
    const translatedCategories = [];
    for (const item of categories) {
      // Keep original (Indonesian) for display_flow_data
      const original = { key: item.name, conditions: item.condition };

      // Translate to English for flow_data
      let translatedConditions = item.condition;
      try {
        const condResp = await captainTranslator.translate(item.condition || '', 'en');
        translatedConditions = condResp?.data?.translated_text || translatedConditions;
      } catch (e) {}

      translatedCategories.push({ key: item.name, conditions: translatedConditions });

      // Also set display (original) below
    }
    const agent_index = flowData.enabled_agents.indexOf(props.agentType);
    flowData.agents_config[agent_index].configurations.category = translatedCategories;
    // For display, store original Indonesian values
    displayFlowData.agents_config[agent_index].configurations.category = categories.map(c => ({
      key: c.name,
      conditions: c.condition,
    }));
    // eslint-disable-next-line no-console


    const payload = {
      flow_data: flowData,
      display_flow_data: displayFlowData,
    };
    // ✅ Properly await the API call
    await aiAgents.updateAgent(props.data.id, payload);
    emitUpdate();
    useAlert(t(getLocaleKey('SAVE_SUCCESS')))
  } catch (e) {
    useAlert(t(getLocaleKey('SAVE_ERROR')))
  } finally {
    isSaving.value = false
  }
}
</script>


<template>
  <div class="flex flex-row gap-4">
    <div class="flex-1 min-w-0 flex flex-col justify-stretch gap-4">
      <div class="space-y-4">
        <div
          v-for="(category, index) in categories"
          :key="index"
          class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl hover:shadow-md transition-all duration-200 hover:border-slate-300 dark:hover:border-slate-600"
        >
          <div 
            class="flex items-center justify-between p-4 cursor-pointer"
            @click="() => toggleCategoryExpand(index)"
          >
            <div class="flex items-center gap-3">
              <div class="w-2 h-2 bg-green-500 rounded-full"></div>
              <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300">
                {{ $t(getLocaleKey('CATEGORY_TITLE')) }} #{{ index + 1 }}
              </h3>
              <span v-if="category.name" class="text-xs text-slate-500 dark:text-slate-400 truncate max-w-xs">
                - {{ category.name }}
              </span>
            </div>
            <div class="flex items-center gap-2">
              <Button
                variant="ghost"
                color="ruby"
                icon="i-lucide-trash"
                size="sm"
                :disabled="false"
                @click.stop="() => removeCategory(index)"
                class="opacity-70 hover:opacity-100"
              />
              <svg 
                class="w-4 h-4 text-slate-400 transition-transform duration-200"
                :class="{ 'rotate-180': expandedCategories[index] }"
                fill="none" 
                stroke="currentColor" 
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
              </svg>
            </div>
          </div>
          
          <div 
            v-show="expandedCategories[index]"
            class="px-4 pb-4 border-t border-slate-200 dark:border-slate-700"
          >
            <div class="pt-4 grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div class="space-y-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {{ $t(getLocaleKey('CATEGORY_PLACEHOLDER')) }}
                  <span class="text-red-500">*</span>
                </label>
                <textarea
                  v-model="category.name"
                  @blur="validateCategoryName(index)"
                  @input="validateCategoryName(index)"
                    :placeholder="$t(getLocaleKey('CATEGORY_PLACEHOLDER'))"
                  :class="[
                    'w-full px-3 py-2.5 text-sm rounded-lg border transition-all duration-200 resize-none',
                    'bg-slate-50 dark:bg-slate-900/50',
                    'focus:ring-2 focus:ring-green-500/20 focus:border-green-500',
                    'hover:border-slate-300 dark:hover:border-slate-600',
                    validation.categories[index] 
                      ? 'border-red-300 focus:border-red-500 focus:ring-red-500/20' 
                      : 'border-slate-200 dark:border-slate-700',
                    'placeholder:text-slate-400 dark:placeholder:text-slate-500'
                  ]"
                  rows="3"
                ></textarea>
                <p v-if="validation.categories[index]" class="text-red-500 text-xs">
                  {{ validation.categories[index] }}
                </p>
              </div>
              
              <div class="space-y-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {{ $t(getLocaleKey('CATEGORY_CONDITION')) }}
                </label>
                <textarea
                  v-model="category.condition"
                  :placeholder="$t(getLocaleKey('CONDITION_PLACEHOLDER'))"
                  class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 hover:border-slate-300 dark:hover:border-slate-600 focus:ring-2 focus:ring-green-500/20 focus:border-green-500 transition-all duration-200 resize-none placeholder:text-slate-400 dark:placeholder:text-slate-500"
                  rows="3"
                ></textarea>
              </div>
            </div>
          </div>
        </div>
      </div>

      <Button 
        id="btnAddCategory" 
        class="w-full py-3 border-2 border-dashed border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-400 hover:border-green-400 hover:text-green-600 transition-all duration-200 rounded-xl bg-transparent hover:bg-green-50 dark:hover:bg-green-900/10" 
        variant="ghost"
        @click="addCategory"
      >
        <span class="flex items-center gap-2">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
          </svg>
          {{ $t(getLocaleKey('ADD_CATEGORY')) }}
        </span>
      </Button>
    </div>
    
    <div class="w-[240px] flex flex-col gap-3">
      <div class="sticky top-4 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm">
        <div class="flex items-center gap-3 mb-4">
          <div class="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path>
            </svg>
          </div>
          <div>
            <h3 class="font-semibold text-slate-700 dark:text-slate-300">{{ $t(getLocaleKey('CATEGORY_TITLE')) }}</h3>
            <p class="text-sm text-slate-500 dark:text-slate-400">{{ categories.length }} items</p>
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
            {{ $t(getLocaleKey('SAVE_BUTTON')) }}
          </span>
        </Button>
        
      </div>
    </div>
  </div>
</template>
