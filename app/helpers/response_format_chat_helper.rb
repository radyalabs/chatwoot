module ResponseFormatChatHelper
  include JsonHelper

  def parsed_response(response)
    raw_message = response&.dig('response')
    message = normalize_utf8(raw_message)
    is_handover = response&.dig('is_handover_human') || false
    is_end_state = response&.dig('is_end_state') || false

    [message, is_handover, is_end_state]
  end

  def json_response(response, is_custom_agent: false)
    if is_custom_agent
      extract_json_from_code_block(response['text'])
    else
      response
    end
  end

  def normalize_utf8(string)
    string.to_s
          .force_encoding('UTF-8')
          .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end
end
