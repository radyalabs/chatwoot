<!-- eslint-disable no-console -->
<script setup>
import { ref, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import DynamicSkillModal from '../skills/DynamicSkillModal.vue';
import aiAgents from '../../../../../api/aiAgents';

const BUILTIN_SKILLS_DEFINITIONS = [
  {
    key: 'lead_capture',
    name: 'Lead Capture',
    description: 'Kumpulkan informasi kontak (nama, nomor HP) dan ketertarikan produk customer',
  },
  {
    key: 'support_ticket',
    name: 'Support Ticket',
    description: 'Tangani keluhan customer, buat dan cek status support ticket',
  },
  {
    key: 'consultation_scheduling',
    name: 'Consultation Scheduling',
    description: 'Jadwalkan konsultasi atau follow-up dengan customer',
  },
  {
    key: 'product_search',
    name: 'Product Search',
    description: 'Cari informasi produk, layanan, katalog, dan knowledge base bisnis',
  },
];

const SKILL_ICONS = {
  lead_capture: '🎯',
  support_ticket: '🎫',
  consultation_scheduling: '📅',
  product_search: '🔍',
};

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
  aiAgentId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['update:data']);

const store = useStore();
const dynamicSkills = useMapGetter('agentSkills/getSkills');
const uiFlags = useMapGetter('agentSkills/getUIFlags');

const isSaving = ref(false);
const editingSkill = ref(null);
const modalRef = ref(null);
const builtinSkillsConfig = ref([]);
const selectedKey = ref(null);

function initBuiltinSkills() {
  const flowData = props.data?.flow_data;
  const agentIndex = flowData?.enabled_agents?.indexOf('lead_generation') ?? -1;
  const savedSkills =
    agentIndex !== -1
      ? (flowData?.agents_config?.[agentIndex]?.configurations?.skills ?? [])
      : [];

  builtinSkillsConfig.value = BUILTIN_SKILLS_DEFINITIONS.map(def => {
    const saved = savedSkills.find(s => s.key === def.key);
    return {
      ...def,
      enabled: saved?.enabled ?? true,
      instructions: saved?.instructions ?? '',
    };
  });
}

onMounted(async () => {
  initBuiltinSkills();
  if (props.aiAgentId) {
    await store.dispatch('agentSkills/get', props.aiAgentId);
  }
});

function toggleChip(key) {
  const skill = builtinSkillsConfig.value.find(s => s.key === key);
  if (!skill.enabled) {
    skill.enabled = true;
    selectedKey.value = key;
  } else if (selectedKey.value === key) {
    selectedKey.value = null;
  } else {
    selectedKey.value = key;
  }
}

function disableSkill(key) {
  const skill = builtinSkillsConfig.value.find(s => s.key === key);
  skill.enabled = false;
}

function chipClass(skill) {
  if (skill.enabled && selectedKey.value === skill.key) {
    return 'bg-green-100 dark:bg-green-900/40 border-green-500 dark:border-green-500 text-green-800 dark:text-green-300';
  }
  if (skill.enabled) {
    return 'bg-green-50 dark:bg-green-900/20 border-green-300 dark:border-green-700 text-green-700 dark:text-green-400';
  }
  return 'bg-slate-50 dark:bg-slate-800/50 border-slate-200 dark:border-slate-700 text-slate-500 dark:text-slate-400 opacity-65';
}

function selectedSkill() {
  return builtinSkillsConfig.value.find(s => s.key === selectedKey.value) ?? null;
}

async function saveBuiltinSkills() {
  if (isSaving.value) return;
  try {
    isSaving.value = true;
    const flowData = JSON.parse(JSON.stringify(props.data.flow_data));
    const displayFlowData = JSON.parse(JSON.stringify(props.data.display_flow_data));
    const agentIndex = flowData.enabled_agents.indexOf('lead_generation');
    if (agentIndex === -1) return;

    if (!flowData.agents_config[agentIndex].configurations) {
      flowData.agents_config[agentIndex].configurations = {};
    }

    const skillsPayload = builtinSkillsConfig.value.map(s => ({
      key: s.key,
      enabled: s.enabled,
      instructions: s.instructions,
    }));

    flowData.agents_config[agentIndex].configurations.skills = skillsPayload;
    if (!displayFlowData.agents_config[agentIndex].configurations) {
      displayFlowData.agents_config[agentIndex].configurations = {};
    }
    displayFlowData.agents_config[agentIndex].configurations.skills = skillsPayload;

    await aiAgents.updateAgent(props.data.id, {
      flow_data: flowData,
      display_flow_data: displayFlowData,
    });
    emit('update:data');
  } catch (e) {
    console.error('Save builtin skills error:', e);
  } finally {
    isSaving.value = false;
  }
}

function openAddModal() {
  editingSkill.value = null;
  modalRef.value?.open();
}

function openEditModal(skill) {
  editingSkill.value = { ...skill };
  modalRef.value?.open();
}

async function handleModalSave(payload) {
  try {
    if (payload.id) {
      await store.dispatch('agentSkills/update', {
        aiAgentId: props.aiAgentId,
        skillId: payload.id,
        data: payload,
      });
    } else {
      await store.dispatch('agentSkills/create', {
        aiAgentId: props.aiAgentId,
        data: payload,
      });
    }
  } catch (error) {
    console.error('Failed to save dynamic skill:', error);
  }
  editingSkill.value = null;
}

async function handleDelete(skillId) {
  try {
    await store.dispatch('agentSkills/delete', {
      aiAgentId: props.aiAgentId,
      skillId,
    });
  } catch (error) {
    console.error('Failed to delete skill:', error);
  }
}
</script>

