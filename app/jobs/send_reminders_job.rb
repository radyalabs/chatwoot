class SendRemindersJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Rails.logger.info('[SendRemindersJob] Starting reminders processing')

    processed_count = 0
    error_count = 0

    ReminderConfig.includes(:ai_agent).where(enabled: true).find_each do |config|
      result = process_reminders_for_config(config)
      processed_count += result[:processed]
      error_count += result[:errors]
    end

    Rails.logger.info("[SendRemindersJob] Completed - processed: #{processed_count}, errors: #{error_count}")
  end

  private

  def process_reminders_for_config(config)
    result = { processed: 0, errors: 0 }

    return result unless config.ai_agent.present?

    reminders = Reminder.joins(:ai_agent)
                        .where(ai_agent_id: config.ai_agent_id)
                        .due_for_reminder(config.minutes_before_booking)

    reminders.find_each do |reminder|
      if send_reminder(reminder, config)
        result[:processed] += 1
      else
        result[:errors] += 1
      end
    end

    result
  end

  def send_reminder(reminder, config)
    Rails.logger.info("[SendRemindersJob] Processing reminder ##{reminder.id}")
    Reminders::SendReminderService.new(reminder, config).perform
  rescue StandardError => e
    Rails.logger.error("[SendRemindersJob] Failed to send reminder ##{reminder.id}: #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    false
  end
end
