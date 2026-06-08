<script setup>
import { ref, computed, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import AgentSkillsAPI from 'dashboard/api/agentSkills';

const props = defineProps({
  aiAgentId: {
    type: [Number, String],
    required: true,
  },
  skill: {
    type: Object,
    default: null,
    // null = create mode; object with id = edit mode
  },
});

const emit = defineEmits(['save', 'close']);

const isOpen = ref(false);
const isSaving = ref(false);
const availableTools = ref([]);
const isLoadingTools = ref(false);

const form = ref({
  name: '',
  description: '',
  instructions: '',
  tool_ids: [],
});

const isEditing = computed(() => !!props.skill?.id);
const title = computed(() =>
  isEditing.value ? 'Edit Dynamic Skill' : 'Tambah Dynamic Skill'
);
const canSave = computed(() => form.value.name.trim() && form.value.description.trim());

watch(
  () => props.skill,
  val => {
    if (val) {
      form.value = {
        name: val.name || '',
        description: val.description || '',
        instructions: val.instructions || '',
        tool_ids: [...(val.tool_ids || [])],
      };
    } else {
      form.value = { name: '', description: '', instructions: '', tool_ids: [] };
    }
  },
  { immediate: true }
);

async function loadTools() {
  isLoadingTools.value = true;
  try {
    const response = await AgentSkillsAPI.listCustomTools(props.aiAgentId);
    availableTools.value = Array.isArray(response.data) ? response.data : [];
  } catch {
    availableTools.value = [];
  } finally {
    isLoadingTools.value = false;
  }
}

function open() {
  isOpen.value = true;
  loadTools();
}

function close() {
  isOpen.value = false;
  emit('close');
}

function toggleTool(toolId) {
  const idx = form.value.tool_ids.indexOf(toolId);
  if (idx === -1) {
    form.value.tool_ids.push(toolId);
  } else {
    form.value.tool_ids.splice(idx, 1);
  }
}

async function handleSave() {
  if (!canSave.value || isSaving.value) return;
  isSaving.value = true;
  try {
    emit('save', { ...form.value, id: props.skill?.id ?? null });
    close();
  } finally {
    isSaving.value = false;
  }
}

defineExpose({ open });
</script>

<template>
  <Teleport to="body">
    <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center">
      <!-- Backdrop -->
      <div class="absolute inset-0 bg-black/50" @click="close" />
      <!-- Modal -->
      <div
        class="relative z-10 w-full max-w-lg rounded-xl bg-white dark:bg-gray-900 shadow-xl p-6 mx-4 max-h-[90vh] overflow-y-auto"
      >
        <!-- Header -->
        <div class="flex items-center justify-between mb-5">
          <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-25">
            {{ title }}
          </h3>
          <button class="text-slate-400 hover:text-slate-600" @click="close">
            <span class="i-lucide-x size-5" />
          </button>
        </div>

        <!-- Form -->
        <div class="space-y-4">
          <!-- Name -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Nama <span class="text-red-500">*</span>
            </label>
            <input
              v-model="form.name"
              type="text"
              class="w-full rounded-md border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-green-500"
              placeholder="Contoh: Product Stock Database"
            />
          </div>

          <!-- Description -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Deskripsi <span class="text-red-500">*</span>
              <span class="text-xs text-slate-400 font-normal ml-1">
                — menentukan kapan bot menggunakan skill ini
              </span>
            </label>
            <input
              v-model="form.description"
              type="text"
              class="w-full rounded-md border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-green-500"
              placeholder="Contoh: Cek stok dan harga produk dari database internal"
            />
          </div>

          <!-- Instructions -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Instruksi Khusus
            </label>
            <textarea
              v-model="form.instructions"
              rows="3"
              class="w-full rounded-md border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-green-500 resize-none"
              placeholder="Instruksi tambahan untuk subagent ini..."
            />
          </div>

          <!-- Tool IDs multi-select -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              Custom Tools
            </label>
            <div v-if="isLoadingTools" class="text-sm text-slate-400">
              Memuat tools...
            </div>
            <div
              v-else-if="availableTools.length === 0"
              class="text-sm text-slate-400 py-2"
            >
              Belum ada custom tools tersedia untuk agent ini.
            </div>
            <div
              v-else
              class="space-y-2 max-h-40 overflow-y-auto border border-gray-100 dark:border-gray-700 rounded-md p-2"
            >
              <label
                v-for="tool in availableTools"
                :key="tool.id"
                class="flex items-center gap-2 cursor-pointer py-1"
              >
                <input
                  type="checkbox"
                  :value="tool.id"
                  :checked="form.tool_ids.includes(tool.id)"
                  class="rounded border-gray-300"
                  @change="toggleTool(tool.id)"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">
                  {{ tool.spec?.name || tool.name || tool.id }}
                </span>
              </label>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-2 mt-6">
          <Button label="Batal" variant="ghost" size="sm" @click="close" />
          <Button
            :label="isSaving ? 'Menyimpan...' : 'Simpan'"
            size="sm"
            class="bg-green-600 hover:bg-green-700 disabled:bg-gray-400"
            :disabled="!canSave || isSaving"
            @click="handleSave"
          />
        </div>
      </div>
    </div>
  </Teleport>
</template>
