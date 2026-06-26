<script setup>
import { ref, reactive, computed } from 'vue';

const props = defineProps({
  componentData: {
    type: Object,
    default: () => ({}),
  },
});

const accountIdInput = ref('');
const specs = ref([]);
const isLoading = ref(false);
const isCreating = ref(false);
const errorMsg = ref('');
const successMsg = ref('');
const expandedId = ref(null);
const specDetail = ref(null);
const isLoadingDetail = ref(false);
const showModal = ref(false);

const form = reactive({
  accountId: '',
  name: '',
  description: '',
  specJson: '',
});
const formError = ref('');

const typeOptions = [
  { value: 'openapi', label: 'OpenAPI' },
  { value: 'webhook', label: 'Webhook' },
  { value: 'sql', label: 'SQL' },
  { value: 'mcp', label: 'MCP' },
];
const selectedType = ref('openapi');

const TYPE_BADGE = {
  openapi: 'bg-blue-100 text-blue-700',
  sql: 'bg-purple-100 text-purple-700',
  webhook: 'bg-yellow-100 text-yellow-700',
  mcp: 'bg-green-100 text-green-700',
};

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '';
}

function clearMessages() {
  errorMsg.value = '';
  successMsg.value = '';
}

async function loadSpecs() {
  if (!accountIdInput.value) return;
  clearMessages();
  isLoading.value = true;
  try {
    const res = await fetch(
      `/super_admin/custom_tools?account_id=${encodeURIComponent(accountIdInput.value)}`,
      { headers: { Accept: 'application/json' }, credentials: 'include' }
    );
    const data = await res.json();
    if (!res.ok) {
      errorMsg.value = data?.error ?? `Error ${res.status}`;
      return;
    }
    specs.value = Array.isArray(data) ? data : [];
    expandedId.value = null;
    specDetail.value = null;
  } catch (e) {
    errorMsg.value = e.message;
  } finally {
    isLoading.value = false;
  }
}

async function toggleDetail(spec) {
  if (expandedId.value === spec.id) {
    expandedId.value = null;
    specDetail.value = null;
    return;
  }
  expandedId.value = spec.id;
  specDetail.value = null;
  isLoadingDetail.value = true;
  try {
    const res = await fetch(`/super_admin/custom_tools/${spec.id}`, {
      headers: { Accept: 'application/json' },
      credentials: 'include',
    });
    specDetail.value = await res.json();
  } catch (e) {
    errorMsg.value = e.message;
  } finally {
    isLoadingDetail.value = false;
  }
}

async function deleteSpec(spec) {
  if (!window.confirm(`Hapus spec "${spec.name}"? Aksi ini tidak dapat dibatalkan.`)) return;
  clearMessages();
  try {
    const res = await fetch(`/super_admin/custom_tools/${spec.id}`, {
      method: 'DELETE',
      headers: { 'X-CSRF-Token': csrfToken(), Accept: 'application/json' },
      credentials: 'include',
    });
    if (!res.ok) {
      const data = await res.json();
      errorMsg.value = data?.error ?? `Error ${res.status}`;
      return;
    }
    specs.value = specs.value.filter(s => s.id !== spec.id);
    if (expandedId.value === spec.id) {
      expandedId.value = null;
      specDetail.value = null;
    }
    successMsg.value = `Spec "${spec.name}" berhasil dihapus.`;
  } catch (e) {
    errorMsg.value = e.message;
  }
}

function openCreateModal() {
  form.accountId = accountIdInput.value;
  form.name = '';
  form.description = '';
  form.specJson = '';
  selectedType.value = 'openapi';
  formError.value = '';
  showModal.value = true;
}

