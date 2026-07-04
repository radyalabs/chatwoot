# == Schema Information
#
# Table name: otps
#
#  id          :bigint           not null, primary key
#  code        :string(6)        not null
#  expires_at  :datetime         not null
#  ip_address  :string
#  purpose     :string           default("email_verification"), not null
#  user_agent  :string
#  verified    :boolean          default(FALSE), not null
#  verified_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_otps_on_code_and_expires_at         (code,expires_at)
#  index_otps_on_expires_at                  (expires_at)
#  index_otps_on_user_id                     (user_id)
#  index_otps_on_user_id_and_purpose_unique  (user_id,purpose) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

class Otp < ApplicationRecord
  belongs_to :user

  validates :code, presence: true, length: { is: 6 }, format: { with: /\A\d{6}\z/ }
  validates :purpose, presence: true, inclusion: { in: %w[email_verification password_reset login] }
  validates :expires_at, presence: true

  scope :active, -> { where(verified: false) }
  scope :verified, -> { where(verified: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid, -> { active.where('expires_at > ?', Time.current) }
  scope :for_purpose, ->(purpose) { where(purpose: purpose) }

  # Removed before_create callbacks - now handled manually in generate_for_user

  def expired?
    expires_at < Time.current
  end

  def valid_for_verification?
    !verified? && !expired?
  end

  def verify!
    Rails.logger.info "Attempting to verify OTP #{id}: verified=#{verified?}, expired=#{expired?}"

    if verified?
      Rails.logger.warn "OTP #{id} already verified"
      return false
    end

    if expired?
      Rails.logger.warn "OTP #{id} expired: expires_at=#{expires_at}, current=#{Time.current}"
      return false
    end

    Rails.logger.info "Marking OTP #{id} as verified"
    update!(verified: true, verified_at: Time.current)
    Rails.logger.info "OTP #{id} successfully marked as verified"
    true
  end

  def mark_as_used!
    update!(verified: true, verified_at: Time.current)
  end

  # Find valid OTP for user and purpose
  def self.find_valid_otp(user, code, purpose = 'email_verification')
    # Since we now use upsert, there should only be one OTP per user per purpose
    otp = find_by(user: user, purpose: purpose, code: code)
    return nil unless otp
    return nil if otp.verified? || otp.expired?

    otp
  end

  # Generate OTP for user using upsert pattern
  def self.generate_for_user(user, purpose = 'email_verification', expires_in_minutes = OtpConfig.expiry_minutes, request = nil)
    Rails.logger.info "Generating OTP for user #{user.id}, purpose: #{purpose}"

    otp_code = generate_otp_code
    otp = find_or_initialize_otp(user, purpose)
    log_current_state(otp, user)
    otp.assign_attributes(
      code: otp_code,
      verified: false,
      verified_at: nil,
      expires_at: expires_in_minutes.minutes.from_now,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )

    Rails.logger.info "OTP attributes: #{otp.attributes}"

    save_generated_otp(otp)
  end

  def self.generate_otp_code
    otp_code = (SecureRandom.random_number(900_000) + 100_000).to_s
    Rails.logger.info "Generated OTP code: #{otp_code}"
    otp_code
  end

  def self.find_or_initialize_otp(user, purpose)
    find_or_initialize_by(user: user, purpose: purpose) do |_new_otp|
      Rails.logger.info "Creating new OTP record for user #{user.id}"
    end
  end

  def self.log_current_state(otp, user)
    return unless otp.persisted?

    Rails.logger.info "Updating existing OTP #{otp.id} for user #{user.id}"
    Rails.logger.info "Previous: code=#{otp.code}, expires_at=#{otp.expires_at}, verified=#{otp.verified}"
  end

  def self.save_generated_otp(otp)
    if otp.save
      Rails.logger.info "OTP #{otp.persisted? ? 'updated' : 'created'} successfully: #{otp.id}"
      return otp
    end

    Rails.logger.error "OTP save failed: #{otp.errors.full_messages.join(', ')}"
    Rails.logger.error "OTP attributes: #{otp.attributes}"
    raise ActiveRecord::RecordInvalid, otp
  end

  private_class_method :generate_otp_code, :find_or_initialize_otp, :log_current_state, :save_generated_otp

  # These methods are no longer needed since we generate code manually
  # def generate_code
  #   self.code = (SecureRandom.random_number(900000) + 100000).to_s
  #   Rails.logger.info "Generated OTP code: #{self.code}"
  # end

  # def set_expiration
  #   self.expires_at ||= 10.minutes.from_now
  #   Rails.logger.info "Set OTP expiration: #{self.expires_at}"
  # end
end
