class Webhooks::SmsEventsJob < ApplicationJob
  queue_as :default

  SUPPORTED_EVENTS = %w[message-received message-delivered message-failed].freeze

  def perform(params = {})
    return unless SUPPORTED_EVENTS.include?(params[:type])

    channel = Channel::Sms.find_by(phone_number: params[:to])
    return unless channel

    process_event_params(channel, params)
  end

  private

  def process_event_params(channel, params)
    if delivery_event?(params)
      Sms::DeliveryStatusService.new(channel: channel, params: params[:message].with_indifferent_access).perform
    else
      return unless channel_available?(channel)

      Sms::IncomingMessageService.new(inbox: channel.inbox, params: params[:message].with_indifferent_access).perform
    end
  end

  def delivery_event?(params)
    params[:type] == 'message-delivered' || params[:type] == 'message-failed'
  end

  def channel_available?(channel)
    inbox = channel.inbox
    return true unless inbox.working_hours_enabled?

    inbox.availability_type != 'turn_off_channel'
  end
end
