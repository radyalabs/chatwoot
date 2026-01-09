class SuperAdmin::ContactConversationsController < SuperAdmin::ApplicationController
  before_action :find_account
  before_action :find_inbox
  before_action :find_contact

  def index
    @conversations = Conversation.where(
      account_id: @account.id,
      inbox_id: @inbox.id,
      contact_id: @contact.id
    ).includes(messages: [:sender]).order(created_at: :asc)
  end

  private

  def find_account
    @account = Account.find(params[:account_id])
  end

  def find_inbox
    @inbox = @account.inboxes.find(params[:inbox_id])
  end

  def find_contact
    @contact = @account.contacts.find(params[:contact_id])
  end
end
