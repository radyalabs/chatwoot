class Subscriptions::NotifyExpiryService
  def perform
    Rails.logger.info('[NotifyExpiryService] Starting expiry notification check')

    Subscription.where(last_notify_expiry: nil)
                .where('DATE(ends_at) = DATE(?)', 7.days.from_now)
                .joins(:account)
                .where.not(accounts: { active_subscription_id: nil })
                .where('subscriptions.id = accounts.active_subscription_id')
                .find_each do |subscription|
      process_expiry_notification(subscription)
    rescue StandardError => e
      Rails.logger.error("[NotifyExpiryService] Error processing subscription #{subscription.id}: #{e.message}")
    end
  end

  private

  def process_expiry_notification(subscription)
    account = subscription.account
    administrators = account.administrators

    if administrators.any?
      administrators.each do |admin|
        SubscriptionNotifierMailer.upcoming_expiry(
          admin.email,
          subscription.account_id,
          Time.now.utc.strftime('%d %b %Y'),
          admin.display_name || admin.name,
          subscription.plan_name,
          subscription.ends_at.strftime('%d %b %Y')
        ).deliver_later
      end
    end

    subscription.update!(last_notify_expiry: Time.now.utc)
  end
end
