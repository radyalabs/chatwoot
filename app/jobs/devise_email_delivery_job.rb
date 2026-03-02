# frozen_string_literal: true

class DeviseEmailDeliveryJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(mailer_class, mailer_method, account_id, user_id, *args, source) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/ParameterLists
    Current.account = Account.find_by(id: account_id) if account_id

    user = User.find(user_id)
    mailer = mailer_class.constantize

    email = mailer.with(account: Current.account).send(mailer_method, user, *args)
    message = email.message

    email_sender = EmailSender.create!(
      to_email: message.to&.first,
      from_email: message.from&.first || ENV.fetch('MAILER_SENDER_EMAIL', nil),
      subject: message.subject,
      body: extract_body(message),
      source: source,
      status: :pending
    )

    result = email.deliver_now
    email_sender.update!(status: :sent)
    result
  rescue StandardError => e
    email_sender&.update!(status: :failed, error_message: e.message)
    Rails.logger.error "Devise email delivery failed: #{e.message}"
    raise e
  ensure
    Current.reset
  end

  private

  def extract_body(message)
    if message.multipart?
      message.html_part&.body&.to_s || message.text_part&.body&.to_s
    else
      message.body.to_s
    end
  end
end
