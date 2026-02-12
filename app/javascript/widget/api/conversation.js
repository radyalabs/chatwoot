import endPoints from 'widget/api/endPoints';
import { API } from 'widget/helpers/axios';

const createConversationAPI = async content => {
  const urlData = endPoints.createConversation(content);
  return API.post(urlData.url, urlData.params);
};

const sendMessageAPI = async (conversationId, content, replyTo = null) => {
  const urlData = endPoints.sendMessage(content, replyTo);
  const payload = {
    ...urlData.params,
    conversation_id: conversationId, 
  };
  return API.post(urlData.url, payload);
};

const sendAttachmentAPI = async (conversationId, attachment, replyTo = null) => {
  const urlData = endPoints.sendAttachment(attachment, replyTo);
  urlData.params.append('conversation_id', conversationId);
  return API.post(urlData.url, urlData.params);
};

const getMessagesAPI = async ({ conversationId, before, after }) => {
  const urlData = endPoints.getConversation({ conversationId, before, after });
  const finalParams = {
    ...urlData.params,    
    conversation_id: conversationId
  };
  return API.get(urlData.url, { params: finalParams });
};

const getConversationsListAPI = async () => {
  return API.get(`/api/v1/widget/conversations${window.location.search}`);
};

const getConversationAPI = async () => {
  return API.get(`/api/v1/widget/conversations${window.location.search}`);
};
const toggleTyping = async ({ conversationId, typingStatus }) => {
  return API.post(
    `/api/v1/widget/conversations/toggle_typing${window.location.search}`,
    { 
      typing_status: typingStatus,
      conversation_id: conversationId
    }
  );
};
const setUserLastSeenAt = async ({ lastSeen }) => {
  return API.post(
    `/api/v1/widget/conversations/update_last_seen${window.location.search}`,
    { contact_last_seen_at: lastSeen }
  );
};
const sendEmailTranscript = async () => {
  return API.post(
    `/api/v1/widget/conversations/transcript${window.location.search}`
  );
};
const toggleStatus = async () => {
  return API.get(
    `/api/v1/widget/conversations/toggle_status${window.location.search}`
  );
};

const setCustomAttributes = async customAttributes => {
  return API.post(
    `/api/v1/widget/conversations/set_custom_attributes${window.location.search}`,
    {
      custom_attributes: customAttributes,
    }
  );
};

const deleteCustomAttribute = async customAttribute => {
  return API.post(
    `/api/v1/widget/conversations/destroy_custom_attributes${window.location.search}`,
    {
      custom_attribute: [customAttribute],
    }
  );
};

export {
  createConversationAPI,
  sendMessageAPI,
  getConversationAPI,
  getMessagesAPI,
  sendAttachmentAPI,
  toggleTyping,
  setUserLastSeenAt,
  sendEmailTranscript,
  toggleStatus,
  setCustomAttributes,
  deleteCustomAttribute,
  getConversationsListAPI,
};
