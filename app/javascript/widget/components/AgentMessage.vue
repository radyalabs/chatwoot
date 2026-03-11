<script>
import UserMessage from 'widget/components/UserMessage.vue';
import AgentMessageBubble from 'widget/components/AgentMessageBubble.vue';
import MessageReplyButton from 'widget/components/MessageReplyButton.vue';
import { messageStamp } from 'shared/helpers/timeHelper';
import ImageBubble from 'widget/components/ImageBubble.vue';
import VideoBubble from 'widget/components/VideoBubble.vue';
import FileBubble from 'widget/components/FileBubble.vue';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import { MESSAGE_TYPE } from 'widget/helpers/constants';
import configMixin from '../mixins/configMixin';
import messageMixin from '../mixins/messageMixin';
import { isASubmittedFormMessage } from 'shared/helpers/MessageTypeHelper';
import { useDarkMode } from 'widget/composables/useDarkMode';
import ReplyToChip from 'widget/components/ReplyToChip.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

export default {
  name: 'AgentMessage',
  components: {
    AgentMessageBubble,
    ImageBubble,
    VideoBubble,
    Thumbnail,
    UserMessage,
    FileBubble,
    MessageReplyButton,
    ReplyToChip,
  },
  mixins: [configMixin, messageMixin],
  props: {
    message: {
      type: Object,
      default: () => {},
    },
    replyTo: {
      type: Object,
      default: () => {},
    },
  },
  setup() {
    const { getThemeClass } = useDarkMode();
    const { formatMessage } = useMessageFormatter();
    return {
      getThemeClass,
      formatMessage,
    };
  },
  data() {
    return {
      hasImageError: false,
      hasVideoError: false,
    };
  },
  computed: {
    shouldDisplayAgentMessage() {
      if (
        this.contentType === 'input_select' &&
        this.messageContentAttributes.submitted_values &&
        !this.message.content
      ) {
        return false;
      }
      return this.message.content;
    },
    readableTime() {
      const { created_at: createdAt = '' } = this.message;
      return messageStamp(createdAt, 'LLL d yyyy, h:mm a');
    },
    messageType() {
      const { message_type: type = 1 } = this.message;
      return type;
    },
    contentType() {
      const { content_type: type = '' } = this.message;
      return type;
    },
    agentName() {
      if (this.message.sender) {
        return this.message.sender.available_name || this.message.sender.name;
      }

      if (this.useInboxAvatarForBot) {
        return this.channelConfig.websiteName;
      }

      return this.$t('UNREAD_VIEW.BOT');
    },
    avatarUrl() {
      const displayImage = this.useInboxAvatarForBot
        ? this.inboxAvatarUrl
        : '/assets/images/chatwoot_bot.png';

      if (this.message.message_type === MESSAGE_TYPE.TEMPLATE) {
        return displayImage;
      }

      return this.message.sender
        ? this.message.sender.avatar_url
        : displayImage;
    },
    hasRecordedResponse() {
      return (
        this.messageContentAttributes.submitted_email ||
        (this.messageContentAttributes.submitted_values &&
          !['form', 'input_csat'].includes(this.contentType))
      );
    },
    responseMessage() {
      if (this.messageContentAttributes.submitted_email) {
        return { content: this.messageContentAttributes.submitted_email };
      }

      if (this.messageContentAttributes.submitted_values) {
        if (this.contentType === 'input_select') {
          const [selectionOption = {}] =
            this.messageContentAttributes.submitted_values;
          return { content: selectionOption.title || selectionOption.value };
        }
      }
      return '';
    },
    isASubmittedForm() {
      return isASubmittedFormMessage(this.message);
    },
    submittedFormValues() {
      return this.messageContentAttributes.submitted_values.map(
        submittedValue => ({
          id: submittedValue.name,
          content: submittedValue.value,
        })
      );
    },
    wrapClass() {
      return {
        'has-text': this.shouldDisplayAgentMessage,
      };
    },
    hasReplyTo() {
      return this.replyTo && (this.replyTo.content || this.replyTo.attachments);
    },
    // Check if this message has both image attachment AND text content
    hasImageAndText() {
      return this.hasAttachments && 
             this.shouldDisplayAgentMessage &&
             this.message.attachments?.some(att => att.file_type === 'image');
    },
  },
  watch: {
    message() {
      this.hasImageError = false;
      this.hasVideoError = false;
    },
  },
  mounted() {
    this.hasImageError = false;
    this.hasVideoError = false;
  },
  methods: {
    onImageLoadError() {
      this.hasImageError = true;
    },
    onVideoLoadError() {
      this.hasVideoError = true;
    },
    toggleReply() {
      emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.message);
    },
  },
};
</script>