async function submitCreate() {
  formError.value = '';
  if (!form.name.trim()) { formError.value = 'Nama wajib diisi'; return; }
  if (!form.accountId.toString().trim()) { formError.value = 'Account ID wajib diisi'; return; }

  let payload;

  if (selectedType.value === 'openapi') {
    if (!form.specJson.trim()) { formError.value = 'Spec JSON wajib diisi untuk tipe OpenAPI'; return; }
    let parsedSpec;
    try { parsedSpec = JSON.parse(form.specJson); } catch (e) {
      formError.value = `JSON tidak valid: ${e.message}`; return;
    }
    payload = {
      account_id: parseInt(form.accountId, 10),
      name: form.name.trim(),
      description: form.description.trim() || null,
      type: 'openapi',
      spec: JSON.stringify(parsedSpec),
    };
  } else {
    if (!form.specJson.trim()) { formError.value = 'Konfigurasi wajib diisi'; return; }
    let parsedConfig;
    try { parsedConfig = JSON.parse(form.specJson); } catch (e) {
      formError.value = `JSON tidak valid: ${e.message}`; return;
    }
    payload = {
      account_id: parseInt(form.accountId, 10),
      name: form.name.trim(),
      description: form.description.trim() || null,
      type: selectedType.value,
      spec: JSON.stringify(parsedConfig),
    };
  }

  isCreating.value = true;
  try {
    const res = await fetch('/super_admin/custom_tools', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken(),
        Accept: 'application/json',
      },
      body: JSON.stringify(payload),
      credentials: 'include',
    });
    const data = await res.json();
    if (!res.ok) {
      formError.value = data?.detail ?? data?.error ?? `Error ${res.status}`;
      return;
    }
    showModal.value = false;
    successMsg.value = `Spec "${data.name}" berhasil dibuat.`;
    if (accountIdInput.value.toString() === form.accountId.toString()) {
      await loadSpecs();
    }
  } catch (e) {
    formError.value = e.message;
  } finally {
    isCreating.value = false;
  }
}

