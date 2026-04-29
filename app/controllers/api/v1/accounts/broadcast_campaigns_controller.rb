class Api::V1::Accounts::BroadcastCampaignsController < Api::V1::Accounts::BaseController
  before_action :fetch_campaign, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    # Mengambil semua riwayat blasting milik akun ini, diurutkan dari yang terbaru
    @campaigns = Current.account.broadcast_campaigns.order(created_at: :desc)
    render json: @campaigns
  end

  def show
    render json: @campaign
  end

  def create
    @campaign = Current.account.broadcast_campaigns.new(campaign_params)

    if @campaign.save
      # PENTING: Lempar tugas pengiriman ke Background Job (Sidekiq)
      # Agar user tidak perlu menunggu layar loading lama saat mengirim ribuan pesan
      BroadcastExecutionJob.perform_later(@campaign.id)
      
      render json: @campaign, status: :created
    else
      render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @campaign.update(campaign_params)
      render json: @campaign
    else
      render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    head :ok
  end

  private

  def fetch_campaign
    @campaign = Current.account.broadcast_campaigns.find(params[:id])
  end

  def campaign_params
    # Strong parameters: Hanya izinkan data ini yang boleh masuk ke database
    params.require(:broadcast_campaign).permit(
      :inbox_id, 
      :target_segment, 
      :message_body, 
      :spin_text_enabled, 
      :unsubscribe_link_enabled
    )
  end

  def check_authorization
    # Keamanan: Fitur blasting massal sangat sensitif. 
    # Pastikan hanya user dengan role Administrator yang bisa mengakses fitur ini.
    unless Current.account_user.administrator?
      render json: { error: 'Unauthorized. Hanya Administrator yang dapat mengelola Blasting.' }, status: :unauthorized
    end
  end
end