# frozen_string_literal: true

class WhatsappUnofficial::CreateWhatsappUnofficialInboxService
  def initialize(account_id:, phone_number:, inbox_name:, provider: nil, provider_config: {})
    @account_id = account_id
    @phone_number = phone_number
    @inbox_name = inbox_name
    @provider = provider || WhatsappUnofficial::AdapterFactory.default_provider
    @provider_config = provider_config
  end

  def perform
    @channel = create_channel
    inbox = create_inbox

    Inbox.transaction do
      inbox.save!(validate: false)
    end

    # Setup webhook URL and device using the adapter
    setup_webhook_and_device

    { inbox: inbox, webhook_url: @channel.reload.webhook_url, provider: @channel.effective_provider }
  rescue StandardError => e
    Rails.logger.error "Failed to create WhatsApp unofficial inbox: #{e.message}"
    raise e
  end

  private

  def create_channel
    Channel::WhatsappUnofficial.create!(
      account_id: @account_id,
      phone_number: @phone_number,
      provider: @provider,
      provider_config: @provider_config
    )
  end

  def create_inbox
    Inbox.create!(
      account_id: @account_id,
      name: @inbox_name,
      channel: @channel,
      channel_type: 'Channel::WhatsappUnofficial'
    )
  end

  def setup_webhook_and_device
    # Set webhook URL via adapter (provider-aware)
    @channel.set_webhook_url
    Rails.logger.info "Webhook URL setup completed for phone #{@channel.phone_number} (provider: #{@channel.effective_provider})"

    # Try to setup device synchronously with timeout
    setup_device_sync_with_timeout
  end

  def setup_device_sync_with_timeout
    # Try sync setup first with 10 second timeout
    Timeout.timeout(30) do
      @channel.create_device_with_retry(max_retries: 1)
      Rails.logger.info "Device setup completed synchronously for phone #{@channel.phone_number}"
    end
  rescue Timeout::Error
    Rails.logger.warn "Device setup timeout for phone #{@channel.phone_number}, falling back to background job"
    SetupWhatsappUnofficialDeviceJob.perform_later(@channel.id)
  rescue StandardError => e
    Rails.logger.error "Sync device setup failed for phone #{@channel.phone_number}: #{e.message}"
    SetupWhatsappUnofficialDeviceJob.perform_later(@channel.id)
  end
end
