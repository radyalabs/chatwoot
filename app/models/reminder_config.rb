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

  # Default templates per bot type
  DEFAULT_TEMPLATES = {
    'booking' => 'Halo {{nama_pelanggan}}! Ini adalah pengingat untuk jadwal {{nama_layanan}} di {{lokasi}} pada {{tanggal_booking}} jam {{waktu_booking}}. Terima kasih!',
    'lead_generation' => 'Halo {{nama_pelanggan}}! Ini adalah pengingat untuk konsultasi {{nama_layanan}} pada {{tanggal_konsultasi}} jam {{waktu_konsultasi}}. Terima kasih!'
  }.freeze

  DEFAULT_MESSAGE_TEMPLATE = DEFAULT_TEMPLATES['booking'].freeze

  # Placeholder mappings for each bot type
  # Each entry maps a placeholder to a lambda that extracts the value from a reminder
  PLACEHOLDER_MAPPINGS = {
    # Shared placeholders (available for all bot types)
    shared: {
      '{{nama_pelanggan}}' => ->(reminder, _) { reminder.customer_name.to_s },
      '{{nama_layanan}}' => ->(reminder, _) { reminder.service_name.to_s }
    },
    # Booking-specific placeholders
    booking: {
      '{{tanggal_booking}}' => ->(reminder, config) { config.send(:format_date, config.send(:local_scheduled_at, reminder)) },
      '{{waktu_booking}}' => ->(reminder, config) { config.send(:format_time, config.send(:local_scheduled_at, reminder)) },
      '{{lokasi}}' => ->(reminder, _) { reminder.service_location.to_s }
    },
    # LeadGen-specific placeholders
    lead_generation: {
      '{{tanggal_konsultasi}}' => ->(reminder, config) { config.send(:format_date, config.send(:local_scheduled_at, reminder)) },
      '{{waktu_konsultasi}}' => ->(reminder, config) { config.send(:format_time, config.send(:local_scheduled_at, reminder)) }
    }
  }.freeze

  def message_template_with_default
    message_template.presence || default_template_for_bot_type
  end

  def render_message(reminder)
    template = message_template_with_default
    placeholders = placeholders_for_bot_type

    placeholders.each do |placeholder, resolver|
      template = template.gsub(placeholder, resolver.call(reminder, self))
    end

    template
  end

  private

  def bot_type
    # Extract bot type from ai_agent's enabled_agents in display_flow_data
    # Returns the first enabled agent type, defaulting to 'booking'
    enabled_agents = ai_agent&.display_flow_data&.dig('enabled_agents')
    return 'booking' if enabled_agents.blank?

    # Prioritize specific bot types that have reminder support
    reminder_supported_types = %w[booking lead_generation]
    enabled_agents.find { |agent| reminder_supported_types.include?(agent) } || 'booking'
  end

  def default_template_for_bot_type
    DEFAULT_TEMPLATES[bot_type] || DEFAULT_MESSAGE_TEMPLATE
  end

  def placeholders_for_bot_type
    shared = PLACEHOLDER_MAPPINGS[:shared] || {}
    type_specific = PLACEHOLDER_MAPPINGS[bot_type.to_sym] || {}
    shared.merge(type_specific)
  end

  def local_scheduled_at(reminder)
    reminder.scheduled_at&.in_time_zone(APP_TIMEZONE)
  end

  def format_date(scheduled_at)
    return '' if scheduled_at.blank?

    scheduled_at.strftime('%d %B %Y')
  end

  def format_time(scheduled_at)
    return '' if scheduled_at.blank?

    scheduled_at.strftime('%H:%M')
  end
end  