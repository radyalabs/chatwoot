class Subscriptions::NotifyAiResponseThresholdService
  THRESHOLDS = [75, 90, 100].freeze

  def perform
    Rails.logger.info('[NotifyAiResponseThresholdService] Starting AI response threshold check')

    Subscription.active.includes(:subscription_usage).find_each do |subscription|
      process_subscription(subscription)
    rescue StandardError => e
      Rails.logger.error("[NotifyAiResponseThresholdService] Error processing subscription #{subscription.id}: #{e.message}")
    end
  end

  private

  def process_subscription(subscription)
    usage = subscription.subscription_usage
    if usage.nil?
      Rails.logger.info("[NotifyAiResponseThresholdService] Subscription #{subscription.id}: no usage record, skipping")
      return
    end

    total_limit = usage.total_max_ai_responses
    if total_limit.zero?
      Rails.logger.info("[NotifyAiResponseThresholdService] Subscription #{subscription.id}: total_max_ai_responses is 0, skipping")
      return
    end

    effective_usage = usage.ai_responses_count - usage.additional_ai_response_count
    percentage = (effective_usage.to_f / total_limit * 100).floor
    Rails.logger.info("[NotifyAiResponseThresholdService] Subscription #{subscription.id}: #{effective_usage}/#{total_limit} = #{percentage}%")

    highest_crossed = THRESHOLDS.select { |t| percentage >= t }.max
    if highest_crossed.nil?
      Rails.logger.info("[NotifyAiResponseThresholdService] Subscription #{subscription.id}: no threshold crossed")
      return
    end
    if highest_crossed <= usage.last_notify_ai_response_threshold
      Rails.logger.info("[NotifyAiResponseThresholdService] Subscription #{subscription.id}: #{highest_crossed}% already notified")
      return
    end

    account = subscription.account
    administrators = account.administrators
    if administrators.empty?
      Rails.logger.info("[NotifyAiResponseThresholdService] Subscription #{subscription.id}: no administrators for account #{account.id}")
      return
    end

    Rails.logger.info("[NotifyAiResponseThresholdService] Subscription #{subscription.id}: sending #{highest_crossed}% warning to #{administrators.count} admin(s)")
    administrators.each do |admin|
      SubscriptionNotifierMailer.ai_response_threshold_warning(
        admin.email,
        admin.display_name || admin.name,
        subscription.plan_name,
        subscription.account_id,
        effective_usage,
        total_limit,
        highest_crossed
      ).deliver_later
    end

    usage.update!(last_notify_ai_response_threshold: highest_crossed)

    Rails.logger.info(
      "[NotifyAiResponseThresholdService] Sent #{highest_crossed}% AI response warning for subscription #{subscription.id}"
    )
  end
end
