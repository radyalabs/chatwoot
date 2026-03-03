class Webhooks::FacebookEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(message)
    response = ::Integrations::Facebook::MessageParser.new(message)

    key = format(::Redis::Alfred::FACEBOOK_MESSAGE_MUTEX, sender_id: response.sender_id, recipient_id: response.recipient_id)
    with_lock(key) do
      process_message(response)
    end
  end

  def process_message(response)
    channel = find_channel(response)
    return unless channel
    return unless channel_available?(channel)

    ::Integrations::Facebook::MessageCreator.new(response).perform
  end

  def find_channel(response)
    if agent_message_via_echo?(response)
      Channel::FacebookPage.find_by(page_id: response.sender_id)
    else
      Channel::FacebookPage.find_by(page_id: response.recipient_id)
    end
  end

  def agent_message_via_echo?(response)
    response.echo? && !response.sent_from_chatwoot_app?
  end

  def channel_available?(channel)
    inbox = channel.inbox
    return true unless inbox.working_hours_enabled?

    inbox.availability_type != 'turn_off_channel'
  end
end
