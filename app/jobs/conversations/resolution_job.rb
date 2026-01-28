class Conversations::ResolutionJob < ApplicationJob
  queue_as :low

  def perform(account:)
    # limiting the number of conversations to be resolved to avoid any performance issues
    auto_resolve_duration = account.auto_resolve_duration || ENV.fetch('AUTO_RESOLVE_CONVERSATION_DURATION', 1).to_i

    resolvable_conversations = account.conversations
                                      .with_completed_idle
                                      .resolvable(auto_resolve_duration)
                                      .limit(Limits::BULK_ACTIONS_LIMIT)
    resolvable_conversations.each(&:toggle_status)
  end
end
