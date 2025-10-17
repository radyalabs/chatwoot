# == Schema Information
#
# Table name: operational_hours
#
#  id           :bigint           not null, primary key
#  close_allday :boolean          default(FALSE)
#  close_hour   :integer
#  close_minute :integer
#  day_of_week  :integer          not null
#  open_allday  :boolean          default(FALSE)
#  open_hour    :integer
#  open_minute  :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  agent_bot_id :bigint           not null
#
# Indexes
#
#  index_operational_hours_on_agent_bot_id                  (agent_bot_id)
#  index_operational_hours_on_day_of_week_and_agent_bot_id  (day_of_week,agent_bot_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agent_bot_id => agent_bots.id)
#
class OperationalHour < ApplicationRecord
  belongs_to :agent_bot

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :day_of_week, uniqueness: { scope: :agent_bot_id, message: "should be unique for this agent bot", on: :create }

  validate :open_and_close_allday_cannot_both_be_true

  with_options unless: :open_allday? do
    validates :open_hour, presence: true, inclusion: { in: 0..23 }
    validates :open_minute, presence: true, inclusion: { in: 0..59 }
  end

  with_options unless: :close_allday? do
    validates :close_hour, presence: true, inclusion: { in: 0..23 }
    validates :close_minute, presence: true, inclusion: { in: 0..59 }
  end

  def is_open?(time = Time.current)
    return false unless time.wday == day_of_week

    return true if open_allday?
    return false if close_allday?

    open_time = Time.new(time.year, time.month, time.day, open_hour, open_minute)
    close_time = Time.new(time.year, time.month, time.day, close_hour, close_minute)

    open_time <= time && time <= close_time
  end

  private

  def open_and_close_allday_cannot_both_be_true
    if open_allday? && close_allday?
      errors.add(:base, "Open all day and close all day cannot both be true")
    end
  end
end
