# == Schema Information
#
# Table name: scheduled_reminders
#
#  id                    :bigint           not null, primary key
#  description           :text
#  enabled               :boolean          default(TRUE), not null
#  ends_after_count      :integer
#  ends_at               :datetime
#  last_sent_at          :datetime
#  message_template      :text             not null
#  message_type          :string           default("personal"), not null
#  next_occurrence_at    :datetime
#  occurrence_count      :integer          default(0)
#  receiver_address      :string           not null
#  receiver_channel_type :string           not null
#  receiver_name         :string
#  recurrence_rule       :jsonb
#  scheduled_at          :datetime         not null
#  timezone              :string           default("UTC"), not null
#  title                 :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  ai_agent_id           :bigint           not null
#  inbox_id              :bigint           not null
#
# Indexes
#
#  idx_scheduled_reminders_business_key                     (account_id,ai_agent_id,inbox_id,receiver_address,title) UNIQUE
#  idx_scheduled_reminders_due                              (next_occurrence_at,enabled)
#  index_scheduled_reminders_on_account_id                  (account_id)
#  index_scheduled_reminders_on_account_id_and_ai_agent_id  (account_id,ai_agent_id)
#  index_scheduled_reminders_on_ai_agent_id                 (ai_agent_id)
#  index_scheduled_reminders_on_inbox_id                    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (ai_agent_id => ai_agents.id) ON DELETE => cascade
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#
class ScheduledReminder < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent
  belongs_to :inbox

  SUPPORTED_CHANNEL_TYPES = %w[whatsapp_unofficial whatsapp telegram instagram].freeze
  SUPPORTED_MESSAGE_TYPES = %w[personal group].freeze
  MAX_PER_AGENT = 50

  validates :title, :receiver_address, :message_template, :scheduled_at, presence: true
  validates :title, uniqueness: { scope: %i[account_id ai_agent_id inbox_id receiver_address],
                                  message: 'already exists for this receiver' }
  validates :message_type, presence: true, inclusion: { in: SUPPORTED_MESSAGE_TYPES }
  validates :receiver_channel_type, presence: true, inclusion: { in: SUPPORTED_CHANNEL_TYPES }
  validates :timezone, presence: true
  validate :validate_reminder_limit, on: :create

  before_validation :normalize_recurrence_rule

  scope :enabled, -> { where(enabled: true) }
  scope :due, -> { enabled.where.not(next_occurrence_at: nil).where('next_occurrence_at <= ?', Time.current) }

  before_save :compute_and_set_next_occurrence, if: :schedule_changed?

  def advance_occurrence!
    update!(
      occurrence_count: occurrence_count + 1,
      last_sent_at: Time.current,
      next_occurrence_at: ScheduledReminders::OccurrenceCalculator.new(self).next_after_current
    )
  end

  def recurring?
    recurrence_rule.present?
  end

  def recurrence_summary
    return nil unless recurring?

    ScheduledReminders::OccurrenceCalculator.new(self).human_readable_summary
  end

  private

  def schedule_changed?
    scheduled_at_changed? || recurrence_rule_changed? || ends_at_changed? ||
      ends_after_count_changed? || timezone_changed? || enabled_changed?
  end

  def compute_and_set_next_occurrence
    if enabled?
      self.next_occurrence_at = ScheduledReminders::OccurrenceCalculator.new(self).next_occurrence
    else
      self.next_occurrence_at = nil
    end
  end

  def normalize_recurrence_rule
    return if recurrence_rule.blank? || scheduled_at.blank?

    rule = recurrence_rule.with_indifferent_access
    local_scheduled = scheduled_at.in_time_zone(timezone || 'UTC')

    if rule['frequency'] == 'monthly' && rule['day_of_month'].blank? && rule['week_of_month'].blank?
      rule['day_of_month'] = local_scheduled.day
      self.recurrence_rule = rule
    elsif rule['frequency'] == 'weekly' && rule['days_of_week'].blank?
      rule['days_of_week'] = [local_scheduled.wday]
      self.recurrence_rule = rule
    end
  end

  def validate_reminder_limit
    return unless ai_agent

    count = ai_agent.scheduled_reminders.count
    errors.add(:base, "Maximum #{MAX_PER_AGENT} reminders per agent") if count >= MAX_PER_AGENT
  end
end
