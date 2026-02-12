import BaseActionCableConnector from '../../shared/helpers/BaseActionCableConnector';
import { playNewMessageNotificationInWidget } from 'widget/helpers/WidgetAudioNotificationHelper';
import { ON_AGENT_MESSAGE_RECEIVED } from '../constants/widgetBusEvents';
import { IFrameHelper } from 'widget/helpers/utils';
import { shouldTriggerMessageUpdateEvent } from './IframeEventHelper';
import { CHATWOOT_ON_MESSAGE } from '../constants/sdkEvents';
import { emitter } from '../../shared/helpers/mitt';

const isMessageInActiveConversation = (getters, message) => {
  const { conversation_id: incomingConvId } = message;
  
  // Ambil ID dari UI state (yang sedang dilihat user)
  const uiConversationId = getters['conversation/getSelectedConversationId'];
  
  // Ambil ID dari Attributes (backup)
  const attrConversationId = getters['conversationAttributes/getConversationParams']?.id;

  // Cek apakah pesan cocok dengan SALAH SATU dari ID tersebut
  const isActive = 
    Number(incomingConvId) === Number(uiConversationId) || 
    Number(incomingConvId) === Number(attrConversationId);

  return isActive;
};

class ActionCableConnector extends BaseActionCableConnector {
  constructor(app, pubsubToken) {
    super(app, pubsubToken);
    this.events = {
      'message.created': this.onMessageCreated,
      'message.updated': this.onMessageUpdated,
      'conversation.typing_on': this.onTypingOn,
      'conversation.typing_off': this.onTypingOff,
      'conversation.status_changed': this.onStatusChange,
      'conversation.created': this.onConversationCreated,
      'presence.update': this.onPresenceUpdate,
      'contact.merged': this.onContactMerge,
    };
    console.log('%c[DEBUG AC] ActionCableConnector INIT', 'color: green');

    this.onReceived = (event, data) => {
      console.log('%c[DEBUG AC] RAW EVENT RECEIVED:', 'color: cyan', event, data);
    };
  }

  onDisconnected = () => {
    this.setLastMessageId();
  };

  onReconnect = () => {
    this.syncLatestMessages();
  };

  setLastMessageId = () => {
    this.app.$store.dispatch('conversation/setLastMessageId');
  };

  syncLatestMessages = () => {
    this.app.$store.dispatch('conversation/syncLatestMessages');
  };

  onStatusChange = data => {
    if (data.status === 'resolved') {
      this.app.$store.dispatch('campaign/resetCampaign');
    }
    this.app.$store.dispatch('conversationAttributes/update', data);
  };

  onMessageCreated = async data => {
    console.log('%c[DEBUG AC] onMessageCreated CALLED:', 'color: orange', data);
    const getters = this.app.$store.getters;
    let currentConvId = getters['conversationAttributes/getConversationParams'].id;

    if (!currentConvId && data.conversation_id) {
      currentConvId = data.conversation_id;
    }

    if (!isMessageInActiveConversation(getters, data)) {
      return;
    }

    console.log(
      '%c[DISPATCH] addOrUpdateMessage CALLED:',
      'color: #09f',
      data
    );
    this.app.$store
      .dispatch('conversation/addOrUpdateMessage', data)
      .then(() => emitter.emit(ON_AGENT_MESSAGE_RECEIVED));

    IFrameHelper.sendMessage({
      event: 'onEvent',
      eventIdentifier: CHATWOOT_ON_MESSAGE,
      data,
    });

    if (data.sender_type === 'User') {
      playNewMessageNotificationInWidget();
    }
  };

  onMessageUpdated = data => {
    console.log('%c[DEBUG AC] onMessageUpdated CALLED:', 'color: orange', data);
    const getters = this.app.$store.getters;

    if (!isMessageInActiveConversation(getters, data)) {
      return;
    }

    if (shouldTriggerMessageUpdateEvent(data)) {
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_MESSAGE,
        data,
      });
    }

    console.log('[AC] REALTIME NEW MESSAGE', data);
    const convId = data.conversation_id;
    this.app.$store.commit('conversation/updateMessage', {
      id: data.id,
      ...data,
    });
  };

  onConversationCreated = () => {
    this.app.$store.dispatch('conversationAttributes/getAttributes');
  };

  onPresenceUpdate = data => {
    this.app.$store.dispatch('agent/updatePresence', data.users);
  };

  // eslint-disable-next-line class-methods-use-this
  onContactMerge = data => {
    const { pubsub_token: pubsubToken } = data;
    ActionCableConnector.refreshConnector(pubsubToken);
  };

  onTypingOn = data => {
    const activeConversationId =
      this.app.$store.getters['conversationAttributes/getConversationParams']
        .id;
    const isUserTypingOnAnotherConversation =
      data.conversation && data.conversation.id !== activeConversationId;

    if (isUserTypingOnAnotherConversation || data.is_private) {
      return;
    }
    this.clearTimer();
    this.app.$store.dispatch('conversation/toggleAgentTyping', {
      status: 'on',
    });
    this.initTimer();
  };

  onTypingOff = () => {
    this.clearTimer();
    this.app.$store.dispatch('conversation/toggleAgentTyping', {
      status: 'off',
    });
  };

  clearTimer = () => {
    if (this.CancelTyping) {
      clearTimeout(this.CancelTyping);
      this.CancelTyping = null;
    }
  };

  initTimer = () => {
    // Turn off typing automatically after 30 seconds
    this.CancelTyping = setTimeout(() => {
      this.onTypingOff();
    }, 30000);
  };
}

export default ActionCableConnector;
