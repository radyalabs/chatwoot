require 'rails_helper'

RSpec.describe SubscriptionExpirationJob, type: :job do
  let(:account) { create(:account) }

  let!(:expired_subscription) do
    Subscription.create!(
      account: account,
      plan_name: 'Free Trial',
      starts_at: 35.days.ago,
      ends_at: 5.days.ago,
      status: 'active',
      payment_status: 'paid',
      price: 0,
      billing_cycle: 'monthly'
    )
  end

  let(:active_account) { create(:account) }
  let!(:active_subscription) do
    Subscription.create!(
      account: active_account,
      plan_name: 'Pertalite',
      starts_at: 10.days.ago,
      ends_at: 20.days.from_now,
      status: 'active',
      payment_status: 'paid',
      price: 1_600_000,
      billing_cycle: 'quarterly'
    )
  end

  before do
    account.update!(active_subscription_id: expired_subscription.id, subscription_status: 'active')
    active_account.update!(active_subscription_id: active_subscription.id, subscription_status: 'active')
  end

  it 'marks expired subscriptions as expired' do
    described_class.perform_now
    expired_subscription.reload
    expect(expired_subscription.status).to eq('expired')
  end

  it 'updates account subscription_status to expired' do
    described_class.perform_now
    account.reload
    expect(account.subscription_status).to eq('expired')
  end

  it 'does not affect active subscriptions' do
    described_class.perform_now
    active_subscription.reload
    expect(active_subscription.status).to eq('active')
  end

  it 'does not affect active account subscription_status' do
    described_class.perform_now
    active_account.reload
    expect(active_account.subscription_status).to eq('active')
  end
end
