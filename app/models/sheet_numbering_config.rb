# == Schema Information
#
# Table name: sheet_numbering_configs
#
#  id                :bigint           not null, primary key
#  current_value     :integer          default(1), not null
#  format_pattern    :string           default("[NUMBER]/[MONTH]/[YEAR]"), not null
#  last_synced_at    :datetime
#  last_synced_value :integer
#  number_padding    :integer          default(3), not null
#  numbering_key     :string           default("default"), not null
#  prefix            :string
#  reset_interval    :string           default("never"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  ai_agent_id       :bigint           not null
#
# Indexes
#
#  idx_sheet_numbering_configs_unique_key        (account_id,ai_agent_id,numbering_key) UNIQUE
#  index_sheet_numbering_configs_on_account_id   (account_id)
#  index_sheet_numbering_configs_on_ai_agent_id  (ai_agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_agent_id => ai_agents.id)
#

class SheetNumberingConfig < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent

  VALID_RESET_INTERVALS = %w[never month year].freeze
  MONTH_VARIABLES = %w[[MONTH] [MONTH_ROMAN] [MONTH_SHORT] [MONTH_LONG]].freeze
  YEAR_VARIABLES = %w[[YEAR] [YEAR_SHORT]].freeze

  # Unique constraint now includes numbering_key to support multiple configs per ai_agent
  validates :ai_agent_id, uniqueness: { scope: [:account_id, :numbering_key] }
  validates :format_pattern, presence: true
  validates :current_value, numericality: { greater_than_or_equal_to: 1 }
  validates :number_padding, numericality: { greater_than_or_equal_to: 1 }
  validates :reset_interval, inclusion: { in: VALID_RESET_INTERVALS }
  validates :numbering_key, presence: true

  validate :format_pattern_must_contain_required_variables
  validate :current_value_must_not_decrease, on: :update

  private

  def format_pattern_must_contain_required_variables
    return if format_pattern.blank?

    unless format_pattern.include?('[NUMBER]')
      errors.add(:format_pattern, 'must include [NUMBER]')
    end
    unless MONTH_VARIABLES.any? { |v| format_pattern.include?(v) }
      errors.add(:format_pattern, 'must include a month variable ([MONTH], [MONTH_ROMAN], [MONTH_SHORT], or [MONTH_LONG])')
    end
    unless YEAR_VARIABLES.any? { |v| format_pattern.include?(v) }
      errors.add(:format_pattern, 'must include a year variable ([YEAR] or [YEAR_SHORT])')
    end
  end

  def current_value_must_not_decrease
    return unless current_value_changed?

    # No IDs ever generated — free to edit
    return if last_synced_value.nil?

    # New reset period — counter has reset, free to edit
    return if new_reset_period?

    # Must be greater than the highest actually-generated ID
    min_allowed = last_synced_value + 1
    return if current_value >= min_allowed

    errors.add(:current_value, "must be greater than the last generated value (#{last_synced_value})")
  end

  def new_reset_period?
    return true if last_synced_at.nil?

    case reset_interval
    when 'month'
      last_synced_at.beginning_of_month < Time.current.beginning_of_month
    when 'year'
      last_synced_at.beginning_of_year < Time.current.beginning_of_year
    else
      false
    end
  end
end
