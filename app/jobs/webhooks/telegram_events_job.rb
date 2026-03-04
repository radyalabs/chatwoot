class Webhooks::TelegramEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    return unless params[:bot_token]

    Rails.logger.info "Processing Telegram event: #{params.inspect}"

    channel = Channel::Telegram.find_by(bot_token: params[:bot_token])
    return unless channel
    return unless channel_available?(channel)

    process_event_params(channel, params)
  end

  private

  def process_event_params(channel, params)
    return unless params[:telegram]

    if params.dig(:telegram, :edited_message).present?
      Telegram::UpdateMessageService.new(inbox: channel.inbox, params: params['telegram'].with_indifferent_access).perform
    else
      Telegram::IncomingMessageService.new(inbox: channel.inbox, params: params['telegram'].with_indifferent_access).perform
    end
  end

  def channel_available?(channel)
    inbox = channel.inbox
    return true unless inbox.working_hours_enabled?

    inbox.availability_type != 'turn_off_channel'
  end
end
