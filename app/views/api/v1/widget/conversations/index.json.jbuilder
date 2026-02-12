json.payload do
  json.array! @conversations do |conversation|
    json.id conversation.display_id
    json.inbox_id conversation.inbox_id
    json.status conversation.status
    last_message = conversation.messages.last
    json.last_message last_message&.content
    json.timestamp conversation.updated_at.to_i
    # json.unread_count conversation.unread_messages_count
  end
end
json.website_channel_config do
  current_account = @contact_inbox.inbox.account
  tx = current_account.transactions.where(status: ['paid', 'success', 'completed', 'Dibayar']).order(expiry_date: :desc).first
  is_premium = ['Pertamax', 'Pertamax Turbo', 'Custom'].include?(tx&.package_name)
  
  json.disable_branding is_premium
end