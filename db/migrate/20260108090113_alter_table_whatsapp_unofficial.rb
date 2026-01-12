class AlterTableWhatsappUnofficial < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_whatsapp_unofficials, :provider, :string, null: true
    add_column :channel_whatsapp_unofficials, :device_id, :string, null: true
    add_column :channel_whatsapp_unofficials, :provider_config, :jsonb, default: {}
  end
end
