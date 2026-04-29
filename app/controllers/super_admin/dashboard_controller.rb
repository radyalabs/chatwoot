class SuperAdmin::DashboardController < SuperAdmin::ApplicationController
  include ActionView::Helpers::NumberHelper

  def index
    @data = Conversation.unscoped.group_by_day(:created_at, range: 30.days.ago..2.seconds.ago).count.to_a
    @accounts_count = number_with_delimiter(Account.count)
    @users_count = number_with_delimiter(User.count)
    @inboxes_count = number_with_delimiter(Inbox.count)
    @conversations_count = number_with_delimiter(Conversation.count)

    @accounts_subscriptions_count = number_with_delimiter(Subscription.where(status: 'active').select(:account_id).distinct.count)
    @accounts_active_count = number_with_delimiter(Subscription.where(status: 'active').where('ends_at > ?',
                                                                                              Time.current).select(:account_id).distinct.count)
    @accounts_expired_count = number_with_delimiter(Subscription.where(status: 'active').where('ends_at <= ?',
                                                                                               Time.current).select(:account_id).distinct.count)

    @administrators_count = number_with_delimiter(AccountUser.where(role: :administrator).select(:user_id).distinct.count)
    @agents_count = number_with_delimiter(AccountUser.where(role: :agent).select(:user_id).distinct.count)
    @users_unverified_count = number_with_delimiter(User.left_joins(:account_users).where(account_users: { user_id: nil }).count)
  end
end
