# frozen_string_literal: true

class WhatsappUnofficial::CallbackProcessor
  attr_reader :channel, :params

  def initialize(channel, params)
    @channel = channel
    @params = params
  end

  # Process callback response from webhook
  # @return [Hash] Processing result with type and action
  def perform
    Rails.logger.info "Processing callback for #{channel.phone_number}"

    event_type = Channel::WhatsappUnofficial.determine_event_type(params)
    Rails.logger.info "Event type determined: #{event_type}"

    case event_type
    when 'receipt'
      handle_receipt
    when 'message'
      handle_message
    when 'initial_scan'
      handle_initial_scan
    else
      handle_unknown(event_type)
    end
  end

  private

  def handle_receipt
    Rails.logger.info 'Receipt callback - updating message status only'
    { type: 'receipt', action: 'update_message_status' }
  end

  def handle_message
    Rails.logger.info 'Regular message callback - no phone validation needed'
    { type: 'regular_message', action: 'process_normally' }
  end

  def handle_initial_scan
    Rails.logger.info 'Initial scan callback detected - validating phone number'
    connected_phone = Channel::WhatsappUnofficial.extract_phone_from_from_field(params[:from])
    Rails.logger.info "Connected phone from callback: #{connected_phone}, Expected: #{channel.phone_number}"

    validation_result = WhatsappUnofficial::PhoneValidationService.new(channel, connected_phone).perform

    build_initial_scan_response(validation_result, connected_phone)
  end

  def handle_unknown(event_type)
    Rails.logger.info "Unknown callback type: #{event_type}"
    { type: 'unknown', action: 'process_normally' }
  end

  def build_initial_scan_response(validation_result, connected_phone)
    if validation_result[:success]
      build_validation_success_response(connected_phone)
    else
      build_validation_failure_response(validation_result)
    end
  end

  def build_validation_success_response(connected_phone)
    Rails.logger.info 'Phone validation SUCCESS'
    {
      type: 'initial_scan',
      action: 'validate_success',
      data: {
        session_id: params[:sessionID],
        phone_number: channel.phone_number,
        connected_phone: connected_phone,
        validation_status: 'validated'
      }
    }
  end

  def build_validation_failure_response(validation_result)
    Rails.logger.error 'Phone validation FAILED'
    action = validation_result[:auto_deleted] ? 'validate_failure_auto_deleted' : 'validate_failure'
    {
      type: 'initial_scan',
      action: action,
      data: validation_result.merge(session_id: params[:sessionID])
    }
  end
end
