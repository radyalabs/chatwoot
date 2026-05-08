# frozen_string_literal: true

class GroupChat::LogMessageService
  def initialize(channel:, params:)
    @channel = channel
    @params  = params
    @payload = params['payload'] || {}
    @event   = params['event']
  end

  def perform
    monitored = find_monitored_group
    return unless monitored

    log_event(monitored)
  end

  private

  def find_monitored_group
    chat_id = @payload['chat_id'].to_s
    chat_id = @params.dig('gowa', 'payload', 'chat_id').to_s if chat_id.exclude?('@')
    
    Rails.logger.info("[GroupChat DEBUG] chat_id=#{chat_id}")
    Rails.logger.info("[GroupChat DEBUG] inbox_id=#{@channel.inbox.id}")
    
    result = GroupMonitoredChat.active
                               .for_inbox(@channel.inbox.id)
                               .find_by(group_id: chat_id)
    
    Rails.logger.info("[GroupChat DEBUG] monitored=#{result.inspect}")
    result
  end

  def log_event(monitored)
    attrs = base_attrs(monitored)

    case @event
    when 'message'
      attrs.merge!(message_attrs)
    when 'message.reaction'
      attrs.merge!(reaction_attrs)
    end

    GroupChatLog.create!(attrs)
    Rails.logger.info("[GroupChat] Logged #{@event} from #{@payload['from']} in #{@payload['chat_id']}")
  rescue StandardError => e
    Rails.logger.error("[GroupChat] Failed to log event: #{e.message}")
  end

  def base_attrs(monitored)
    {
      account_id: @channel.inbox.account_id,
      group_monitored_chat: monitored,
      event_type: @event,
      message_id: @payload['id'].to_s,
      sender_jid: @payload['from'].to_s,
      sender_name: @payload['from_name'].to_s,
      sent_at: @payload['timestamp'],
      raw_payload: @payload
    }
  end

  def message_attrs
    {
      content: @payload['body'],
      replied_to_id: @payload['replied_to_id'],
      quoted_body: @payload['quoted_body']
    }
  end

  def reaction_attrs
    reaction = @payload['reaction'] || {}
    {
      reaction_emoji: reaction['emoji'] || @payload['emoji'],
      reaction_target_id: reaction['target_message_id'] || @payload['target_message_id']
    }
  end
end