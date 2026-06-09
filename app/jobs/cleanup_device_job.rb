class CleanupDeviceJob < ApplicationJob
  queue_as :low

  def perform(channel_id)
    begin
      waha_service = Waha::WahaService.instance
      waha_service.delete_device(device_id: channel_id)
    rescue StandardError => e
      Rails.logger.warn "API Gowa gagal (mungkin device sudah terhapus): #{e.message}"
    end

    channel = Channel::WhatsappUnofficial.find_by(id: channel_id)
    
    if channel && !channel.phone_number.to_s.include?('_deleted_')
      new_phone_number = "#{channel.phone_number}_deleted_#{Time.current.to_i}"
      channel.update_columns(phone_number: new_phone_number, status: 'disconnected')
      Rails.logger.info "Nomor #{channel.phone_number} berhasil dibebaskan di database."
    end
  end
end