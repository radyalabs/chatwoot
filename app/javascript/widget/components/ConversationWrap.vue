<script>
import ChatMessage from 'widget/components/ChatMessage.vue';
import AgentTypingBubble from 'widget/components/AgentTypingBubble.vue';
import DateSeparator from 'shared/components/DateSeparator.vue';
import Spinner from 'shared/components/Spinner.vue';
import { useDarkMode } from 'widget/composables/useDarkMode';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { mapActions, mapGetters } from 'vuex';

export default {
  name: 'ConversationWrap',
  components: {
    ChatMessage,
    AgentTypingBubble,
    DateSeparator,
    Spinner,
  },
  props: {
    groupedMessages: {
      type: Array,
      default: () => [],
    },
  },
  setup() {
    const { darkMode } = useDarkMode();
    return { darkMode };
  },
  data() {
    return {
      previousScrollHeight: 0,
    };
  },
  computed: {
    ...mapGetters({
      earliestMessage: 'conversation/getEarliestMessage',
      lastMessage: 'conversation/getLastMessage',
      allMessagesLoaded: 'conversation/getAllMessagesLoaded',
      isFetchingList: 'conversation/getIsFetchingList',
      conversationSize: 'conversation/getConversationSize',
      isAgentTyping: 'conversation/getIsAgentTyping',
      conversationAttributes: 'conversationAttributes/getConversationParams',
    }),
    messageCount() {
      if (!this.groupedMessages) return 0;
      return this.groupedMessages.reduce((acc, group) => acc + group.messages.length, 0);
    },
    colorSchemeClass() {
      return `${this.darkMode === 'dark' ? 'dark-scheme' : 'light-scheme'}`;
    },
    showStatusIndicator() {
      const { status } = this.conversationAttributes;
      const isConversationInPendingStatus = status === 'pending';
      const isLastMessageIncoming =
        this.lastMessage.message_type === MESSAGE_TYPE.INCOMING;
      return (
        this.isAgentTyping ||
        (isConversationInPendingStatus && isLastMessageIncoming)
      );
    },
    cleanedGroupedMessages() {
      if (!this.groupedMessages.length) return [];

      let isFirstMessageRemoved = false;

      return this.groupedMessages.map(group => {
        const filtered = group.messages.filter((msg, index) => {
          if (!isFirstMessageRemoved) {
            const isAutoHalo =
              msg.sender?.type === 'contact' &&
              typeof msg.content === 'string' &&
              msg.content.trim().toLowerCase() === 'halo';

            if (isAutoHalo) {
              isFirstMessageRemoved = true;
              return false; // sembunyikan
            }
          }
          return true;
        });

        return {
          date: group.date,
          messages: filtered
        };
      });
    },
  },
  watch: {
    allMessagesLoaded() {
      this.previousScrollHeight = 0;
    },
    messageCount(newCount, oldCount) {
      this.$nextTick(() => {
        this.scrollToBottom();
      });
    }
  },
  mounted() {
    this.$el.addEventListener('scroll', this.handleScroll);
    this.scrollToBottom();
  },
  updated() {
    if (this.previousConversationSize !== this.conversationSize) {
      this.previousConversationSize = this.conversationSize;
      this.$nextTick(() => {
        this.scrollToBottom();
      });
    }
  },
  unmounted() {
    this.$el.removeEventListener('scroll', this.handleScroll);
  },
  methods: {
    ...mapActions('conversation', ['fetchOldConversations']),
    scrollToBottom() {
      const container = this.$el;
      if (this.previousScrollHeight > 0) {
        container.scrollTop = container.scrollHeight - this.previousScrollHeight;
        this.previousScrollHeight = 0;
      } else {
        container.scrollTo({
          top: container.scrollHeight,
          behavior: 'smooth' 
        });
      }
    },
    handleScroll() {
      if (
        this.isFetchingList ||
        this.allMessagesLoaded ||
        !this.conversationSize
      ) {
        return;
      }

      if (this.$el.scrollTop > 200) {
        this.previousScrollHeight = 0;
      }

      // Logika fetch history (saat di pucuk atas)
      if (this.$el.scrollTop < 100) {
        // Simpan tinggi saat ini SEBELUM data baru masuk
        this.previousScrollHeight = this.$el.scrollHeight;
        this.fetchOldConversations({ before: this.earliestMessage.id });
      }
    },
  },
};
</script>

<template>
  <div class="conversation--container" :class="colorSchemeClass">
    <div class="conversation-wrap" :class="{ 'is-typing': isAgentTyping }">
      <div v-if="isFetchingList" class="message--loader">
        <Spinner />
      </div>
      <div
        v-for="groupedMessage in cleanedGroupedMessages"
        :key="groupedMessage.date"
        class="messages-wrap"
      >
        <DateSeparator :date="groupedMessage.date" />
        <ChatMessage
          v-for="message in groupedMessage.messages"
          :key="message.id"
          :message="message"
        />
      </div>
      <AgentTypingBubble v-if="showStatusIndicator" />
    </div>
  </div>
</template>

<style scoped lang="scss">
@import 'widget/assets/scss/variables.scss';
@import 'widget/assets/scss/mixins.scss';

.conversation--container {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow-y: auto;
  color-scheme: light dark;

  &.light-scheme {
    color-scheme: light;
  }

  &.dark-scheme {
    color-scheme: dark;
  }
}

.conversation-wrap {
  flex: 1;
  padding: $space-large $space-small $space-small $space-small;
}

.message--loader {
  text-align: center;
}
</style>
