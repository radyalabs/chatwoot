class SendScheduledRemindersJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ScheduledReminder.due.find_each do |reminder|
      ScheduledReminders::SendService.new(reminder).perform
    rescue StandardError => e
      Rails.logger.error("[SendScheduledRemindersJob] Failed reminder ##{reminder.id}: #{e.message}")
    end
  end
end
