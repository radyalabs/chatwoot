import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { findUndeliveredMessage } from './helpers';

export const mutations = {
  clearConversations($state) {
    $state.conversations = {};
  },
  setConversationList($state, payload) {
    if (!Array.isArray(payload)) {
      console.error("[setConversationList] payload bukan array!", payload);
      $state.conversationsList = [];
      return;
    }

    $state.conversationsList = payload
      .slice() // clone
      .sort((a, b) => b.timestamp - a.timestamp); // newest → oldest
  },

  setActiveConversation($state, conversationId) {
    $state.selectedConversationId = conversationId;
  },

  setAllMessagesLoaded(state, isLoaded) {
    state.allMessagesLoaded = isLoaded;
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
    console.log('%c[MUTATION] addOrUpdateMessage:', 'color: purple', message);
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    if (!$state.conversations[conversationId]) {
      $state.conversations[conversationId] = { messages: [], meta: {} };
    }

    const messages = $state.conversations[conversationId].messages;
    if (message.id && !message.is_temp) {
      const duplicateTempIndex = messages.findIndex(
        m => m.is_temp && m.content === message.content
      );
      
      if (duplicateTempIndex !== -1) {
        console.log('[MUTATION] Menghapus pesan temp duplikat:', messages[duplicateTempIndex]);
        messages.splice(duplicateTempIndex, 1);
      }
    }

    // Update by ID
    if (message.id) {
      const index = messages.findIndex(m => m.id === message.id);
      if (index !== -1) {
        this._vm.$set(messages, index, {
          ...messages[index],
          ...message,
        });
      } else {
        messages.push(message);
      }
    } else {
      // Remove echo message
      const echoIndex = messages.findIndex(m => !m.id && m.content === message.content);
      if (echoIndex !== -1) {
        messages.splice(echoIndex, 1);
      }
      messages.push(message);
    }

    // Sort
    messages.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

    // FORCE rerender
    $state.conversations[conversationId].messages = [...messages];
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

  clearSelectedConversation(state) {
    state.selectedConversationId = null;
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
    console.log('[mutation:setConversationListLoading] status =', status);
    $state.uiFlags.isFetchingList = status;
  },

  setMessagesInConversation($state, payload) {
    const conversationId = $state.selectedConversationId;
    console.log('[mutation:setMessagesInConversation] conversationId =', conversationId);
    if (!conversationId) return;

    if (!$state.conversations[conversationId]) {
      $state.conversations[conversationId] = { messages: [], meta: {} };
    }

    const existing = $state.conversations[conversationId].messages || [];

    console.log('[mutation:setMessagesInConversation] existing messages =', existing.length);
    console.log('[mutation:setMessagesInConversation] incoming payload =', payload.length);

    const combined = [...existing, ...payload];
    combined.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
    const unique = combined.filter(
      (msg, index, self) =>
        index === self.findIndex(m => m.id === msg.id)
    );

    console.log('[mutation:setMessagesInConversation] combined unique =', unique.length);

    $state.conversations[conversationId].messages = unique;
  },


  setMissingMessagesInConversation($state, payload) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    const existing = $state.conversations[conversationId]?.messages || [];

    const merged = [...existing, ...payload];
    const unique = merged.filter(
      (msg, index, self) => index === self.findIndex(m => m.id === msg.id)
    );

    $state.conversations[conversationId].messages = unique;
  },

  updateMessage($state, { id, content_attributes }) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    const messages = $state.conversations[conversationId]?.messages || [];
    const msg = messages.find(m => m.id === id);

    if (msg) {
      msg.content_attributes = {
        ...msg.content_attributes,
        ...content_attributes,
      };
    }
  },

  updateMessageMeta($state, { id, meta }) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    const messages = $state.conversations[conversationId]?.messages || [];
    const msg = messages.find(m => m.id === id);

    if (msg) {
      msg.meta = {
        ...msg.meta,
        ...meta,
      };
    };
  },

  setConversationMeta(state, payload) {
    state.meta = {
      ...state.meta,
      ...payload,
    };
  },

  deleteMessage($state, id) {
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    const messages = $state.conversations[conversationId]?.messages || [];
    $state.conversations[conversationId].messages = messages.filter(
      msg => msg.id !== id
    );
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
