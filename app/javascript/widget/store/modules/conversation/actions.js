import {
  createConversationAPI,
  getConversationsListAPI,
  sendMessageAPI,
  getMessagesAPI,
  sendAttachmentAPI,
  toggleTyping,
  setUserLastSeenAt,
  toggleStatus,
  setCustomAttributes,
  deleteCustomAttribute,
} from 'widget/api/conversation';

import { ON_CONVERSATION_CREATED } from 'widget/constants/widgetBusEvents';
import { createTemporaryMessage, getNonDeletedMessages } from './helpers';
import { emitter } from 'shared/helpers/mitt';

export const actions = {
  createConversation: async ({ commit, dispatch }, params) => {
    commit('setConversationUIFlag', { isCreating: true });

    try {
      const { data } = await createConversationAPI(params);
      const { messages } = data;
      const conversationId = data.id;

      if (!messages || messages.length === 0) {
        await sendMessageAPI(conversationId, 'Halo');
      } else {
        const firstMessage = messages[0];
        commit('pushMessageToConversation', {
          conversation_id: conversationId,
          ...firstMessage,
        });
      }
      dispatch('conversationAttributes/getAttributes', {}, { root: true });
      emitter.emit(ON_CONVERSATION_CREATED);
      return conversationId;

    } catch (error) {
      throw error;

    } finally {
      commit('setConversationUIFlag', { isCreating: false });
    }
  },

  sendMessage: async ({ dispatch }, params) => {
    const { content, replyTo } = params;
    const message = createTemporaryMessage({ content, replyTo });
    dispatch('sendMessageWithData', message);
  },

  sendMessageWithData: async ({ commit, getters }, message) => {
    const { id: tempId, content, replyTo, meta = {} } = message;
    const conversationId = getters.getSelectedConversationId;

    if (!conversationId) {
      console.error('No conversation selected');
      return;
    }
    commit('pushMessageToConversation', {
      ...message,
      conversation_id: conversationId,
      is_temp: true,
      status: 'in_progress',
    });

    try {
      const { data } = await sendMessageAPI(conversationId, content, replyTo);
      commit('removeMessageById', tempId);
      commit('pushMessageToConversation', {
        ...data,
        conversation_id: conversationId,
        status: 'sent',
      });

    } catch (error) {

      commit('updateMessageMeta', {
        id: tempId,
        meta: { ...meta, error: true },
      });

      commit('updateMessageStatus', { id: tempId, status: 'failed' });
    }
  },



  sendAttachment: async ({ commit, getters }, params) => {
    const {
      attachment: { thumbUrl, fileType },
      meta = {},
    } = params;

    const conversationId = getters.getSelectedConversationId;

    const attachment = {
      thumb_url: thumbUrl,
      data_url: thumbUrl,
      file_type: fileType,
      status: 'in_progress',
    };

    const tempMessage = createTemporaryMessage({
      attachments: [attachment],
      replyTo: params.replyTo,
    });

    commit('pushMessageToConversation', {
      conversation_id: conversationId,
      ...tempMessage,
    });

    try {
      const { data } = await sendAttachmentAPI(conversationId, params);

      commit('updateAttachmentMessageStatus', {
        message: data,
        tempId: tempMessage.id,
      });

      commit('pushMessageToConversation', {
        conversation_id: conversationId,
        ...data,
        status: 'sent',
      });
    } catch (error) {
      commit('pushMessageToConversation', {
        conversation_id: conversationId,
        ...tempMessage,
        status: 'failed',
      });

      commit('updateMessageMeta', {
        id: tempMessage.id,
        meta: { ...meta, error: '' },
      });
    }
  },

  loadConversation: async ({ commit, dispatch }, conversationId) => {
    commit('setActiveConversation', conversationId);
    commit('clearMessages');
    await dispatch('fetchOldConversations');
    return conversationId;
  },

  fetchOldConversations: async ({ commit, getters }, { before } = {}) => {
    try {
      commit('setConversationListLoading', true);

      const conversationId = getters.getSelectedConversationId;
      if (!conversationId) return;

      commit('initConversationObject', conversationId);

      const {
        data: { payload, meta },
      } = await getMessagesAPI({ conversationId, before });

      const { contact_last_seen_at: lastSeen } = meta;

      const formattedMessages = getNonDeletedMessages({ messages: payload });

      commit('conversation/setMetaUserLastSeenAt', lastSeen, { root: true });
      commit('setMessagesInConversation', formattedMessages);
      commit('setConversationListLoading', false);
    } catch (error) {
      commit('setConversationListLoading', false);
    }
  },

  fetchAllConversations: async ({ commit }) => {
    try {
      const response = await getConversationsListAPI();
      commit('setConversationList', response.data.payload);
    } catch (e) {
      console.error(e);
    }
  },

  syncLatestMessages: async ({ state, commit, getters }) => {
    try {
      const conversationId = getters.getSelectedConversationId;
      if (!conversationId) return;

      const convObj = state.conversations[conversationId];
      const existingMessages = convObj?.messages || [];

      const lastMessageId =
        existingMessages.length > 0
          ? existingMessages[existingMessages.length - 1].id
          : null;

      const {
        data: { payload, meta },
      } = await getMessagesAPI({
        conversationId,
        after: lastMessageId,
      });

      const { contact_last_seen_at: lastSeen } = meta;
      const formattedMessages = getNonDeletedMessages({ messages: payload });

      const missingMessages = formattedMessages.filter(
        m => !existingMessages.find(e => e.id === m.id)
      );

      if (!missingMessages.length) return;

      commit('appendMessagesToConversation', {
        conversationId,
        messages: missingMessages,
      });

      commit('conversation/setMetaUserLastSeenAt', lastSeen, { root: true });
    } catch (error) {
      // ignore
    }
  },

  clearConversations: ({ commit }) => {
    commit('clearConversations');
  },

  addOrUpdateMessage: async ({ commit, getters }, data) => {
    const { id, content_attributes } = data;
    const conversationId = getters.getSelectedConversationId;

    if (!conversationId) return;

    if (content_attributes && content_attributes.deleted) {
      commit('deleteMessage', { conversationId, id });
      return;
    }

    commit('pushMessageToConversation', {
      conversation_id: conversationId,
      ...data,
    });
  },

  toggleAgentTyping({ commit }, data) {
    commit('toggleAgentTypingStatus', data);
  },

  toggleUserTyping: async ({ getters }, { typingStatus }) => {
    const conversationId = getters.getSelectedConversationId;
    if (!conversationId) return;

    try {
      await toggleTyping({ conversationId, typingStatus });
    } catch (error) {}
  },

  setUserLastSeen: async ({ commit, getters: appGetters }) => {
    if (!appGetters.getConversationSize) {
      return;
    }

    const lastSeen = Date.now() / 1000;
    try {
      commit('setMetaUserLastSeenAt', lastSeen);
      await setUserLastSeenAt({ lastSeen });
    } catch (error) {}
  },

  resolveConversation: async () => {
    await toggleStatus();
  },

  setCustomAttributes: async (_, customAttributes = {}) => {
    try {
      await setCustomAttributes(customAttributes);
    } catch (error) {}
  },

  deleteCustomAttribute: async (_, customAttribute) => {
    try {
      await deleteCustomAttribute(customAttribute);
    } catch (error) {}
  },
};
