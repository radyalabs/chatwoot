class Api::V1::Accounts::ContactAttributeKeysController < Api::V1::Accounts::BaseController
  before_action :fetch_key, only: [:destroy]

  def index
    render json: Current.account.contact_attribute_keys.order(:key).map { |r| { id: r.id, key: r.key, data_type: r.data_type } }
  end

  def create
    key = params[:key].to_s.strip
    data_type = ContactAttributeKey.data_types.key?(params[:data_type].to_s) ? params[:data_type].to_s : 'text'
    record = Current.account.contact_attribute_keys.find_or_create_by!(key: key)
    record.update!(data_type: data_type) if record.data_type != data_type
    render json: { id: record.id, key: record.key, data_type: record.data_type }, status: :ok
  end

  def destroy
    @key.destroy!
    head :ok
  end

  private

  def fetch_key
    @key = Current.account.contact_attribute_keys.find(params[:id])
  end
end
