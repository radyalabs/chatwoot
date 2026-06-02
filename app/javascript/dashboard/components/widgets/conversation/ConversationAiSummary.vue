<script>
import { mapGetters } from 'vuex';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';

export default {
  name: 'ConversationAiSummary',

  components: { AccordionItem },

  data() {
    return {
      isOpen: true,
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
    }),
    summary() {
      return this.currentChat?.ai_summary || null;
    },
    isAssigned() {
      return !!this.currentChat?.meta?.assignee;
    },
    isGenerating() {
      const generating = this.$store.state.conversations.aiSummaryGenerating;
      return !!generating[this.currentChat?.id];
    },
    summaryState() {
      if (this.isGenerating) return 'loading';
      if (this.summary) return 'loaded';
      return 'idle';
    },
    formattedSummary() {
      if (!this.summary) return [];
      const sections = [];
      let match;
      const boldPattern = /\*\*(.+?)\*\*\s*\n+([\s\S]+?)(?=\n+\*\*|$)/g;
      while ((match = boldPattern.exec(this.summary)) !== null) {
        sections.push({ title: match[1].trim(), content: match[2].trim() });
      }
      if (!sections.length) {
        const colonPattern = /^(.+?):\s*\n+([\s\S]+?)(?=\n+\S[^\n]*:\s*\n|$)/gm;
        while ((match = colonPattern.exec(this.summary)) !== null) {
          sections.push({ title: match[1].trim(), content: match[2].trim() });
        }
      }
      return sections;
    },
  },

  watch: {
    'currentChat.id'() {
      this.isOpen = true;
    },
  },

  methods: {
    generateSummary() {
      this.$store.dispatch('generateAiSummary', {
        conversationId: this.currentChat.id,
      });
    },
    copySummary() {
      if (this.summary) {
        navigator.clipboard.writeText(this.summary);
      }
    },
  },
};
</script>

<template>
  <AccordionItem
    v-if="isAssigned"
    :title="$t('CONVERSATION.AI_SUMMARY.TITLE')"
    :is-open="isOpen"
    @toggle="isOpen = !isOpen"
  >
    <template v-if="summaryState === 'loaded'" #button>
      <button
        class="p-1 mr-1 text-n-slate-500 hover:text-n-slate-800 rounded transition-colors"
        :title="$t('CONVERSATION.AI_SUMMARY.COPY')"
        @click.stop="copySummary"
      >
        <span class="i-lucide-copy size-4" />
      </button>
    </template>

    <!-- Idle -->
    <button
      v-if="summaryState === 'idle'"
      class="flex items-center gap-2 w-full px-3 py-2 text-sm font-medium text-n-blue-text bg-n-blue-subtle border border-n-blue rounded-lg hover:bg-n-blue-light transition-colors"
      @click="generateSummary"
    >
      <span class="i-lucide-sparkles size-4" />
      {{ $t('CONVERSATION.AI_SUMMARY.GENERATE_BUTTON') }}
    </button>

    <!-- Loading -->
    <div
      v-else-if="summaryState === 'loading'"
      class="flex items-center gap-2 py-2 text-sm text-n-slate-600"
    >
      <span class="i-lucide-loader-circle animate-spin size-4" />
      {{ $t('CONVERSATION.AI_SUMMARY.LOADING') }}
    </div>

    <!-- Loaded -->
    <div v-else-if="summaryState === 'loaded'" class="text-sm space-y-3">
      <template v-if="formattedSummary.length">
        <div
          v-for="section in formattedSummary"
          :key="section.title"
          class="space-y-1"
        >
          <p class="font-semibold text-n-slate-800 dark:text-slate-200">
            {{ section.title }}
          </p>
          <p
            class="text-n-slate-600 dark:text-slate-400 whitespace-pre-line leading-relaxed"
          >
            {{ section.content }}
          </p>
        </div>
      </template>
      <p
        v-else
        class="text-n-slate-600 dark:text-slate-400 whitespace-pre-line leading-relaxed"
      >
        {{ summary }}
      </p>
    </div>
  </AccordionItem>
</template>
