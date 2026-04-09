class Subscriptions::NotifyMauThresholdService
  THRESHOLDS = [80, 90, 100].freeze

  def perform
    Rails.logger.info('[NotifyMauThresholdService] Starting MAU threshold check')

    count = Subscription.active.count
    Rails.logger.info("[NotifyMauThresholdService] Found #{count} active subscription(s)")
    Subscription.active.includes(:subscription_usage).find_each do |subscription|
      process_subscription(subscription)
    rescue StandardError => e
      Rails.logger.error("[NotifyMauThresholdService] Error processing subscription #{subscription.id}: #{e.message}")
    end
  end

  private

  def process_subscription(subscription)
    usage = subscription.subscription_usage
    if usage.nil?
      Rails.logger.info("[NotifyMauThresholdService] Subscription #{subscription.id}: no usage record, skipping")
      return
    end

    total_limit = usage.total_max_mau
    if total_limit.zero?
      Rails.logger.info("[NotifyMauThresholdService] Subscription #{subscription.id}: total_max_mau is 0, skipping")
      return
    end

    effective_usage = usage.mau_count - usage.additional_mau_count
    percentage = (effective_usage.to_f / total_limit * 100).floor
    Rails.logger.info("[NotifyMauThresholdService] Subscription #{subscription.id}: #{effective_usage}/#{total_limit} = #{percentage}%")

    highest_crossed = THRESHOLDS.select { |t| percentage >= t }.max
    if highest_crossed.nil?
      Rails.logger.info("[NotifyMauThresholdService] Subscription #{subscription.id}: no threshold crossed")
      return
    end
    if highest_crossed <= usage.last_notify_mau_threshold
      Rails.logger.info("[NotifyMauThresholdService] Subscription #{subscription.id}: #{highest_crossed}% already notified (last: #{usage.last_notify_mau_threshold}%)")
      return
    end

    account = subscription.account
    administrators = account.administrators
    if administrators.empty?
      Rails.logger.info("[NotifyMauThresholdService] Subscription #{subscription.id}: no administrators found for account #{account.id}")
      return
    end

    Rails.logger.info("[NotifyMauThresholdService] Subscription #{subscription.id}: sending #{highest_crossed}% warning to #{administrators.count} admin(s)")
    administrators.each do |admin|
      SubscriptionNotifierMailer.mau_threshold_warning(
        admin.email,
        admin.display_name || admin.name,
        subscription.plan_name,
        subscription.account_id,
        effective_usage,
        total_limit,
        highest_crossed
      ).deliver_later
    end

    usage.update!(last_notify_mau_threshold: highest_crossed)

    Rails.logger.info(
      "[NotifyMauThresholdService] Sent #{highest_crossed}% MAU warning for subscription #{subscription.id}"
    )
  end
end
