import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { groupBy } from 'widget/helpers/utils';
import { groupConversationBySender } from './helpers';
import { formatUnixDate } from 'shared/helpers/DateHelper';

export const getters = {
  getCurrentMessages: (_state) => {
    const id = _state.selectedConversationId;
    if (!id) return [];
    return _state.conversations[id]?.messages || [];
  },
  getAllMessagesLoaded: _state => _state.uiFlags.allMessagesLoaded,
  getIsCreating: _state => _state.uiFlags.isCreating,
  getIsAgentTyping: _state => _state.uiFlags.isAgentTyping,
  getConversationMeta: state => ({
    disable_branding: state.meta?.disable_branding ?? false,
    userLastSeenAt: state.meta?.userLastSeenAt
  }),
  getConversation: _state => _state.conversations,
  getConversationSize: _state => Object.keys(_state.conversations).length,
  // Mengambil List Percakapan (Header chat history)
  getConversationsList: _state => {
    if (!_state.conversationsList) return [];
    return _state.conversationsList.slice(0, 4); // Ambil 4 paling akhir
  },
  // Mengambil ID percakapan yang sedang dibuka sekarang
  getSelectedConversationId: _state => _state.selectedConversationId,
  getEarliestMessage: (_state, getters) => {
    const messages = getters.getCurrentMessages;
    return messages.length ? messages[0] : {};
  },
  getLastMessage: (_state, getters) => {
    const messages = getters.getCurrentMessages;
    return messages.length ? messages[messages.length - 1] : {};
  },
  getGroupedConversation: (_state, getters) => {
    const messages = [...getters.getCurrentMessages];

    messages.sort((a, b) => a.created_at - b.created_at);

    const visible = messages.filter(m => {
      const hasContent = m.content && m.content !== '';
      const hasAttachment =
        m.attachments && m.attachments.length > 0;
      return hasContent || hasAttachment;
    });

    const groupedByDate = groupBy(
      visible,
      m => formatUnixDate(m.created_at)
    );

    return Object.keys(groupedByDate).map(date => ({
      date,
      messages: groupConversationBySender(groupedByDate[date]),
    }));
  },
  getIsFetchingList: _state => _state.uiFlags.isFetchingList,
  getMessageCount: (_state, getters) => {
    return getters.getCurrentMessages.length;
  },
  getUnreadMessageCount: (_state, getters) => {
    const { userLastSeenAt } = _state.meta;
    const messages = getters.getCurrentMessages;

    return messages.filter(msg => {
      const isOutgoing = msg.message_type === MESSAGE_TYPE.OUTGOING;
      const notSeen = userLastSeenAt
        ? msg.created_at * 1000 > userLastSeenAt * 1000
        : true;
      return notSeen && isOutgoing;
    }).length;
  },
  getUnreadTextMessages: (_state, getters) => {
    const messages = getters.getCurrentMessages;
    const unread = messages.filter(
      m => m.message_type === MESSAGE_TYPE.OUTGOING
    );
    return unread.slice(-3);
  },
};
