class Api::V1::Accounts::ContactAttributeKeysController < Api::V1::Accounts::BaseController
  before_action :fetch_key, only: [:destroy]

  def index
    render json: Current.account.contact_attribute_keys.order(:key).pluck(:id, :key).map { |id, k| { id: id, key: k } }
  end

  def create
    record = Current.account.contact_attribute_keys.find_or_create_by!(key: params[:key].to_s.strip)
    render json: { id: record.id, key: record.key }, status: :ok
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
