# == Schema Information
#
# Table name: reminder_configs
#
#  id                     :bigint           not null, primary key
#  enabled                :boolean          default(FALSE), not null
#  message_template       :text
#  minutes_before_booking :integer          default(60), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  ai_agent_id            :bigint           not null
#
# Indexes
#
#  index_reminder_configs_on_account_id                  (account_id)
#  index_reminder_configs_on_account_id_and_ai_agent_id  (account_id,ai_agent_id) UNIQUE
#  index_reminder_configs_on_ai_agent_id                 (ai_agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_agent_id => ai_agents.id)
#

class ReminderConfig < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent

  validates :ai_agent_id, uniqueness: { scope: :account_id }
  validates :minutes_before_booking, numericality: { greater_than: 0 }

  DEFAULT_MESSAGE_TEMPLATE = 'Halo {{customer_name}}! Ini pengingat untuk jadwal Anda pada {{scheduled_at}}. Terima kasih!'

  def message_template_with_default
    message_template.presence || DEFAULT_MESSAGE_TEMPLATE
  end

  def render_message(reminder)
    template = message_template_with_default
    template
      .gsub('{{scheduled_at}}', format_scheduled_at(reminder.scheduled_at))
      .gsub('{{customer_name}}', reminder.customer_name.to_s)
      .gsub('{{contact}}', reminder.contact.to_s)
      .gsub('{{service_type}}', reminder.service_type.to_s)
      .gsub('{{service_name}}', reminder.service_name.to_s)
      .gsub('{{service_location}}', reminder.service_location.to_s)
  end

  private

  def format_scheduled_at(scheduled_at)
    return '' if scheduled_at.blank?

    scheduled_at.strftime('%d %B %Y %H:%M')
  end
end
