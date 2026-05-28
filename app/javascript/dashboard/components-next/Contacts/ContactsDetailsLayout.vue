<script setup>
import { computed, onMounted, ref, useSlots } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import Button from 'dashboard/components-next/button/Button.vue';
import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

const props = defineProps({
  buttonLabel: {
    type: String,
    default: '',
  },
  selectedContact: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['goToContactsList']);

const { t } = useI18n();
const slots = useSlots();
const route = useRoute();

const contactId = computed(() => route.params.contactId);

const selectedContactName = computed(() => {
  return props.selectedContact?.name;
});

const breadcrumbItems = computed(() => {
  const items = [
    {
      label: t('CONTACTS_LAYOUT.HEADER.BREADCRUMB.CONTACTS'),
      link: '#',
    },
  ];
  if (props.selectedContact) {
    items.push({
      label: selectedContactName.value,
    });
  }
  return items;
});

const handleBreadcrumbClick = () => {
  emit('goToContactsList');
};

const SIDEBAR_STORAGE_KEY = 'contact_detail_sidebar_open';
const isSidebarOpen = ref(false);

onMounted(() => {
  const stored = localStorage.getItem(SIDEBAR_STORAGE_KEY);
  if (stored !== null) isSidebarOpen.value = stored === 'true';
});

const toggleSidebar = () => {
  isSidebarOpen.value = !isSidebarOpen.value;
  localStorage.setItem(SIDEBAR_STORAGE_KEY, String(isSidebarOpen.value));
};
</script>

<template>
  <section
    class="flex w-full h-full overflow-hidden justify-evenly bg-n-background"
  >
    <div
      class="flex flex-col w-full h-full transition-all duration-300"
      :class="isSidebarOpen ? 'ltr:2xl:ml-56 rtl:2xl:mr-56' : ''"
    >
      <header class="sticky top-0 z-10 px-6 xl:px-0">
        <div class="w-full mx-auto max-w-[650px]">
          <div class="flex items-center justify-between w-full h-20 gap-2">
            <Breadcrumb
              :items="breadcrumbItems"
              @click="handleBreadcrumbClick"
            />
            <ComposeConversation :contact-id="contactId">
              <template #trigger="{ toggle }">
                <Button :label="buttonLabel" size="sm" @click="toggle" />
              </template>
            </ComposeConversation>
          </div>
        </div>
      </header>
      <main class="flex-1 px-6 overflow-y-auto xl:px-px">
        <div class="w-full py-4 mx-auto max-w-[650px]">
          <slot name="default" />
        </div>
      </main>
    </div>

    <div
      v-if="slots.sidebar"
      class="flex h-full transition-all duration-300"
      :class="isSidebarOpen ? 'min-w-[200px] w-full max-w-[440px]' : 'flex-shrink-0'"
    >
      <woot-button
        v-tooltip="isSidebarOpen ? 'Sembunyikan panel' : 'Tampilkan panel'"
        variant="smooth"
        size="tiny"
        color-scheme="secondary"
        class="flex-shrink-0 self-start mt-20 box-border bg-white border border-r-0 border-solid rounded-l-lg rtl:rotate-180 border-n-weak"
        :icon="isSidebarOpen ? 'arrow-chevron-right' : 'arrow-chevron-left'"
        @click="toggleSidebar"
      />
      <div
        class="h-full overflow-y-auto transition-all duration-300 border-l border-n-weak bg-n-solid-2"
        :class="isSidebarOpen ? 'flex-1 py-6' : 'w-0 overflow-hidden'"
      >
        <slot name="sidebar" />
      </div>
    </div>
  </section>
</template>