<template>
  <div
    class="agent-message-wrap group"
    :class="{
      'has-response': hasRecordedResponse || isASubmittedForm,
    }"
  >
    <div v-if="!isASubmittedForm" class="agent-message">
      <div class="avatar-wrap">
        <Thumbnail
          v-if="message.showAvatar || hasRecordedResponse"
          :src="avatarUrl"
          size="24px"
          :username="agentName"
        />
      </div>
      <div class="message-wrap">
        <div v-if="hasReplyTo" class="flex mt-2 mb-1 text-xs">
          <ReplyToChip :reply-to="replyTo" />
        </div>
        <div class="flex gap-1">
          <!-- COMBINED BUBBLE: Image + Text in ONE bubble -->
          <div v-if="hasImageAndText" class="space-y-0">
            <div
              class="chat-bubble agent has-attachment combined-bubble"
              :class="getThemeClass('bg-white', 'dark:bg-slate-700 has-dark-mode')"
            >
              <!-- Images FIRST -->
              <div
                v-for="attachment in message.attachments"
                :key="attachment.id"
                class="attachment-item"
              >
                <ImageBubble
                  v-if="attachment.file_type === 'image' && !hasImageError"
                  :url="attachment.data_url"
                  :thumb="attachment.data_url"
                  :readable-time="readableTime"
                  :hide-time="true"
                  :full-width="true"
                  @error="onImageLoadError"
                />
              </div>
              
              <!-- Text BELOW image (inside same bubble) -->
              <div
                v-if="shouldDisplayAgentMessage"
                v-dompurify-html="formatMessage(message.content, false)"
                class="message-content text-slate-900 dark:text-slate-50 pt-2"
              />
            </div>
          </div>

          <!-- SEPARATE RENDERING: For messages with ONLY text or ONLY attachments (not both) -->
          <div v-else class="space-y-2">
            <!-- Attachments first (for non-image or when no text) -->
            <div
              v-if="hasAttachments && !hasImageAndText"
              class="space-y-2 chat-bubble has-attachment agent"
              :class="
                (wrapClass, getThemeClass('bg-white', 'dark:bg-slate-700'))
              "
            >
              <div
                v-for="attachment in message.attachments"
                :key="attachment.id"
              >
                <ImageBubble
                  v-if="attachment.file_type === 'image' && !hasImageError"
                  :url="attachment.data_url"
                  :thumb="attachment.data_url"
                  :readable-time="readableTime"
                  @error="onImageLoadError"
                />

                <VideoBubble
                  v-if="attachment.file_type === 'video' && !hasVideoError"
                  :url="attachment.data_url"
                  :readable-time="readableTime"
                  @error="onVideoLoadError"
                />

                <audio v-else-if="attachment.file_type === 'audio'" controls>
                  <source :src="attachment.data_url" />
                </audio>
                <FileBubble v-else :url="attachment.data_url" />
              </div>
            </div>

            <!-- Text bubble (only if no combined rendering) -->
            <AgentMessageBubble
              v-if="shouldDisplayAgentMessage && !hasImageAndText"
              :content-type="contentType"
              :message-content-attributes="messageContentAttributes"
              :message-id="message.id"
              :message-type="messageType"
              :message="message.content"
            />
          </div>

          <div class="flex flex-col justify-end">
            <MessageReplyButton
              class="transition-opacity delay-75 opacity-0 group-hover:opacity-100 sm:opacity-0"
              @click="toggleReply"
            />
          </div>
        </div>
        <p
          v-if="message.showAvatar || hasRecordedResponse"
          v-dompurify-html="agentName"
          class="agent-name"
          :class="getThemeClass('text-slate-700', 'dark:text-slate-200')"
        />
      </div>
    </div>

    <UserMessage v-if="hasRecordedResponse" :message="responseMessage" />
    <div v-if="isASubmittedForm">
      <UserMessage
        v-for="submittedValue in submittedFormValues"
        :key="submittedValue.id"
        :message="submittedValue"
      />
    </div>
  </div>
</template>

<style scoped>
.combined-bubble {
  overflow: hidden;
  padding: 0 !important;
}

.combined-bubble .attachment-item {
  margin: 0;
  display: flex;
  justify-content: center;
  background-color: inherit;
}

.combined-bubble .attachment-item .image {
  display: block;
  margin-bottom: 0;
  width: 100%;
}

.combined-bubble .attachment-item .image .wrap {
  width: 100%;
  display: flex;
  justify-content: center;
}

.combined-bubble .attachment-item .image img {
  display: block;
  border-radius: 0;
  width: 100%;
  max-width: 100%;
  object-fit: cover;
}

.combined-bubble .message-content {
  padding: 12px 16px;
}

.combined-bubble .attachment-item:first-child .image img {
  border-radius: 8px 8px 0 0;
}

.combined-bubble .attachment-item .image .wrap::before {
  display: none;
}
</style>