# == Schema Information
#
# Table name: email_senders
#
#  id            :bigint           not null, primary key
#  body          :text
#  error_message :text
#  from_email    :string
#  source        :integer          default("system")
#  status        :integer          default("pending")
#  subject       :string
#  to_email      :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_email_senders_on_created_at  (created_at)
#  index_email_senders_on_source      (source)
#  index_email_senders_on_status      (status)
#  index_email_senders_on_to_email    (to_email)
#
class EmailSender < ApplicationRecord
  enum status: { pending: 0, sent: 1, delivered: 2, failed: 3 }
  enum source: { system: 0, user: 1, automation: 2, campaign: 3 }

  before_create :set_default_from_email

  validates :body, presence: true
  validates :subject, presence: true
  validates :to_email, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :source, presence: true, inclusion: { in: sources.keys }

  private

  def set_default_from_email
    self.from_email ||= ENV.fetch('MAILER_SENDER_EMAIL', nil)
  end
end