<template>
  <div class="space-y-6">
    <!-- Built-in Skills Section -->
    <div>
      <div class="flex items-center justify-between mb-3">
        <div>
          <h4 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
            Built-in Skills
          </h4>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Klik untuk aktifkan/nonaktifkan. Pilih skill aktif untuk set instruksi.
          </p>
        </div>
        <Button
          :label="isSaving ? 'Menyimpan...' : 'Simpan'"
          size="sm"
          :disabled="isSaving"
          class="bg-green-600 hover:bg-green-700 rounded-md shrink-0"
          @click="saveBuiltinSkills"
        />
      </div>

      <!-- Chip row -->
      <div class="flex flex-wrap gap-2 mb-3">
        <button
          v-for="skill in builtinSkillsConfig"
          :key="skill.key"
          type="button"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-xs font-medium transition-all duration-150 cursor-pointer select-none"
          :class="chipClass(skill)"
          @click="toggleChip(skill.key)"
        >
          <span>{{ SKILL_ICONS[skill.key] }}</span>
          <span>{{ skill.name }}</span>
          <span
            v-if="skill.enabled"
            class="w-1.5 h-1.5 rounded-full bg-green-500 dark:bg-green-400 ml-0.5"
          />
        </button>
      </div>

      <!-- Accordion detail panel -->
      <Transition
        enter-active-class="transition-all duration-200 ease-out"
        leave-active-class="transition-all duration-150 ease-in"
        enter-from-class="opacity-0 -translate-y-1.5"
        leave-to-class="opacity-0 -translate-y-1.5"
      >
        <div
          v-if="selectedKey && selectedSkill()"
          class="border border-slate-200 dark:border-slate-700 border-l-2 border-l-green-500 rounded-lg p-4 bg-white dark:bg-slate-800/50"
        >
          <!-- Panel header -->
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <span class="text-base">{{ SKILL_ICONS[selectedKey] }}</span>
              <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                {{ selectedSkill().name }}
              </span>
            </div>
            <!-- Active/inactive toggle -->
            <div class="flex items-center gap-2 cursor-pointer" @click="selectedSkill().enabled ? disableSkill(selectedKey) : toggleChip(selectedKey)">
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {{ selectedSkill().enabled ? 'Aktif' : 'Nonaktif' }}
              </span>
              <div
                class="relative w-9 h-5 rounded-full transition-colors duration-200"
                :class="selectedSkill().enabled ? 'bg-green-500' : 'bg-slate-300 dark:bg-slate-600'"
              >
                <span
                  class="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200"
                  :class="selectedSkill().enabled ? 'translate-x-4' : 'translate-x-0'"
                />
              </div>
            </div>
          </div>

          <!-- Skill description -->
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
            {{ selectedSkill().description }}
          </p>

          <!-- Instructions textarea (coming soon) -->
          <div class="opacity-40 pointer-events-none select-none">
            <label class="block text-xs font-medium text-slate-600 dark:text-slate-400 mb-1.5">
              Instruksi Khusus
              <span class="font-normal text-slate-400">(segera hadir)</span>
            </label>
            <textarea
              v-model="selectedSkill().instructions"
              rows="3"
              disabled
              class="w-full text-xs rounded-md border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-800 px-3 py-2 text-slate-900 dark:text-slate-100 placeholder-slate-400 resize-none cursor-not-allowed"
              placeholder="Contoh: Selalu tanya nama dulu sebelum nomor HP"
            />
          </div>
        </div>
      </Transition>
    </div>

    <!-- Custom Skills Section -->
    <div class="border-t border-slate-200 dark:border-slate-700 pt-5">
      <div class="mb-3">
        <h4 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
          Custom Skills
        </h4>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
          Hubungkan tools eksternal sebagai kemampuan tambahan.
        </p>
      </div>

      <!-- Dynamic skill chips + loading -->
      <div class="flex flex-wrap gap-2 items-center">
        <div
          v-if="uiFlags.isFetching"
          class="text-xs text-slate-400 py-1"
        >
          Memuat...
        </div>

        <template v-else>
          <!-- Dynamic skill chips -->
          <div
            v-for="skill in dynamicSkills"
            :key="skill.id"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-sky-200 dark:border-sky-700 bg-sky-50 dark:bg-sky-900/20 text-xs font-medium text-sky-700 dark:text-sky-300"
          >
            <span>🔌</span>
            <span>{{ skill.name }}</span>
            <button
              type="button"
              class="ml-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 transition-colors"
              title="Edit"
              @click="openEditModal(skill)"
            >
              <span class="i-lucide-pencil size-3" />
            </button>
            <button
              type="button"
              class="text-slate-300 hover:text-red-500 dark:hover:text-red-400 transition-colors"
              title="Hapus"
              @click="handleDelete(skill.id)"
            >
              <span class="i-lucide-x size-3" />
            </button>
          </div>

          <!-- Add button -->
          <button
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-dashed border-green-400 dark:border-green-600 text-xs font-medium text-green-600 dark:text-green-400 hover:bg-green-50 dark:hover:bg-green-900/20 transition-colors"
            @click="openAddModal"
          >
            <span class="i-lucide-plus size-3" />
            Tambah Custom Skill
          </button>
        </template>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <DynamicSkillModal
      ref="modalRef"
      :ai-agent-id="aiAgentId"
      :skill="editingSkill"
      @save="handleModalSave"
      @close="editingSkill = null"
    />
  </div>
</template>
