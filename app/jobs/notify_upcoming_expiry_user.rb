class NotifyUpcomingExpiryUser < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info('[NotifyUpcomingExpiryUser] Starting subscription notification job')

    Subscriptions::NotifyExpiryService.new.perform
    Subscriptions::NotifyMauThresholdService.new.perform
    Subscriptions::NotifyAiResponseThresholdService.new.perform

    Rails.logger.info('[NotifyUpcomingExpiryUser] Finished subscription notification job')
  end
end
