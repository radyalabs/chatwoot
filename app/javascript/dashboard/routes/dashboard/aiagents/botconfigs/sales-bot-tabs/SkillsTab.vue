<script setup>
import { ref, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import DynamicSkillModal from '../skills/DynamicSkillModal.vue';

const props = defineProps({
  aiAgentId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();
const dynamicSkills = useMapGetter('agentSkills/getSkills');
const uiFlags = useMapGetter('agentSkills/getUIFlags');

const editingSkill = ref(null);
const modalRef = ref(null);

onMounted(async () => {
  if (props.aiAgentId) {
    await store.dispatch('agentSkills/get', props.aiAgentId);
  }
});

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
    console.error('Failed to save skill:', error);
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
    <div>
      <div class="mb-3">
        <h4 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
          Custom Skills
        </h4>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
          Tambahkan kemampuan khusus untuk bot sales Anda.
        </p>
      </div>

      <div class="flex flex-wrap gap-2 items-center">
        <div v-if="uiFlags.isFetching" class="text-xs text-slate-400 py-1">
          Memuat...
        </div>

        <template v-else>
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

    <DynamicSkillModal
      ref="modalRef"
      :ai-agent-id="aiAgentId"
      :skill="editingSkill"
      @save="handleModalSave"
      @close="editingSkill = null"
    />
  </div>
</template>
