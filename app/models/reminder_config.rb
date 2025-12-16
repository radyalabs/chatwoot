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

  APP_TIMEZONE = 'Asia/Jakarta'.freeze
  DEFAULT_MESSAGE_TEMPLATE = 'Halo {{nama_pelanggan}}! Ini adalah pengingat untuk jadwal {{nama_layanan}} di {{lokasi}} pada {{tanggal_booking}} jam {{waktu_booking}}. Terima kasih!'

  def message_template_with_default
    message_template.presence || DEFAULT_MESSAGE_TEMPLATE
  end

  def render_message(reminder)
    template = message_template_with_default
    local_scheduled_at = reminder.scheduled_at&.in_time_zone(APP_TIMEZONE)

    template
      .gsub('{{nama_pelanggan}}', reminder.customer_name.to_s)
      .gsub('{{nama_layanan}}', reminder.service_name.to_s)
      .gsub('{{lokasi}}', reminder.service_location.to_s)
      .gsub('{{tanggal_booking}}', format_date(local_scheduled_at))
      .gsub('{{waktu_booking}}', format_time(local_scheduled_at))
  end

  private

  def format_date(scheduled_at)
    return '' if scheduled_at.blank?

    scheduled_at.strftime('%d %B %Y')
  end

  def format_time(scheduled_at)
    return '' if scheduled_at.blank?

    scheduled_at.strftime('%H:%M')
  end  
end  