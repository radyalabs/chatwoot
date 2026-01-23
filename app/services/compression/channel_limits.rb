# frozen_string_literal: true

module Compression
  class ChannelLimits
    LIMITS = {
      'whatsapp' => {
        image: 5.megabytes,
        audio: 16.megabytes,
        video: 16.megabytes,
        file: 100.megabytes
      },
      'whatsapp_unofficial' => {
        image: 5.megabytes,
        audio: 16.megabytes,
        video: 16.megabytes,
        file: 100.megabytes
      },
      'telegram' => {
        image: 10.megabytes,
        audio: 50.megabytes,
        video: 50.megabytes,
        file: 50.megabytes
      },
      'instagram' => {
        image: 8.megabytes,
        audio: nil,
        video: 25.megabytes,
        file: nil
      },
      'facebook' => {
        image: 25.megabytes,
        audio: 25.megabytes,
        video: 25.megabytes,
        file: 25.megabytes
      },
      'line' => {
        image: 10.megabytes,
        audio: 200.megabytes,
        video: 200.megabytes,
        file: 300.megabytes
      }
    }.freeze

    DEFAULT_LIMIT = 40.megabytes

    ChannelLimit = Struct.new(:max_size, :supported, keyword_init: true)

    def self.for(channel_type, file_type)
      channel_key = normalize_channel(channel_type)
      file_key = normalize_file_type(file_type)

      limit = LIMITS.dig(channel_key, file_key)

      ChannelLimit.new(
        max_size: limit || DEFAULT_LIMIT,
        supported: !limit.nil?
      )
    end

    def self.normalize_channel(channel_type)
      channel_type.to_s.downcase.gsub('::', '_').gsub('channel_', '')
    end

    def self.normalize_file_type(file_type)
      file_type.to_s.to_sym
    end
  end
end
