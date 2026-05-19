<script>
import { mapGetters } from 'vuex';

export default {
  name: 'ConversationAiSummary',

  data() {
    return {
      state: 'idle', // idle | loading | loaded
      isMinimized: true,
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
    }),
    summary() {
      return this.currentChat?.ai_summary || null;
    },
    formattedSummary() {
      if (!this.summary) return [];
      const matches = [
        ...this.summary.matchAll(/\*\*(.+?)\*\*\n+([\s\S]*?)(?=\n+\*\*|$)/g),
      ];
      return matches
        .map(m => ({ title: m[1].trim(), content: m[2].trim() }))
        .filter(s => s.content);
    },
  },

  watch: {
    'currentChat.id'() {
      this.state = this.summary ? 'loaded' : 'idle';
      this.isMinimized = false;
    },
  },

  mounted() {
    this.state = this.summary ? 'loaded' : 'idle';
  },

  methods: {
    async generateSummary() {
      this.state = 'loading';
      try {
        await this.$store.dispatch('generateAiSummary', {
          conversationId: this.currentChat.id,
        });
        this.state = 'loaded';
        this.isMinimized = false;
      } catch {
        this.state = 'idle';
      }
    },
    copySummary() {
      if (this.summary) {
        navigator.clipboard.writeText(this.summary);
      }
    },
    toggleMinimize() {
      this.isMinimized = !this.isMinimized;
    },
  },
};
</script>

<template>
  <div class="conversation-ai-summary">
    <!-- Idle: generate button -->
    <button
      v-if="state === 'idle'"
      class="flex items-center gap-2 px-3 py-2 mx-4 mt-3 text-sm font-medium text-n-blue-text bg-n-blue-subtle border border-n-blue rounded-lg hover:bg-n-blue-light transition-colors"
      @click="generateSummary"
    >
      <span class="i-lucide-sparkles size-4" />
      {{ $t('CONVERSATION.AI_SUMMARY.GENERATE_BUTTON') }}
    </button>

    <!-- Loading -->
    <div
      v-else-if="state === 'loading'"
      class="flex items-center gap-2 px-4 py-3 mx-4 mt-3 text-sm text-n-slate-600 bg-n-background border border-n-weak rounded-lg"
    >
      <span class="i-lucide-loader-circle animate-spin size-4" />
      {{ $t('CONVERSATION.AI_SUMMARY.LOADING') }}
    </div>

    <!-- Loaded: summary banner -->
    <div
      v-else-if="state === 'loaded'"
      class="mx-4 mt-3 border border-n-weak rounded-lg overflow-hidden bg-n-background"
    >
      <div
        class="flex items-center justify-between px-4 py-2 bg-n-blue-subtle"
        :class="{ 'border-b border-n-weak': !isMinimized }"
      >
        <button
          class="flex items-center gap-2 text-sm font-semibold text-n-blue-text flex-1 text-left"
          @click="toggleMinimize"
        >
          <span class="i-lucide-sparkles size-4" />
          {{ $t('CONVERSATION.AI_SUMMARY.TITLE') }}
          <span
            class="i-lucide-chevron-down size-4 ml-auto transition-transform duration-200"
            :class="{ 'rotate-180': !isMinimized }"
          />
        </button>
        <div class="flex items-center gap-1 ml-2">
          <button
            class="p-1 text-n-slate-500 hover:text-n-slate-800 rounded transition-colors"
            :title="$t('CONVERSATION.AI_SUMMARY.COPY')"
            @click="copySummary"
          >
            <span class="i-lucide-copy size-4" />
          </button>
        </div>
      </div>
      <div v-if="!isMinimized" class="px-4 py-3 text-sm space-y-3">
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
    </div>
  </div>
</template>
