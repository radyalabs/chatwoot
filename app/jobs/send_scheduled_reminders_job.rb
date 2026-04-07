class SendScheduledRemindersJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Use UPDATE ... RETURNING with a processing guard to prevent double-sends
    # when overlapping job runs pick up the same due reminders.
    reminder_ids = ScheduledReminder.due.pluck(:id)
    return if reminder_ids.empty?

    reminder_ids.each do |reminder_id|
      ScheduledReminder.transaction do
        # Row-level lock: skip if another worker already picked it up
        reminder = ScheduledReminder.lock('FOR UPDATE SKIP LOCKED').find_by(id: reminder_id)
        next unless reminder
        next unless reminder.next_occurrence_at && reminder.next_occurrence_at <= Time.current

        ScheduledReminders::SendService.new(reminder).perform
      end
    rescue StandardError => e
      Rails.logger.error("[SendScheduledRemindersJob] Failed reminder ##{reminder_id}: #{e.message}")
    end
  end
end
