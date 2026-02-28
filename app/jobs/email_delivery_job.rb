# frozen_string_literal: true

class EmailDeliveryJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(mailer_class, mailer_method, *args, source)
    mailer = mailer_class.constantize
    email = mailer.public_send(mailer_method, *args)
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
    Rails.logger.error "Email delivery failed in job: #{e.message}"
    raise e
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
