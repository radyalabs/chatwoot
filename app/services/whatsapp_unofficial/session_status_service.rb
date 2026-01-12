# frozen_string_literal: true

class WhatsappUnofficial::SessionStatusService
  attr_reader :channel

  def initialize(channel)
    @channel = channel
  end

  # Check real-time session status from provider API
  # Handles state transitions and broadcasts events
  # @return [Hash] Response with connection status
  def perform
    Rails.logger.info "Checking real-time status for #{channel.phone_number} from #{channel.effective_provider} API"

    return not_logged_in_response unless channel.provider_configured?

    check_status_with_transitions
  rescue StandardError => e
    handle_error(e)
  end

  private

  def check_status_with_transitions
    previous_status = channel.read_session_status_from_cache
    result = channel.adapter.get_session_status
    connected = result[:connected]

    handle_state_transition(connected, previous_status)

    build_response(connected)
  end

  def handle_state_transition(connected, previous_status)
    if connected && previous_status != 'validated'
      handle_connected(previous_status)
    elsif !connected && previous_status == 'validated'
      handle_disconnected
    end
  end

  def handle_connected(_previous_status)
    Rails.logger.info "Session connected for #{channel.phone_number}, updating cache to 'validated'"
    channel.write_session_status_to_cache('validated')
    channel.clear_mismatch_attempts
    channel.clear_rescan_attempts
    broadcast_service.session_ready
  end

  def handle_disconnected
    Rails.logger.info "Session disconnected for #{channel.phone_number}"
    handle_auto_disconnect
    channel.write_session_status_to_cache('disconnected')
  end

  def handle_auto_disconnect
    Rails.logger.warn "Auto-detected disconnect for #{channel.phone_number}"
    channel.clear_mismatch_attempts
    broadcast_service.disconnect
  end

  def handle_error(error)
    Rails.logger.error "Failed to get real-time status for #{channel.phone_number}: #{error.message}"

    previous_status = channel.read_session_status_from_cache
    if previous_status == 'validated'
      Rails.logger.warn "API failed, assuming #{channel.phone_number} is disconnected"
      handle_auto_disconnect
      channel.write_session_status_to_cache('disconnected')
    end

    not_logged_in_response
  end

  def build_response(connected)
    {
      'data' => {
        'connected' => connected,
        'status' => connected ? 'logged_in' : 'not_logged_in'
      }
    }
  end

  def not_logged_in_response
    { 'data' => { 'connected' => false, 'status' => 'not_logged_in' } }
  end

  def broadcast_service
    @broadcast_service ||= WhatsappUnofficial::BroadcastService.new(channel)
  end
end
