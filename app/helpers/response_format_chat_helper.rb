module ResponseFormatChatHelper
  include JsonHelper

  def parsed_response(response, is_custom_agent: false)
    response = is_custom_agent ? extract_json_from_code_block(response['text']) : response

    {
      response: normalize_utf8(response&.dig('response')),
      is_handover: response&.dig('is_handover_human') || false,
      is_end_state: response&.dig('is_end_state') || false,
      has_domain_change: response&.dig('has_domain_change') || false
    }
  end

  def normalize_utf8(string)
    string.to_s
          .force_encoding('UTF-8')
          .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end
end
