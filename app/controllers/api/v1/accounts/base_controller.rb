class Api::V1::Accounts::BaseController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper
  before_action :current_account
  around_action :switch_locale_using_account_locale

  private

  def ensure_active_subscription
    subscription = current_account&.active_subscription
    unless subscription&.active?
      subscription = current_account&.subscriptions&.find_by(status: 'active')
      current_account.update_column(:active_subscription_id, subscription&.id)
    end
    render_subscription_expired unless subscription&.active?
  rescue StandardError => e
    Rails.logger.error(
      "[BaseController] Error checking subscription for account ##{current_account&.id}: #{e.class} - #{e.message}"
    )
    render_subscription_expired
  end

  def render_subscription_expired
    render json: { error: 'subscription_expired', message: 'Your account subscription has expired' }, status: :forbidden
  end
end
