json.payload do
  json.array! @conversations do |conversation|
    json.id conversation.display_id
    json.inbox_id conversation.inbox_id
    json.status conversation.status
    last_message = conversation.messages.last
    json.last_message last_message&.content
    json.timestamp conversation.updated_at.to_i
    unread_count = 0
    
    if conversation.contact_last_seen_at
      unread_count = conversation.messages.where("created_at > ?", conversation.contact_last_seen_at).where.not(message_type: 1).count
    else
      unread_count = conversation.messages.where.not(message_type: 1).count
    end

    json.unread_count unread_count
  end
end
json.website_channel_config do
  current_account = @contact_inbox.inbox.account
  tx = current_account.transactions.where(status: ['paid', 'success', 'completed', 'Dibayar']).order(expiry_date: :desc).first
  is_premium = ['Pertamax', 'Pertamax Turbo', 'Custom'].include?(tx&.package_name)
  
  json.disable_branding is_premium
end