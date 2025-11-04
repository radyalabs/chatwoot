class Api::V1::NumberFormatConfigsController < Api::BaseController
  before_action :set_account
  before_action :set_config_for_show, only: [:show]
  before_action :set_config_for_update, only: [:update]

  def show
    render json: @config
  end

  def create
    @config = @account.build_number_format_config(config_params)

    if @config.save
      render json: @config
    else
      render json: @config.errors, status: :unprocessable_entity
    end
  end

  def update
    if @config.update(config_params)
      render json: @config
    else
      render json: @config.errors, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:account_id])
  end

  def set_config_for_show
    @config = @account.number_format_config
  end

  def set_config_for_update
    @config = @account.number_format_config
    render_not_found unless @config
  end

  def config_params
    params.require(:number_format_config).permit(:format, :current_number, :reset_every, :prefix, :number_digits)
  end
end
