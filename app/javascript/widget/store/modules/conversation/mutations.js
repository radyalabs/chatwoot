import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { findUndeliveredMessage } from './helpers';

export const mutations = {
  clearConversations($state) {
    $state.conversations = {};
  },
  setConversationList($state, payload) {
    $state.conversationsList = payload;
  },

  setActiveConversation($state, conversationId) {
    $state.selectedConversationId = conversationId;
  },

  clearMessages($state) {
    const id = $state.selectedConversationId;
    if (id && $state.conversations[id]) {
      $state.conversations[id].messages = [];
    }
  },
  initConversationObject($state, conversationId) {
    if (!$state.conversations) {
      $state.conversations = {};
    }

    if (!$state.conversations[conversationId]) {
      $state.conversations[conversationId] = {
        messages: [],
        meta: {},
      };
    }
  },
  pushMessageToConversation($state, message) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    if (!$state.conversations[conversationId]) {
      $state.conversations[conversationId] = { messages: [], meta: {} };
    }

    const messages = $state.conversations[conversationId].messages;
    const exists = messages.some(m =>
      (m.id && m.id === message.id) ||
      (m.content && m.content === message.content && !m.id)
    );
    if (!exists) {
      messages.push(message);
    }
  },

  removeMessageById($state, id) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    const messages = $state.conversations[conversationId]?.messages || [];
    $state.conversations[conversationId].messages = messages.filter(
      msg => msg.id !== id
    );
  },

  updateMessageStatus($state, { id, status }) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    const messages = $state.conversations[conversationId]?.messages || [];
    const msg = messages.find(m => m.id === id);
    if (msg) msg.status = status;
  },


  updateAttachmentMessageStatus($state, { message, tempId }) {
    const { id } = message;
    const messagesInbox = $state.conversations;

    const messageInConversation = messagesInbox[tempId];

    if (messageInConversation) {
      // [VITE] instead of leaving undefined behind, we remove it completely
      // remove the temporary message and replace it with the new message
      // messagesInbox[tempId] = undefined;
      delete messagesInbox[tempId];
      messagesInbox[id] = { ...message };
    }
  },

  setConversationUIFlag($state, uiFlags) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...uiFlags,
    };
  },

  setConversationListLoading($state, status) {
    $state.uiFlags.isFetchingList = status;
  },

  setMessagesInConversation($state, payload) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    if (!$state.conversations[conversationId]) {
      $state.conversations[conversationId] = { messages: [], meta: {} };
    }

    const existing = $state.conversations[conversationId].messages || [];

    const combined = [...payload, ...existing];
    const unique = combined.filter(
      (msg, index, self) =>
        index === self.findIndex(m => m.id === msg.id)
    );

    $state.conversations[conversationId].messages = unique;
  },


  setMissingMessagesInConversation($state, payload) {
    $state.conversation = payload;
  },

  updateMessage($state, { id, content_attributes }) {
    $state.conversations[id] = {
      ...$state.conversations[id],
      content_attributes: {
        ...($state.conversations[id].content_attributes || {}),
        ...content_attributes,
      },
    };
  },

  updateMessageMeta($state, { id, meta }) {
    const message = $state.conversations[id];
    if (!message) return;

    const newMeta = message.meta ? { ...message.meta, ...meta } : { ...meta };
    message.meta = { ...newMeta };
  },

  setConversationMeta($state, payload) {
    $state.meta = {
      ...$state.meta,
      ...payload,
    };
  },

  deleteMessage($state, id) {
    delete $state.conversations[id];
    // [VITE] In Vue 3 proxy objects, we can't delete properties by setting them to undefined
    // Instead, we have to use the delete operator
    // $state.conversations[id] = undefined;
  },

  toggleAgentTypingStatus($state, { status }) {
    $state.uiFlags.isAgentTyping = status === 'on';
  },

  setMetaUserLastSeenAt($state, lastSeen) {
    $state.meta.userLastSeenAt = lastSeen;
  },

  setLastMessageId($state) {
    const { conversations } = $state;
    const lastMessage = Object.values(conversations).pop();
    if (!lastMessage) return;
    const { id } = lastMessage;
    $state.lastMessageId = id;
  },
};
