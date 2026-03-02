class CreateEmailSenders < ActiveRecord::Migration[7.0]
  def change
    create_table :email_senders do |t|
      t.text :body
      t.string :subject
      t.integer :status, default: 0
      t.integer :source, default: 0
      t.string :to_email
      t.string :from_email
      t.text :error_message

      t.timestamps
    end

    add_index :email_senders, :status
    add_index :email_senders, :source
    add_index :email_senders, :to_email
    add_index :email_senders, :created_at
  end
end
