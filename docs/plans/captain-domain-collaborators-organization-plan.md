# Captain Domain Collaborators Organization Plan

## Goal

Organize `app/services/captain/` so it remains a Captain domain service layer while separating non-service collaborators into clear domain subfolders.

This is a structural refactor only. It should not change runtime behavior.

## Principles

- Keep Captain-related collaborators under `app/services/captain/` to preserve domain cohesion.
- Use role-based subfolders for objects that are not orchestration services.
- Match file paths and constants for Zeitwerk autoloading.
- Do not add compatibility aliases unless a concrete external caller requires them.
- Keep the change reviewable as one dedicated refactor commit.

## Target Structure

```text
app/services/captain/copilot/
  chat_service.rb
  welcome_message_service.rb
  welcome_source_claimer.rb
  greeting_image_sender.rb
  message_debouncer.rb
  reply_sender.rb
  reply_dispatcher.rb
  group_context_service.rb

app/services/captain/copilot/policies/
  welcome_message_policy.rb
  group_mention_policy.rb

app/services/captain/copilot/state/
  conversation_ai_state.rb
  conversation_state_handler.rb
  message_context.rb

app/services/captain/copilot/locks/
  ai_invocation_lock.rb

app/services/captain/copilot/guards/
  eligibility_guard.rb
  eligibility_guard_logger.rb

app/services/captain/copilot/config/
  debounce_config.rb

app/services/captain/llm/
  assistant_chat_service.rb
  base_jangkau_service.rb
  base_flowise_service.rb
  base_azure_open_ai_service.rb
  conversation_summary_service.rb
  generate_idle_message_service.rb
  system_prompt_service.rb
  translate_service.rb
  whatsapp_reply_context_enricher.rb

app/services/captain/llm/policies/
  jangkau_endpoint_policy.rb

app/services/captain/llm/clients/
  jangkau_api_client.rb

app/services/captain/llm/builders/
  jangkau_request_builder.rb
  attachment_payload_builder.rb
```

## Namespace Changes

- `Captain::Copilot::WelcomeMessagePolicy` -> `Captain::Copilot::Policies::WelcomeMessagePolicy`
- `Captain::Copilot::GroupMentionPolicy` -> `Captain::Copilot::Policies::GroupMentionPolicy`
- `Captain::Copilot::ConversationAiState` -> `Captain::Copilot::State::ConversationAiState`
- `Captain::Copilot::ConversationStateHandler` -> `Captain::Copilot::State::ConversationStateHandler`
- `Captain::Copilot::MessageContext` -> `Captain::Copilot::State::MessageContext`
- `Captain::Copilot::AiInvocationLock` -> `Captain::Copilot::Locks::AiInvocationLock`
- `Captain::Copilot::EligibilityGuard` -> `Captain::Copilot::Guards::EligibilityGuard`
- `Captain::Copilot::EligibilityGuardLogger` -> `Captain::Copilot::Guards::EligibilityGuardLogger`
- `Captain::Copilot::DebounceConfig` -> `Captain::Copilot::Config::DebounceConfig`
- `Captain::Llm::JangkauEndpointPolicy` -> `Captain::Llm::Policies::JangkauEndpointPolicy`
- `Captain::Llm::JangkauApiClient` -> `Captain::Llm::Clients::JangkauApiClient`
- `Captain::Llm::JangkauRequestBuilder` -> `Captain::Llm::Builders::JangkauRequestBuilder`
- `Captain::Llm::AttachmentPayloadBuilder` -> `Captain::Llm::Builders::AttachmentPayloadBuilder`
- `Captain::Llm::GenerateIdleMessage` -> `Captain::Llm::GenerateIdleMessageService`

## Execution Steps

1. Move files into the target subfolders.
2. Rename `generate_idle_message.rb` to `generate_idle_message_service.rb`.
3. Update class declarations to match their new Zeitwerk paths.
4. Update all references in app code, jobs, listeners, and specs.
5. Move specs to mirror the new folders where useful.
6. Grep for old constants and remove all stale references.
7. Run focused Captain specs.
8. Run RuboCop on touched files.
9. Commit as a separate refactor commit.

## Focused Validation

```bash
eval "$(rbenv init -)" && bundle exec rspec \
  spec/services/captain \
  spec/jobs/captain/copilot \
  spec/listeners/action_cable_listener_spec.rb
```

```bash
eval "$(rbenv init -)" && bundle exec rubocop \
  app/services/captain \
  app/jobs/captain/copilot \
  app/listeners/action_cable_listener.rb \
  spec/services/captain \
  spec/jobs/captain/copilot \
  spec/listeners/action_cable_listener_spec.rb
```

## Suggested Commit

```text
refactor(captain): organize domain collaborators
```

## Risks

- Zeitwerk autoload mismatch if file paths and constants do not match.
- Missed references in jobs, listeners, or specs.
- Over-segmentation if future Captain collaborators remain small. Keep this scoped to obvious non-service roles only.

## Non-Goals

- Do not move Captain collaborators to new top-level directories like `app/clients`, `app/builders`, or `app/state` in this pass.
- Do not change behavior, request/response contracts, debounce behavior, welcome routing, or LLM endpoint behavior.
- Do not add new specs unless a moved object requires a path/reference update in existing specs.
