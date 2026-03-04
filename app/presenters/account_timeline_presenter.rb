class AccountTimelinePresenter
  def initialize(user)
    @user = user
  end

  def build_timeline
    events = []

    # Account events
    @user.accounts.each do |account|
      events << build_account_event(account)
    end

    # User registration
    events << build_registration_event

    # Email verification
    events.concat(build_email_verification_events)

    # OTP events
    @user.otps.each do |otp|
      events.concat(build_otp_events(otp))
    end

    # Login events
    events.concat(build_login_events)

    # Sort descending by timestamp, filter nils
    events.compact.sort_by { |e| e[:timestamp] }.reverse
  end

  private

  def build_account_event(account)
    {
      type: :account_created,
      timestamp: account.created_at,
      icon: 'icon-building-line',
      title: 'Account Created',
      description: account.name,
      metadata: { account_id: account.id }
    }
  end

  def build_registration_event
    {
      type: :user_registered,
      timestamp: @user.created_at,
      icon: 'icon-user-add-line',
      title: 'User Registered',
      description: "#{@user.name} (#{@user.email})"
    }
  end

  def build_email_verification_events
    events = []

    if @user.confirmation_sent_at
      events << {
        type: :verification_sent,
        timestamp: @user.confirmation_sent_at,
        icon: 'icon-mail-send-line',
        title: 'Verification Email Sent',
        description: @user.email
      }
    end

    if @user.confirmed_at
      events << {
        type: :email_verified,
        timestamp: @user.confirmed_at,
        icon: 'icon-mail-check-line',
        title: 'Email Verified',
        description: @user.email
      }
    end

    events
  end

  def build_otp_events(otp)
    events = []

    events << {
      type: :otp_sent,
      timestamp: otp.created_at,
      icon: 'icon-shield-key-line',
      title: 'OTP Sent',
      description: "Purpose: #{otp.purpose.humanize}",
      metadata: { ip: otp.ip_address }
    }

    if otp.verified?
      events << {
        type: :otp_verified,
        timestamp: otp.verified_at,
        icon: 'icon-shield-check-line',
        title: 'OTP Verified',
        description: "Purpose: #{otp.purpose.humanize}",
        metadata: { ip: otp.ip_address }
      }
    end

    events
  end

  def build_login_events
    events = []

    if @user.current_sign_in_at
      events << {
        type: :current_session,
        timestamp: @user.current_sign_in_at,
        icon: 'icon-login-circle-line',
        title: 'Current Session',
        description: "IP: #{@user.current_sign_in_ip}"
      }
    end

    if @user.last_sign_in_at
      events << {
        type: :last_login,
        timestamp: @user.last_sign_in_at,
        icon: 'icon-history-line',
        title: 'Last Login',
        description: "IP: #{@user.last_sign_in_ip} (Sign in ##{@user.sign_in_count})"
      }
    end

    events
  end
end
