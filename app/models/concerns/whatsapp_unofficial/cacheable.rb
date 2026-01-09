# frozen_string_literal: true

module WhatsappUnofficial
  module Cacheable
    extend ActiveSupport::Concern

    included do
      before_destroy :clear_session_status_cache
      before_destroy :clear_rescan_attempts
      before_destroy :clear_mismatch_attempts
    end

    # Cache key helpers
    def session_status_cache_key
      "whatsapp_session_status_#{phone_number}"
    end

    def mismatch_attempts_cache_key
      "whatsapp_mismatch_attempts_#{phone_number}"
    end

    def rescan_attempts_cache_key
      "whatsapp_rescan_attempts_#{phone_number}"
    end

    # Session status cache operations
    def read_session_status_from_cache
      ::Redis::Alfred.get(session_status_cache_key)
    end

    def write_session_status_to_cache(status, expires_in: 24.hours)
      ::Redis::Alfred.setex(session_status_cache_key, status, expires_in.to_i)
      Rails.logger.info "REDIS: Wrote '#{status}' to #{session_status_cache_key}"
    end

    def clear_session_status_cache
      ::Redis::Alfred.delete(session_status_cache_key)
      Rails.logger.info "REDIS: Cleared cache for #{session_status_cache_key}"
    end

    # Mismatch attempts cache operations
    def read_mismatch_attempts_from_cache
      ::Redis::Alfred.get(mismatch_attempts_cache_key).to_i
    end

    def increment_mismatch_attempts
      key = mismatch_attempts_cache_key
      lock_key = "increment_lock_#{phone_number}"
      last_increment_key = "last_increment_#{phone_number}"
      lock_value = "lock_#{Time.current.to_f}_#{SecureRandom.hex(4)}"

      # Check if there was a recent increment (within 3 seconds) to prevent rapid increments
      last_increment_time = ::Redis::Alfred.get(last_increment_key)
      if last_increment_time
        time_since_last = Time.current.to_f - last_increment_time.to_f
        if time_since_last < 3.0
          Rails.logger.warn "Rapid increment blocked! Last increment was #{time_since_last.round(2)}s ago"
          return ::Redis::Alfred.get(key).to_i
        end
      end

      # Try to acquire increment lock to prevent race conditions
      acquired_lock = ::Redis::Alfred.set(lock_key, lock_value, nx: true, ex: 5)

      unless acquired_lock
        Rails.logger.warn "Increment locked for #{phone_number}. Returning current value to prevent duplicate."
        return ::Redis::Alfred.get(key).to_i
      end

      begin
        current_value = ::Redis::Alfred.get(key).to_i
        Rails.logger.info "REDIS: Current attempts before increment: #{current_value} for #{phone_number}"

        new_attempts = ::Redis::Alfred.incr(key)
        ::Redis::Alfred.expire(key, 1.hour.to_i) if new_attempts == 1
        ::Redis::Alfred.setex(last_increment_key, Time.current.to_f.to_s, 10)

        Rails.logger.info "REDIS: Incremented mismatch attempts to #{new_attempts} for #{phone_number}"

        if current_value.positive? && new_attempts > current_value + 1
          Rails.logger.warn "SUSPICIOUS: Attempts jumped from #{current_value} to #{new_attempts} for #{phone_number}"
        end

        new_attempts
      ensure
        if ::Redis::Alfred.get(lock_key) == lock_value
          ::Redis::Alfred.del(lock_key)
          Rails.logger.debug { "Released increment lock for #{phone_number}" }
        end
      end
    end

    def clear_mismatch_attempts
      ::Redis::Alfred.delete(mismatch_attempts_cache_key)
      Rails.logger.info "REDIS: Cleared mismatch attempts for #{phone_number}"
    end

    # Rescan attempts cache operations
    def read_rescan_attempts_from_cache
      ::Redis::Alfred.get(rescan_attempts_cache_key).to_i
    end

    def increment_rescan_attempts
      key = rescan_attempts_cache_key
      current_value = ::Redis::Alfred.get(key).to_i
      Rails.logger.info "REDIS: Current rescan attempts before increment: #{current_value} for #{phone_number}"

      new_attempts = ::Redis::Alfred.incr(key)
      ::Redis::Alfred.expire(key, 24.hours.to_i) if new_attempts == 1

      Rails.logger.info "REDIS: Incremented rescan attempts to #{new_attempts} for #{phone_number}"
      new_attempts
    end

    def clear_rescan_attempts
      ::Redis::Alfred.delete(rescan_attempts_cache_key)
      Rails.logger.info "REDIS: Cleared rescan attempts for #{phone_number}"
    end

    # Cached session status with interpretation
    def session_status
      Rails.logger.info "Checking session status for #{phone_number} using cache"

      return { 'data' => { 'connected' => false, 'status' => 'not_logged_in' } } if token.blank? && device_id.blank?

      cached_status = read_session_status_from_cache
      Rails.logger.info "CACHE: Read '#{cached_status}' for #{phone_number}"

      case cached_status
      when 'validated'
        { 'data' => { 'connected' => true, 'status' => 'logged_in' } }
      when 'mismatch'
        { 'data' => { 'connected' => false, 'status' => 'mismatch' } }
      when 'waiting'
        { 'data' => { 'connected' => false, 'status' => 'waiting_for_qr' } }
      when 'failed'
        { 'data' => { 'connected' => false, 'status' => 'failed' } }
      else
        { 'data' => { 'connected' => false, 'status' => 'pending_validation' } }
      end
    end
  end
end
