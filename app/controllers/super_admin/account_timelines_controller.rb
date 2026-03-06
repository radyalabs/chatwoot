class SuperAdmin::AccountTimelinesController < SuperAdmin::ApplicationController
  def index
    @users = User.includes(:otps, :account_users, :accounts)
                 .order(created_at: :desc)
                 .page(params[:page])

    return if params[:search].blank?

    @users = @users.where('name ILIKE ? OR email ILIKE ?',
                          "%#{params[:search]}%",
                          "%#{params[:search]}%")
  end

  def show
    @user = User.includes(:otps, :account_users, :accounts).find(params[:id])
    @timeline = AccountTimelinePresenter.new(@user).build_timeline
  end
end
