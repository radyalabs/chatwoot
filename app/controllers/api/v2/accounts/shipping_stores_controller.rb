class Api::V2::Accounts::ShippingStoresController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent

  # GET /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/shipping_stores
  def index
    @stores = @ai_agent.shipping_stores.order(created_at: :asc)
    render json: @stores.map { |store| format_store_response(store) }
  end

  # POST /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/shipping_stores/batch_update
  def batch_update
    ActiveRecord::Base.transaction do
      incoming_ids = params[:stores].map { |s| s[:id] }.compact.map(&:to_i)
      
      current_ids = @ai_agent.shipping_stores.pluck(:id)
      ids_to_delete = current_ids - incoming_ids
      @ai_agent.shipping_stores.where(id: ids_to_delete).destroy_all

      @saved_stores = params[:stores].map do |store_params|
        store = @ai_agent.shipping_stores.find_by(id: store_params[:id])
        
        store ||= @ai_agent.shipping_stores.build(account: Current.account)
        
        store.assign_attributes(map_frontend_params(store_params))
        store.save!
        store
      end
    end

    render json: @saved_stores.map { |store| format_store_response(store) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def map_frontend_params(p)
    {
      name: p[:name],
      address: p[:address],
      latitude: p.dig(:coordinates, :lat),
      longitude: p.dig(:coordinates, :lng),
      courier_settings: p[:store_courier] || {},
      pickup_settings: p[:store_pickup] || {},
      is_enabled: true
    }
  end

  def format_store_response(store)
    {
      id: store.id,
      name: store.name,
      address: store.address,
      coordinates: {
        lat: store.latitude&.to_f,
        lng: store.longitude&.to_f
      },
      store_courier: store.courier_settings,
      store_pickup: store.pickup_settings
    }
  end
end