# frozen_string_literal: true

class AddStatusToChannelWhatsappUnofficials < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_whatsapp_unofficials, :status, :string, default: 'disconnected', null: false

    add_index :channel_whatsapp_unofficials, :status
  end
end
