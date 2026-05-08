class CreateGroupChatLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :group_chat_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :group_monitored_chat, null: false, foreign_key: true
      t.string :event_type, null: false     # message, message.reaction
      t.string :message_id                  # GOWA message ID
      t.string :sender_jid                  # e.g. "6281234@s.whatsapp.net"
      t.string :sender_name
      t.text :content                       # pesan teks
      t.string :replied_to_id              # untuk reply
      t.text :quoted_body                  # teks yang dikutip
      t.string :reaction_emoji             # untuk reaction
      t.string :reaction_target_id         # message ID yang di-react
      t.jsonb :raw_payload, default: {}    # simpan payload asli
      t.datetime :sent_at
      t.timestamps
    end
    add_index :group_chat_logs, [:group_monitored_chat_id, :message_id]
    add_index :group_chat_logs, :event_type
  end
end