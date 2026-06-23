FactoryBot.define do
  factory :broadcast_campaign do
    account { nil }
    inbox { nil }
    target_segment { "MyString" }
    message_body { "MyText" }
    spin_text_enabled { false }
    unsubscribe_link_enabled { false }
    status { 1 }
    scheduled_at { "2026-04-29 11:03:26" }
  end
end
