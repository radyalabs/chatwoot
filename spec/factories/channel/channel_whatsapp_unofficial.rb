FactoryBot.define do
  factory :channel_whatsapp_unofficial, class: 'Channel::WhatsappUnofficial' do
    phone_number { Faker::PhoneNumber.cell_phone_in_e164 }
    account
    status { 'connected' }
    provider { 'gowa' }
    device_id { "#{phone_number}@s.whatsapp.net" }
  end
end
