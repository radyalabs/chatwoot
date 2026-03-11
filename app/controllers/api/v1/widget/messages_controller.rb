class Api::V1::Widget::MessagesController < Api::V1::Widget::BaseController
  before_action :set_conversation, only: [:create]
  before_action :set_message, only: [:update]

  def index
    @messages = conversation.nil? ? [] : message_finder.perform
  end

  def create
    @message = conversation.messages.new(message_params)
    @message.inbox = conversation.inbox
    @message.account_id = conversation.account_id
    @message.message_type = :incoming
    build_attachment
    @message.save!
  end

  def update
    if @message.content_type == 'input_email'
      @message.update!(submitted_email: contact_email)
      ContactIdentifyAction.new(
        contact: @contact,
        params: { email: contact_email, name: contact_name },
        retain_original_contact_name: true
      ).perform
    else
      @message.update!(message_update_params[:message])
    end
  rescue StandardError => e
    render json: { error: @contact.errors, message: e.message }.to_json, status: :internal_server_error
  end

  private

  def build_attachment
    return if params[:message][:attachments].blank?

    params[:message][:attachments].each do |uploaded_attachment|
      attachment = @message.attachments.new(
        account_id: @message.account_id,
        file: uploaded_attachment
      )

      # [PERBAIKAN] Cek tipe file secara manual berdasarkan content_type
      # agar tidak dianggap 'file' biasa oleh helper
      if uploaded_attachment.is_a?(ActionDispatch::Http::UploadedFile)
        content_type = uploaded_attachment.content_type
        attachment.file_type = if content_type.include?('image')
                                 :image
                               elsif content_type.include?('audio')
                                 :audio
                               elsif content_type.include?('video')
                                 :video
                               else
                                 :file
                               end
      end
    end
  end

  def conversation
    @conversation ||= if permitted_params[:conversation_id].present?
                        @contact_inbox.conversations.find_by(display_id: permitted_params[:conversation_id])
                      else
                        @contact_inbox.conversations.last
                      end
    @conversation
  end

  def set_conversation
    @conversation = create_conversation if conversation.nil?
  end

  def message_finder_params
    {
      filter_internal_messages: true,
      before: permitted_params[:before],
      after: permitted_params[:after]
    }
  end

  def message_finder
    @message_finder ||= MessageFinder.new(conversation, message_finder_params)
  end

  def message_update_params
    params.permit(message: [{ submitted_values: [:name, :title, :value, { csat_survey_response: [:feedback_message, :rating] }] }])
  end

  def permitted_params
    # timestamp parameter is used in create conversation method
    params.permit(:id, :conversation_id, :before, :after, :website_token, contact: [:name, :email], message: [:content, :referer_url, :timestamp, :echo_id, :reply_to])
  end

  def set_message
    @message = @web_widget.inbox.messages.find(permitted_params[:id])
  end
end
