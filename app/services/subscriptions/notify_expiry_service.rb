class Subscriptions::NotifyExpiryService
  def perform
    Rails.logger.info('[NotifyExpiryService] Starting expiry notification check')

    Timeout.timeout(1.hour.to_i) do
      loop do
        subscriptions = fetch_upcoming_expiry_subscriptions
        break if subscriptions.blank?

        subscriptions.each do |account|
          process_expiry_notification(account)
        end
      end
    end
  rescue Timeout::Error
    Rails.logger.error('[NotifyExpiryService] Operation timed out')
  end

  private

  def fetch_upcoming_expiry_subscriptions
    Account.joins('LEFT JOIN "subscriptions" ON subscriptions.id = "accounts"."active_subscription_id"')
           .joins('LEFT JOIN "account_users" ON "account_users"."account_id" = "accounts"."id"')
           .joins('LEFT JOIN "users" ON "users"."id" = "account_users"."user_id"')
           .where(subscriptions: { last_notify_expiry: nil })
           .where('DATE(subscriptions.ends_at) = DATE(?)', 7.days.from_now)
           .where('"account_users"."role" = ?', AccountUser.roles[:administrator])
           .where.not(active_subscription_id: nil)
           .limit(10)
  end

  def process_expiry_notification(account)
    subscription = Subscription.find_by(id: account.active_subscription_id)
    return if subscription.nil?

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
