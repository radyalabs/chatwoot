module ScheduledReminders
  class OccurrenceCalculator
    DAYS_OF_WEEK = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

    def initialize(reminder)
      @reminder = reminder
      @rule = (reminder.recurrence_rule || {}).with_indifferent_access
      @timezone = ActiveSupport::TimeZone[reminder.timezone] || ActiveSupport::TimeZone['UTC']
    end

    # Returns the next occurrence for scheduling (used when creating/updating)
    def next_occurrence
      return nil unless @reminder.enabled?

      if @reminder.recurring?
        compute_next_recurring
      else
        # One-time: return scheduled_at if not yet sent
        @reminder.occurrence_count.zero? ? @reminder.scheduled_at : nil
      end
    end

    # Returns the next occurrence after the current one was sent (used by advance_occurrence!)
    def next_after_current
      return nil unless @reminder.recurring?
      return nil if series_ended?

      compute_next_from(Time.current)
    end

    def human_readable_summary
      return nil unless @reminder.recurring?

      frequency = @rule['frequency']
      interval = (@rule['interval'] || 1).to_i

      case frequency
      when 'daily'
        interval == 1 ? 'Daily' : "Every #{interval} days"
      when 'weekly'
        days = format_days_of_week
        base = interval == 1 ? 'Weekly' : "Every #{interval} weeks"
        days.present? ? "#{base} on #{days}" : base
      when 'monthly'
        base = interval == 1 ? 'Monthly' : "Every #{interval} months"
        if @rule['week_of_month'].present? && @rule['day_of_week_monthly'].present?
          ordinal = ordinal_word(@rule['week_of_month'].to_i)
          day_name = DAYS_OF_WEEK[@rule['day_of_week_monthly'].to_i]&.capitalize
          "#{base} on the #{ordinal} #{day_name}"
        elsif @rule['day_of_month'].present?
          "#{base} on day #{@rule['day_of_month']}"
        else
          base
        end
      when 'yearly'
        interval == 1 ? 'Annually' : "Every #{interval} years"
      else
        nil
      end
    end

    private

    def compute_next_recurring
      if @reminder.occurrence_count.zero? && @reminder.scheduled_at > Time.current
        @reminder.scheduled_at
      else
        compute_next_from([@reminder.last_sent_at || @reminder.scheduled_at, Time.current].max)
      end
    end

    def compute_next_from(after_time)
      return nil if series_ended?

      frequency = @rule['frequency']
      interval = (@rule['interval'] || 1).to_i

      candidate = case frequency
                  when 'daily' then next_daily(after_time, interval)
                  when 'weekly' then next_weekly(after_time, interval)
                  when 'monthly' then next_monthly(after_time, interval)
                  when 'yearly' then next_yearly(after_time, interval)
                  else nil
                  end

      return nil if candidate.nil?
      return nil if @reminder.ends_at.present? && candidate > @reminder.ends_at

      candidate
    end

    def next_daily(after_time, interval)
      local_scheduled = @reminder.scheduled_at.in_time_zone(@timezone)
      local_after = after_time.in_time_zone(@timezone)
      allowed_days = (@rule['days_of_week'] || []).map(&:to_i)

      if allowed_days.any?
        candidate_date = local_after.to_date + 1.day
        8.times do
          if allowed_days.include?(candidate_date.wday)
            return @timezone.local(candidate_date.year, candidate_date.month, candidate_date.day,
                                   local_scheduled.hour, local_scheduled.min, local_scheduled.sec).utc
          end

          candidate_date += 1.day
        end
        nil
      else
        candidate_date = local_after.to_date + 1.day
        days_since_start = (candidate_date - local_scheduled.to_date).to_i
        remainder = days_since_start % interval
        candidate_date += (interval - remainder).days if remainder != 0
        @timezone.local(candidate_date.year, candidate_date.month, candidate_date.day,
                        local_scheduled.hour, local_scheduled.min, local_scheduled.sec).utc
      end
    end

    def next_weekly(after_time, interval)
      local_scheduled = @reminder.scheduled_at.in_time_zone(@timezone)
      local_after = after_time.in_time_zone(@timezone)
      target_days = (@rule['days_of_week'] || [local_scheduled.wday]).map(&:to_i).sort

      return nil if target_days.empty?

      start_of_week = local_scheduled.beginning_of_week(:sunday).to_date
      current_date = local_after.to_date + 1.day

      # Search up to 8 weeks ahead to find a valid occurrence
      (0..8 * 7).each do |offset|
        check_date = current_date + offset.days
        weeks_since_start = ((check_date.beginning_of_week(:sunday) - start_of_week) / 7).to_i

        next unless (weeks_since_start % interval).zero?
        next unless target_days.include?(check_date.wday)

        return @timezone.local(check_date.year, check_date.month, check_date.day,
                               local_scheduled.hour, local_scheduled.min, local_scheduled.sec).utc
      end

      nil
    end

    def next_monthly(after_time, interval)
      local_scheduled = @reminder.scheduled_at.in_time_zone(@timezone)
      local_after = after_time.in_time_zone(@timezone)

      start_month = local_scheduled.year * 12 + local_scheduled.month - 1
      current_month_val = local_after.year * 12 + local_after.month - 1

      # Start searching from next month or current month
      search_start = current_month_val
      (0..24).each do |i|
        month_val = search_start + i
        months_since_start = month_val - start_month

        next if months_since_start.negative?
        next unless (months_since_start % interval).zero?

        year = month_val / 12
        month = (month_val % 12) + 1

        candidate = if @rule['week_of_month'].present? && @rule['day_of_week_monthly'].present?
                      nth_weekday_of_month(year, month, @rule['week_of_month'].to_i, @rule['day_of_week_monthly'].to_i,
                                           local_scheduled)
                    else
                      day = [@rule['day_of_month']&.to_i || local_scheduled.day, days_in_month(year, month)].min
                      @timezone.local(year, month, day,
                                      local_scheduled.hour, local_scheduled.min, local_scheduled.sec).utc
                    end

        next if candidate.nil?
        return candidate if candidate > after_time
      end

      nil
    end

    def next_yearly(after_time, interval)
      local_scheduled = @reminder.scheduled_at.in_time_zone(@timezone)
      local_after = after_time.in_time_zone(@timezone)

      start_year = local_scheduled.year
      search_year = local_after.year

      (0..10).each do |i|
        year = search_year + i
        years_since = year - start_year

        next if years_since.negative?
        next unless (years_since % interval).zero?

        month = @rule['month_of_year']&.to_i || local_scheduled.month
        day = [local_scheduled.day, days_in_month(year, month)].min

        candidate = @timezone.local(year, month, day,
                                    local_scheduled.hour, local_scheduled.min, local_scheduled.sec).utc
        return candidate if candidate > after_time
      end

      nil
    end

    def nth_weekday_of_month(year, month, week_of_month, day_of_week, local_scheduled)
      first_day = Date.new(year, month, 1)
      first_target_wday = first_day + ((day_of_week - first_day.wday) % 7).days
      target_date = first_target_wday + (week_of_month - 1).weeks

      return nil if target_date.month != month

      @timezone.local(target_date.year, target_date.month, target_date.day,
                      local_scheduled.hour, local_scheduled.min, local_scheduled.sec).utc
    end

    def series_ended?
      return true if @reminder.ends_after_count.present? && @reminder.occurrence_count >= @reminder.ends_after_count
      return true if @reminder.ends_at.present? && Time.current > @reminder.ends_at

      false
    end

    def days_in_month(year, month)
      Date.new(year, month, -1).day
    end

    def format_days_of_week
      days = (@rule['days_of_week'] || []).map(&:to_i).sort
      days.map { |d| DAYS_OF_WEEK[d]&.capitalize&.first(3) }.compact.join(', ')
    end

    def ordinal_word(n)
      %w[first second third fourth fifth][n - 1] || "#{n}th"
    end
  end
end
