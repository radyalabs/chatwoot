# frozen_string_literal: true

# Sync DIRECT_UPLOADS_ENABLED setting from environment variable
# This allows setting DIRECT_UPLOADS_ENABLED=true in .env file
# instead of manually updating the database
Rails.application.config.after_initialize do
  if ENV['DIRECT_UPLOADS_ENABLED'].present?
    begin
      direct_uploads_config = InstallationConfig.find_by(name: 'DIRECT_UPLOADS_ENABLED')
      if direct_uploads_config
        new_value = ENV['DIRECT_UPLOADS_ENABLED'] == 'true'
        if direct_uploads_config.value != new_value
          direct_uploads_config.value = new_value
          direct_uploads_config.save!
          GlobalConfig.clear_cache
          Rails.logger.info "[DirectUploads] Updated DIRECT_UPLOADS_ENABLED to #{new_value} from ENV"
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid => e
      # Database might not exist yet (during db:create or db:migrate)
      Rails.logger.debug "[DirectUploads] Skipping sync: #{e.message}"
    end
  end
end
