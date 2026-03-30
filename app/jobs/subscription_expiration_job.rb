class SubscriptionExpirationJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    expired_count = 0
    error_count = 0

    Subscription.where(status: 'active').where('ends_at < ?', Time.current).find_each do |subscription|
      expire_subscription(subscription)
      expired_count += 1
    rescue StandardError => e
      error_count += 1
      Rails.logger.error(
        "[SubscriptionExpirationJob] Failed to expire subscription ##{subscription.id} " \
        "(account ##{subscription.account_id}): #{e.class} - #{e.message}"
      )
      Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    end

    Rails.logger.info("[SubscriptionExpirationJob] Completed: #{expired_count} expired, #{error_count} errors")
  end

  private

  def expire_subscription(subscription)
    ActiveRecord::Base.transaction do
      subscription.update!(status: 'expired')
      subscription.account.update!(
        subscription_status: 'expired',
        active_subscription_id: nil
      )
    end
  end
end
