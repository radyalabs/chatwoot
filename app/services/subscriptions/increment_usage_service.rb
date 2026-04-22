class Subscriptions::IncrementUsageService
  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    usage = find_or_create_usage
    return unless usage

    if usage.exceeded_limits?
      log_mau_limit_reached(usage)
    else
      usage.increment_mau
    end
  end

  private

  def subscription
    @subscription ||= Subscription.find_by(account_id: @conversation.account_id, status: 'active')
  end

  def find_or_create_usage
    SubscriptionUsage.find_or_create_by(subscription_id: subscription.id).tap do |u|
      Rails.logger.warn("No subscription or usage found for account #{@conversation.account_id}") unless u
    end
  end

  def log_mau_limit_reached(usage)
    Rails.logger.warn("MAU limit reached for subscription #{usage.subscription_id}")
  end
end
