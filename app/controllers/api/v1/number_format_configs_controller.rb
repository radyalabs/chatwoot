class Api::V1::NumberFormatConfigsController < Api::BaseController
  # Kita harus menambahkan 'set_account' di sini karena
  # 'Api::BaseController' (induknya) tidak memilikinya.
  before_action :set_account

  # 'before_action' ini HANYA berjalan untuk 'show'
  before_action :set_config_for_show, only: [:show]

  # 'before_action' ini HANYA berjalan untuk 'update'
  before_action :set_config_for_update, only: [:update]

  def show
    # @config di-set oleh :set_config_for_show
    # Ini akan merender 'null' jika config belum ada, dan ini yang kita inginkan
    # agar frontend bisa menampilkan nilai default.
    render json: @config
  end

  def create
    # Menggunakan 'build_...' (dari relasi 'has_one') untuk membuat record baru
    @config = @account.build_number_format_config(config_params)

    if @config.save
      render json: @config
    else
      render json: @config.errors, status: :unprocessable_entity
    end
  end

  def update
    # @config sudah di-set oleh :set_config_for_update
    if @config.update(config_params)
      render json: @config
    else
      render json: @config.errors, status: :unprocessable_entity
    end
  end

  private

  def set_account
    # Mengambil 'account_id' dari parameter URL
    # 'current_user' didapat dari 'Api::BaseController'
    @account = current_user.accounts.find(params[:account_id])
  end

  def set_config_for_show
    # Menggunakan nama relasi (singular) dari model 'Account'
    @config = @account.number_format_config
  end

  def set_config_for_update
    @config = @account.number_format_config
    # Kirim 404 (Not Found) jika user mencoba 'update' data yang belum ada
    render_not_found unless @config
  end

  def config_params
    # 'require' nama model (singular) sesuai dengan yang dikirim API client
    params.require(:number_format_config).permit(:format, :current_number, :reset_every)
  end
end
