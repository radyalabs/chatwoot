class Api::V1::Accounts::BroadcastTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_template, only: [:update, :destroy]

  def index
    # Mengambil semua template milik akun/perusahaan ini, diurutkan sesuai abjad nama
    @templates = Current.account.broadcast_templates.order(name: :asc)
    render json: @templates
  end

  def create
    # Membuat template baru yang langsung terikat dengan akun/perusahaan saat ini
    @template = Current.account.broadcast_templates.new(template_params)

    if @template.save
      render json: @template, status: :created
    else
      render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @template.update(template_params)
      render json: @template
    else
      render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @template.destroy
    head :ok
  end

  private

  def fetch_template
    # Hanya mencari template berdasarkan ID di dalam scope akun saat ini (Mencegah IDOR/Bocor data)
    @template = Current.account.broadcast_templates.find(params[:id])
  end

  def template_params
    # Strong parameters: Hanya mengizinkan parameter name dan message_body yang masuk ke database
    params.require(:broadcast_template).permit(:name, :message_body)
  end
end