function formatDate(dt) {
  if (!dt) return '—';
  return new Date(dt).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

const currentDetail = computed(() =>
  expandedId.value && specDetail.value?.id === expandedId.value ? specDetail.value : null
);

const specJsonPlaceholder = computed(() => {
  if (selectedType.value === 'openapi') return '{"openapi": "3.0.0", "info": {...}, ...}';
  if (selectedType.value === 'webhook') return '{"url": "https://...", "description": "...", "method": "POST"}';
  if (selectedType.value === 'sql') return '{"queries": [{"name": "...", "sql": "...", "description": "..."}]}';
  return '{"server_url": "http://...", "transport": "sse", "description": "..."}';
});

function handleFileUpload(event) {
  const file = event.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = e => { form.specJson = e.target.result; };
  reader.readAsText(file);
}
</script>

<template>
  <div class="p-6 max-w-6xl">
    <!-- Header -->
    <div class="mb-6">
      <h1 class="text-2xl font-bold text-slate-900">Custom Tools</h1>
      <p class="text-sm text-slate-500 mt-1">Kelola OpenAPI/Webhook/SQL/MCP spec untuk digunakan oleh AI Agent.</p>
    </div>

    <!-- Alert messages -->
    <div v-if="errorMsg" class="mb-4 flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-3 rounded-lg">
      <svg class="w-4 h-4 mt-0.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
      <span>{{ errorMsg }}</span>
      <button class="ml-auto text-red-400 hover:text-red-600" @click="errorMsg = ''">✕</button>
    </div>
    <div v-if="successMsg" class="mb-4 flex items-center gap-2 bg-green-50 border border-green-200 text-green-700 text-sm px-4 py-3 rounded-lg">
      <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
      </svg>
      <span>{{ successMsg }}</span>
      <button class="ml-auto text-green-400 hover:text-green-600" @click="successMsg = ''">✕</button>
    </div>

    <!-- Filter bar -->
    <div class="flex items-center gap-3 mb-6">
      <div class="flex-1 max-w-xs">
        <label class="block text-xs font-medium text-slate-600 mb-1">Account ID</label>
        <input
          v-model.number="accountIdInput"
          type="text"
          inputmode="numeric"
          placeholder="Masukkan account ID..."
          class="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
          @keydown.enter="loadSpecs"
        />
      </div>
      <button
        class="mt-5 px-4 py-2 bg-woot-500 hover:bg-woot-600 text-white rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
        :disabled="isLoading || !accountIdInput"
        @click="loadSpecs"
      >
        <span v-if="isLoading" class="flex items-center gap-2">
          <svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25"/>
            <path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" class="opacity-75"/>
          </svg>
          Memuat...
        </span>
        <span v-else>Muat Specs</span>
      </button>
      <button
        class="mt-5 px-4 py-2 border border-woot-500 text-woot-600 hover:bg-woot-50 rounded-lg text-sm font-medium transition-colors flex items-center gap-1.5"
        @click="openCreateModal"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Buat Spec Baru
      </button>
    </div>

    <!-- Specs table -->
    <div v-if="specs.length > 0" class="border border-slate-200 rounded-xl overflow-hidden bg-white">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 border-b border-slate-200">
          <tr>
            <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Nama</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Tipe</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Operasi</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Base URL</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Dibuat</th>
            <th class="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody>
          <template v-for="spec in specs" :key="spec.id">
            <tr
              class="border-b border-slate-100 hover:bg-slate-50 transition-colors cursor-pointer"
              :class="{ 'bg-woot-25': expandedId === spec.id }"
              @click="toggleDetail(spec)"
            >
              <td class="px-4 py-3">
                <div class="font-medium text-slate-900">{{ spec.name }}</div>
                <div v-if="spec.description" class="text-xs text-slate-400 mt-0.5 truncate max-w-[200px]">{{ spec.description }}</div>
              </td>
              <td class="px-4 py-3">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                  :class="TYPE_BADGE[spec.tool_type] ?? 'bg-slate-100 text-slate-600'"
                >{{ spec.tool_type }}</span>
              </td>
              <td class="px-4 py-3 text-slate-700">{{ spec.operation_count ?? 0 }}</td>
              <td class="px-4 py-3 text-slate-500 text-xs truncate max-w-[160px]">{{ spec.base_url ?? '—' }}</td>
              <td class="px-4 py-3 text-slate-400 text-xs whitespace-nowrap">{{ formatDate(spec.created_at) }}</td>
              <td class="px-4 py-3">
                <div class="flex items-center justify-end gap-2" @click.stop>
                  <button
                    class="p-1.5 text-slate-400 hover:text-woot-600 rounded transition-colors"
                    title="Lihat detail"
                    @click="toggleDetail(spec)"
                  >
                    <svg class="w-4 h-4 transition-transform" :class="{ 'rotate-180': expandedId === spec.id }" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                    </svg>
                  </button>
                  <button
                    class="p-1.5 text-slate-400 hover:text-red-600 rounded transition-colors"
                    title="Hapus"
                    @click="deleteSpec(spec)"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
              </td>
            </tr>

            <!-- Detail row -->
            <tr v-if="expandedId === spec.id" class="bg-slate-50">
              <td colspan="6" class="px-6 py-4">
                <div v-if="isLoadingDetail" class="text-sm text-slate-400">Memuat detail...</div>
                <div v-else-if="currentDetail">
                  <div class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">
                    Operasi ({{ (currentDetail.operations ?? []).length }})
                  </div>
                  <div v-if="currentDetail.operations?.length" class="space-y-1">
                    <div
                      v-for="op in currentDetail.operations"
                      :key="op.operation_id"
                      class="flex items-start gap-3 text-xs bg-white border border-slate-200 rounded-md px-3 py-2"
                    >
                      <span
                        class="font-mono font-bold uppercase shrink-0 min-w-[48px]"
                        :class="{
                          'text-green-700': op.method === 'get',
                          'text-blue-700': op.method === 'post',
                          'text-orange-700': op.method === 'patch' || op.method === 'put',
                          'text-red-700': op.method === 'delete',
                        }"
                      >{{ op.method }}</span>
                      <span class="font-mono text-slate-600">{{ op.path }}</span>
                      <span class="text-slate-400 ml-1">{{ op.summary }}</span>
                    </div>
                  </div>
                  <div v-else class="text-xs text-slate-400">Tidak ada operasi.</div>

                  <div v-if="currentDetail.skipped_operations?.length" class="mt-3">
                    <div class="text-xs font-semibold text-slate-400 uppercase tracking-wide mb-1">
                      Dilewati ({{ currentDetail.skipped_operations.length }})
                    </div>
                    <div
                      v-for="op in currentDetail.skipped_operations"
                      :key="op.operation_id"
                      class="text-xs text-slate-400 flex gap-3 items-center py-0.5"
                    >
                      <span class="font-mono uppercase">{{ op.method }}</span>
                      <span class="font-mono">{{ op.path }}</span>
                      <span class="text-yellow-600 text-[11px]">{{ op.reason }}</span>
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <!-- Empty state -->
    <div v-else-if="!isLoading && accountIdInput" class="flex flex-col items-center justify-center py-16 text-slate-400">
      <svg class="w-12 h-12 mb-3 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 3H5a2 2 0 00-2 2v4m6-6h10a2 2 0 012 2v4M9 3v18m0 0h10a2 2 0 002-2V9M9 21H5a2 2 0 01-2-2V9m0 0h18"/>
      </svg>
      <p class="text-sm">Tidak ada custom tool spec untuk account ini.</p>
      <button class="mt-3 text-sm text-woot-600 hover:underline" @click="openCreateModal">Buat spec baru</button>
    </div>

    <!-- Initial hint -->
    <div v-else-if="!isLoading && !accountIdInput" class="flex flex-col items-center justify-center py-16 text-slate-300">
      <svg class="w-12 h-12 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
      </svg>
      <p class="text-sm">Masukkan Account ID lalu klik "Muat Specs".</p>
    </div>

    <!-- Create Modal -->
    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-[9999] flex items-center justify-center">
        <div class="absolute inset-0 bg-black/50" @click="showModal = false" />
        <div class="relative z-10 w-full max-w-2xl mx-4 bg-white rounded-xl shadow-2xl max-h-[90vh] flex flex-col">
          <!-- Modal header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-slate-200">
            <h2 class="text-lg font-semibold text-slate-900">Buat Spec Baru</h2>
            <button class="text-slate-400 hover:text-slate-600 p-1" @click="showModal = false">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Modal body -->
          <div class="overflow-y-auto px-6 py-5 space-y-4 flex-1">
            <div v-if="formError" class="bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-2 rounded-lg">
              {{ formError }}
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-medium text-slate-700 mb-1">Account ID <span class="text-red-500">*</span></label>
                <input
                  v-model="form.accountId"
                  type="number"
                  class="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
                  placeholder="e.g. 1"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-700 mb-1">Tipe <span class="text-red-500">*</span></label>
                <select
                  v-model="selectedType"
                  class="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500 bg-white"
                >
                  <option v-for="opt in typeOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">Nama <span class="text-red-500">*</span></label>
              <input
                v-model="form.name"
                type="text"
                class="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
                placeholder="e.g. Product Catalog API"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">Deskripsi</label>
              <input
                v-model="form.description"
                type="text"
                class="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
                placeholder="Opsional"
              />
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-medium text-slate-700">
                  {{ selectedType === 'openapi' ? 'Spec JSON/YAML' : 'Konfigurasi JSON' }}
                  <span class="text-red-500">*</span>
                </label>
                <label class="cursor-pointer text-xs text-woot-600 hover:underline flex items-center gap-1">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
                  </svg>
                  Upload file
                  <input type="file" class="hidden" accept=".json,.yaml,.yml" @change="handleFileUpload" />
                </label>
              </div>
              <textarea
                v-model="form.specJson"
                rows="12"
                class="w-full border border-slate-200 rounded-lg px-3 py-2 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-woot-500 resize-none bg-slate-50"
                :placeholder="specJsonPlaceholder"
              />
            </div>
          </div>

          <!-- Modal footer -->
          <div class="px-6 py-4 border-t border-slate-200 flex justify-end gap-3">
            <button
              class="px-4 py-2 text-sm border border-slate-200 text-slate-600 hover:bg-slate-50 rounded-lg transition-colors"
              @click="showModal = false"
            >
              Batal
            </button>
            <button
              class="px-4 py-2 text-sm bg-woot-500 hover:bg-woot-600 text-white rounded-lg font-medium transition-colors disabled:opacity-50 flex items-center gap-2"
              :disabled="isCreating"
              @click="submitCreate"
            >
              <svg v-if="isCreating" class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25"/>
                <path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" class="opacity-75"/>
              </svg>
              {{ isCreating ? 'Membuat...' : 'Simpan' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
