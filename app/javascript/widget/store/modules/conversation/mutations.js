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
    if ($state.conversationsList && $state.conversationsList.length > 0) {
      const index = $state.conversationsList.findIndex(c => c.id === conversationId);
      
      if (index !== -1) {
        const updatedChat = { 
          ...$state.conversationsList[index], 
          unread_count: 0 
        };
        
        $state.conversationsList.splice(index, 1, updatedChat);
      }
    }
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
    console.log('%c[MUTATION] pushMessageToConversation:', 'color: purple', message);
    
    // 1. AMBIL ID DARI PESAN, JANGAN DARI STATE SELECTED
    const conversationId = message.conversation_id || $state.selectedConversationId;
    
    if (!conversationId) {
      console.warn('Message has no conversation_id provided');
      return;
    }

    // --- BAGIAN A: UPDATE DETAIL CHAT (Hanya jika chat tersebut sudah dimuat di memori) ---
    // Cek apakah detail percakapan ini ada di store ($state.conversations)
    if ($state.conversations[conversationId]) {
      const messages = $state.conversations[conversationId].messages;

      // Hapus duplikat temp message (logika asli Anda)
      if (message.id && !message.is_temp) {
        const duplicateTempIndex = messages.findIndex(
          m => m.is_temp && m.content === message.content
        );
        if (duplicateTempIndex !== -1) {
          messages.splice(duplicateTempIndex, 1);
        }
      }

      // Update atau Push Message
      if (message.id) {
        const index = messages.findIndex(m => m.id === message.id);
        if (index !== -1) {
          // Gunakan Vue.set / spread agar reaktif
          messages.splice(index, 1, { ...messages[index], ...message });
        } else {
          messages.push(message);
        }
      } else {
        // Handle echo message (optimistic update)
        const echoIndex = messages.findIndex(m => !m.id && m.content === message.content);
        if (echoIndex !== -1) messages.splice(echoIndex, 1);
        messages.push(message);
      }

      // Sort pesan
      messages.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
      $state.conversations[conversationId].messages = [...messages];
    }

    // --- BAGIAN B: UPDATE LIST PERCAKAPAN (TAMPILAN DEPAN) ---
    // Ini yang membuat kartu di halaman depan berubah
    if ($state.conversationsList && $state.conversationsList.length > 0) {
      
      const listIndex = $state.conversationsList.findIndex(c => c.id === conversationId);

      if (listIndex !== -1) {
        // Clone item untuk dimodifikasi
        const chatItem = { ...$state.conversationsList[listIndex] };
        
        // Update teks preview dan waktu
        chatItem.last_message = message.content;
        chatItem.timestamp = message.created_at;

        // Logika Unread Count (Badge)
        // Jika pesan masuk (type 0 atau 2) DAN user sedang TIDAK membuka chat ini
        const isIncoming = message.message_type === 0 || message.message_type === 2; 
        const isNotActive = $state.selectedConversationId !== conversationId;

        if (isIncoming && isNotActive) {
          chatItem.unread_count = (chatItem.unread_count || 0) + 1;
        }

        // Hapus item dari posisi lama
        $state.conversationsList.splice(listIndex, 1);
        
        // Masukkan ke posisi paling atas (index 0)
        $state.conversationsList.unshift(chatItem);
        
        console.log('[MUTATION] List updated for conversation:', conversationId);
      } else {
        // Jika percakapan belum ada di list (kasus baru), Anda bisa menambahkannya di sini
        // Tapi biasanya perlu fetch data percakapan lengkap dulu.
        console.log('[MUTATION] Conversation ID not found in list:', conversationId);
      }
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
