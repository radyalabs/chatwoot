<script>
import UserMessageBubble from 'widget/components/UserMessageBubble.vue';
import MessageReplyButton from 'widget/components/MessageReplyButton.vue';
import ImageBubble from 'widget/components/ImageBubble.vue';
import VideoBubble from 'widget/components/VideoBubble.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import FileBubble from 'widget/components/FileBubble.vue';
import { messageStamp } from 'shared/helpers/timeHelper';
import messageMixin from '../mixins/messageMixin';
import ReplyToChip from 'widget/components/ReplyToChip.vue';
import DragWrapper from 'widget/components/DragWrapper.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import { mapGetters } from 'vuex';

export default {
  name: 'UserMessage',
  components: {
    UserMessageBubble,
    MessageReplyButton,
    ImageBubble,
    VideoBubble,
    FileBubble,
    FluentIcon,
    ReplyToChip,
    DragWrapper,
  },
  mixins: [messageMixin],
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
  data() {
    return {
      imageErrors: {},
      videoErrors: {},
    };
  },
  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
    }),

    isInProgress() {
      const { status = '' } = this.message;
      return status === 'in_progress';
    },
    showTextBubble() {
      const { message } = this;
      return !!message.content;
    },
    readableTime() {
      const { created_at: createdAt = '' } = this.message;
      return messageStamp(createdAt);
    },
    isFailed() {
      const { status = '' } = this.message;
      return status === 'failed';
    },
    hasReplyTo() {
      return this.replyTo && (this.replyTo.content || this.replyTo.attachments);
    },
  },
  watch: {
    message() {
      this.imageErrors = {};
      this.videoErrors = {};
    },
  },
  methods: {
    async retrySendMessage() {
      await this.$store.dispatch(
        'conversation/sendMessageWithData',
        this.message
      );
    },
    onImageLoadError(attachmentId) {
      this.imageErrors = { ...this.imageErrors, [attachmentId]: true };
    },
    onVideoLoadError(attachmentId) {
      this.videoErrors = { ...this.videoErrors, [attachmentId]: true };
    },
    toggleReply() {
      emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.message);
    },
    hasImageError(id) {
      return !!this.imageErrors[id];
    },
    hasVideoError(id) {
      return !!this.videoErrors[id];
    },
    getAttachmentUrl(attachment) {
      if (attachment.thumb_url && (attachment.thumb_url.startsWith('blob:') || attachment.thumb_url.startsWith('data:'))) {
        return attachment.thumb_url;
      }
      if (attachment.data_url && (attachment.data_url.startsWith('blob:') || attachment.data_url.startsWith('data:'))) {
        return attachment.data_url;
      }
      return this.sanitizeUrl(attachment.data_url);
    },
    
    sanitizeUrl(url) {
      if (!url) return '';
      return url.replace('0.0.0.0', '127.0.0.1');
    }
  },
};
</script>

<template>
  <div class="user-message-wrap group">
    <div class="flex gap-1 user-message">
      <div
        class="message-wrap"
        :class="{ 'in-progress': isInProgress, 'is-failed': isFailed }"
      >
        <div v-if="hasReplyTo" class="flex justify-end mt-2 mb-1 text-xs">
          <ReplyToChip :reply-to="replyTo" />
        </div>
        <div class="flex justify-end gap-1">
          <div class="flex flex-col justify-end">
            <MessageReplyButton
              v-if="!isInProgress && !isFailed"
              class="transition-opacity delay-75 opacity-0 group-hover:opacity-100 sm:opacity-0"
              @click="toggleReply"
            />
          </div>
          <DragWrapper direction="left" @dragged="toggleReply">
            <UserMessageBubble
              v-if="showTextBubble"
              :message="message.content"
              :status="message.status"
              :widget-color="widgetColor"
            />
            <div
              v-if="hasAttachments"
              class="chat-bubble has-attachment user"
              :style="{ backgroundColor: widgetColor }"
            >
              <div
                v-for="attachment in message.attachments"
                :key="attachment.id"
              >
                <ImageBubble
                  v-if="!isFailed && attachment.file_type === 'image' && !hasImageError(attachment.id)"
                  :url="getAttachmentUrl(attachment)"
                  :thumb="getAttachmentUrl(attachment)"
                  :readable-time="readableTime"
                  @error="onImageLoadError(attachment.id)"
                />

                <VideoBubble
                  v-else-if="!isFailed && attachment.file_type === 'video' && !hasVideoError(attachment.id)"
                  :url="getAttachmentUrl(attachment)"
                  :readable-time="readableTime"
                  @error="onVideoLoadError(attachment.id)"
                />

                <div 
                  v-else-if="isFailed || hasImageError(attachment.id) || hasVideoError(attachment.id)"
                  class="error-message-bubble flex items-center p-2 cursor-default"
                >
                  <FluentIcon icon="error-circle" size="16" class="mr-2 text-red-500" />
                  <div class="flex flex-col">
                    <span class="text-xs text-red-600 font-bold">
                      {{ isFailed ? 'Gagal Terkirim' : 'Gagal Memuat' }}
                    </span>
                    <span v-if="isFailed" class="text-[10px] text-red-500">
                      Klik ikon panah untuk coba lagi
                    </span>
                  </div>
                </div>

                <FileBubble
                  v-else
                  :url="getAttachmentUrl(attachment)"
                  :attachment="attachment"
                  :is-in-progress="isInProgress"
                  :widget-color="widgetColor"
                  is-user-bubble
                />
              </div>
            </div>
          </DragWrapper>
        </div>
        
        <div
          v-if="isFailed"
          class="flex justify-end px-4 py-2 text-red-700 align-middle"
        >
          <button
            :title="$t('COMPONENTS.MESSAGE_BUBBLE.RETRY')"
            class="inline-flex items-center justify-center ml-2 hover:bg-red-100 rounded-full p-1 transition-colors"
            @click="retrySendMessage"
          >
            <FluentIcon icon="arrow-clockwise" size="16" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.error-message-bubble {
  background-color: #FEF2F2;
  border-radius: 8px;
  border: 1px solid #FECACA;
  min-width: 150px;
  margin-bottom: 4px;
}
</style>