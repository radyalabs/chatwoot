class SubscriptionExpirationJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Subscription.where(status: 'active').where('ends_at < ?', Time.current).find_each do |subscription|
      subscription.update!(status: 'expired')
      subscription.account.update!(subscription_status: 'expired')
    end
  end
end
