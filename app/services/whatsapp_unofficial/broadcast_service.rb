# frozen_string_literal: true

class WhatsappUnofficial::BroadcastService
  attr_reader :channel

  def initialize(channel)
    @channel = channel
  end

  def session_ready
    broadcast_status_event('session_ready', 'connected', true)
  end

  def session_mismatch(callback_phone, current_attempts, max_attempts)
    return if inbox.blank?

    broadcast_data = base_broadcast_data.merge(
      event: 'whatsapp_session_mismatch',
      type: 'session_mismatch',
      status: 'mismatch',
      connected: false,
      callback_phone: callback_phone,
      attempts: current_attempts,
      max_attempts: max_attempts,
      remaining_attempts: max_attempts - current_attempts
    )

    broadcast_to_all(broadcast_data)
    Rails.logger.info "Session mismatch event broadcasted for #{channel.phone_number}"
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast session mismatch: #{e.message}"
  end

  def session_failed(callback_phone, current_attempts)
    return if inbox.blank?

    broadcast_data = base_broadcast_data.merge(
      event: 'whatsapp_session_failed',
      type: 'session_failed',
      status: 'failed',
      connected: false,
      callback_phone: callback_phone,
      attempts: current_attempts,
      auto_deleted: true
    )

    broadcast_to_all(broadcast_data)
    Rails.logger.info "Session failed event broadcasted for #{channel.phone_number}"
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast session failed: #{e.message}"
  end

  def disconnect
    broadcast_status_event('auto_disconnect', 'disconnected', false)
  end

  def reconnect
    broadcast_status_event('auto_reconnect', 'connected', true)
  end

  private

  def inbox
    channel.inbox
  end

  def broadcast_status_event(event_type, status, connected)
    return if inbox.blank?

    broadcast_data = base_broadcast_data.merge(
      event: 'whatsapp_status_changed',
      type: event_type,
      status: status,
      connected: connected
    )

    Rails.logger.info "Broadcasting #{event_type} for #{channel.phone_number}"
    broadcast_to_all(broadcast_data)
    Rails.logger.info "#{event_type.titleize} event broadcasted successfully"
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast #{event_type} event: #{e.message}"
  end

  def broadcast_to_all(data)
    # Broadcast to inbox channel
    inbox_pubsub_token = "#{channel.account_id}_inbox_#{inbox.id}"
    ActionCable.server.broadcast(inbox_pubsub_token, data)

    # Broadcast to all account users
    channel.account.users.each do |user|
      ActionCable.server.broadcast(user.pubsub_token, data)
    end
  end

  def base_broadcast_data
    {
      phone_number: channel.phone_number,
      inbox_id: inbox.id,
      account_id: channel.account_id,
      timestamp: Time.current.iso8601
    }
  end
end
