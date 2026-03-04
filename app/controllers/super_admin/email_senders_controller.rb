class SuperAdmin::EmailSendersController < SuperAdmin::ApplicationController
  def scoped_resource
    EmailSender.order(created_at: :desc)
  end
end
