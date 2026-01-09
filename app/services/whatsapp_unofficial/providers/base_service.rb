class WhatsappUnofficial::Providers::BaseService
  pattr_initialize [:whatsapp_channel!]

  def send_message(_message)
    raise 'Overwrite this method in child class'
  end
end
