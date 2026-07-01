module Api
  module V2
    module Internal
      class ConversationMessagesController < ActionController::API
        before_action :authenticate_api_key!

        def create
          conversation = Conversation.find(params[:conversation_id])

          message = conversation.messages.create!(
            content: params[:content],
            message_type: params[:message_type] || 1,
            sender_type: params[:sender_type] || 'AiAgent',
            sender_id: params[:sender_id],
            account_id: conversation.account_id,
            inbox_id: conversation.inbox_id,
            content_type: 0,
            status: 0
          )

          render json: { id: message.id, content: message.content }, status: :created
        end

        private

        def authenticate_api_key!
          api_key = request.headers['X-Internal-Api-Key'] || request.headers['X-API-Key']
          expected_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

          unless expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key.to_s, expected_key)
            render json: { error: 'Unauthorized' }, status: :unauthorized
          end
        end
      end
    end
  end
end
