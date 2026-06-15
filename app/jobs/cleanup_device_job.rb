class CleanupDeviceJob < ApplicationJob
  queue_as :low

  def perform(channel_id)
    channel = Channel::WhatsappUnofficial.find_by(id: channel_id)
    return unless channel

    begin
      channel.adapter.logout_session
      channel.adapter.delete_device
    rescue StandardError => e
      Rails.logger.warn "API Provider gagal dihapus: #{e.message}"
    end
    
    if !channel.phone_number.to_s.include?('_deleted_')
      new_phone_number = "#{channel.phone_number}_deleted_#{Time.current.to_i}"
      channel.update_columns(phone_number: new_phone_number, status: 'disconnected')
    end
  end
end