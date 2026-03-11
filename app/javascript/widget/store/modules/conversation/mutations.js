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
    console.log('%c[MUTATION] pushMessageToConversation:', 'color: purple', message);
    const conversationId = $state.selectedConversationId;
    if (!conversationId) return;

    if (!$state.conversations[conversationId]) {
      $state.conversations[conversationId] = { messages: [], meta: {} };
    }

    const messages = $state.conversations[conversationId].messages;

    // -----------------------------------------------------------------------
    // BAGIAN 1: MENANGANI PESAN BARU (MENGGANTIKAN TEMP)
    // -----------------------------------------------------------------------
    // Logika ini berjalan saat API Upload selesai dan mengirim pesan "asli"
    if (message.id && !message.is_temp) {
      // Cari pesan sementara (temp) yang cocok untuk dihapus/digantikan
      const duplicateTempIndex = messages.findIndex(
        m => m.is_temp && (
          (m.content && m.content === message.content) || 
          (message.attachments && message.attachments.length > 0 && m.attachments && m.attachments.length > 0)
        )
      );
      
      if (duplicateTempIndex !== -1) {
        const tempMsg = messages[duplicateTempIndex];
        console.log('[MUTATION] Menemukan pesan temp. Menyelamatkan Nama File...');

        // Transfer data NAMA FILE dan BLOB dari temp ke pesan asli
        if (tempMsg.attachments && message.attachments) {
          message.attachments.forEach((realAtt, index) => {
            const tempAtt = tempMsg.attachments[index]; 
            if (tempAtt) {
               // A. Selamatkan URL Blob (agar gambar tidak reload/kedip)
               const blobUrl = tempAtt.data_url || tempAtt.thumb_url;
               if (blobUrl && blobUrl.startsWith('blob:')) {
                  realAtt.data_url = blobUrl;
                  realAtt.thumb_url = blobUrl;
               }

               // B. Selamatkan Metadata File (Nama, Ukuran, Ekstensi)
               if (tempAtt.file_name) realAtt.file_name = tempAtt.file_name;
               if (tempAtt.file_size) realAtt.file_size = tempAtt.file_size;
               if (tempAtt.extension) realAtt.extension = tempAtt.extension;
            }
          });
        }
        
        // Hapus pesan temp
        messages.splice(duplicateTempIndex, 1);
      }
    }

    // -----------------------------------------------------------------------
    // BAGIAN 2: UPDATE ATAU INSERT PESAN
    // -----------------------------------------------------------------------
    if (message.id) {
      const index = messages.findIndex(m => m.id === message.id);
      
      if (index !== -1) {
        // --- [PERBAIKAN UTAMA: PROTEKSI DATA NAMA FILE] ---
        // Logika ini berjalan saat WebSocket masuk membawa update
        // Kita cegah data kosong dari WebSocket menimpa data nama file yang sudah ada
        
        const existingMsg = messages[index];
        
        // Cek jika pesan lama punya attachment & pesan baru juga punya
        if (existingMsg.attachments && message.attachments) {
           message.attachments.forEach((newAtt, i) => {
             const existAtt = existingMsg.attachments[i];
             if (existAtt) {
                // 1. JANGAN HAPUS NAMA FILE
                // Jika data baru (WebSocket) tidak punya nama file, tapi data lama punya -> PAKAI DATA LAMA
                if (!newAtt.file_name && existAtt.file_name) {
                   newAtt.file_name = existAtt.file_name;
                   newAtt.file_size = existAtt.file_size;
                   newAtt.extension = existAtt.extension;
                }
                
                // 2. PERTAHANKAN BLOB URL (Agar gambar tidak reload/kedip)
                if (existAtt.data_url && existAtt.data_url.startsWith('blob:')) {
                   newAtt.data_url = existAtt.data_url;
                   newAtt.thumb_url = existAtt.thumb_url;
                }
             }
           });
        }
        // ---------------------------------------------------------

        // Lakukan Update (Merge data lama dengan data baru yang sudah kita perbaiki)
        const updatedMessage = { ...messages[index], ...message };
        messages.splice(index, 1, updatedMessage);
        
      } else {
        // Jika ID belum ada di list, masukkan sebagai pesan baru
        messages.push(message);
      }
    } else {
      // -----------------------------------------------------------------------
      // BAGIAN 3: PESAN SEMENTARA (TEMP) BARU
      // -----------------------------------------------------------------------
      // Cek duplikat pesan echo (pesan temp yang sama persis)
      const echoIndex = messages.findIndex(m => !m.id && m.content === message.content);
      if (echoIndex !== -1) {
        messages.splice(echoIndex, 1);
      }
      messages.push(message);
    }

    // Sort berdasarkan waktu (created_at)
    messages.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

    // FORCE rerender array agar tampilan update seketika
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
    const conversationId = $state.selectedConversationId;
    
    // Safety check
    if (!conversationId || !$state.conversations[conversationId]) {
      return;
    }

    const messages = $state.conversations[conversationId].messages;
    
    // Cari index pesan sementara
    const tempIndex = messages.findIndex(m => m.id === tempId);

    if (tempIndex !== -1) {
      const tempMsg = messages[tempIndex];
      
      // --- LOGIKA BARU: Transfer Metadata ---
      if (tempMsg.attachments && message.attachments) {
          message.attachments.forEach((realAtt, index) => {
            const tempAtt = tempMsg.attachments[index];
            if (tempAtt) {
               // 1. Transfer Blob
               const blobUrl = tempAtt.data_url || tempAtt.thumb_url;
               if (blobUrl && blobUrl.startsWith('blob:')) {
                  realAtt.data_url = blobUrl;
                  realAtt.thumb_url = blobUrl;
               }
               
               // 2. Transfer Nama File, Ukuran, dan Ekstensi
               if (tempAtt.file_name) realAtt.file_name = tempAtt.file_name;
               if (tempAtt.file_size) realAtt.file_size = tempAtt.file_size;
               if (tempAtt.extension) realAtt.extension = tempAtt.extension;
            }
          });
      }
      // -------------------------------------

      // Hapus pesan temp dan ganti dengan pesan asli yang sudah diperkaya datanya
      messages.splice(tempIndex, 1);
      messages.push(message);
      
      // Sort ulang
      messages.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
      
      // Force update
      $state.conversations[conversationId].messages = [...messages];
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

  updateMessageWithAttachment($state, { conversationId, messageIndex, attachment }) {
    console.log('[MUTATION] updateMessageWithAttachment called');
    
    if (!$state.conversations[conversationId]) {
      console.error('[MUTATION] Conversation not found:', conversationId);
      return;
    }

    const messages = $state.conversations[conversationId].messages;
    
    if (!messages[messageIndex]) {
      console.error('[MUTATION] Message not found at index:', messageIndex);
      return;
    }

    const message = messages[messageIndex];
    
    console.log('[MUTATION] Updating message:', message.id);
    console.log('[MUTATION] Adding attachment:', attachment);

    // Use Vue.set to ensure reactivity (for Vue 2) or direct assignment (for Vue 3)
    if (this._vm && this._vm.$set) {
      // Vue 2
      this._vm.$set(message, 'attachments', [attachment]);
    } else {
      // Vue 3 or direct assignment
      message.attachments = [attachment];
    }

    // Force array update to trigger reactivity
    $state.conversations[conversationId].messages = [...messages];
    
    console.log('[MUTATION] Message updated successfully');
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
