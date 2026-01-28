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
      raw_stores_params = params[:stores] || []
      
      incoming_ids = raw_stores_params.map { |s| s['id'] || s[:id] }.compact.map(&:to_i)
      
      if raw_stores_params.empty?
        @ai_agent.shipping_stores.destroy_all
      else
        @ai_agent.shipping_stores.where.not(id: incoming_ids).destroy_all
      end

      @saved_stores = raw_stores_params.map do |store_data|
        current_data = store_data.try(:permit!) || store_data
        
        current_id = current_data['id'] || current_data[:id]
        
        store = nil
        if current_id.present?
          store = @ai_agent.shipping_stores.find_by(id: current_id)
        end
        
        store ||= @ai_agent.shipping_stores.build(account: Current.account)
        store.assign_attributes(map_frontend_params(current_data))
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
    coords = p[:coordinates] || p['coordinates'] || {}

    {
      name: p[:name] || p['name'],
      address: p[:address] || p['address'],
      latitude: coords[:lat] || coords['lat'],
      longitude: coords[:lng] || coords['lng'],
      courier_settings: p[:store_courier] || p['store_courier'] || {},
      pickup_settings: p[:store_pickup] || p['store_pickup'] || {},
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