# == Schema Information
#
# Table name: knowledge_source_files
#
#  id                  :bigint           not null, primary key
#  file_name           :string
#  file_size           :integer
#  file_type           :string
#  source_config       :jsonb            not null
#  total_chars         :integer          default(0), not null
#  total_chunks        :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ai_agent_name_id    :string
#  knowledge_source_id :bigint           not null
#  loader_id           :string           not null
#
# Indexes
#
#  index_knowledge_source_files_on_knowledge_source_id  (knowledge_source_id)
#
# Foreign Keys
#
#  fk_rails_...  (knowledge_source_id => knowledge_sources.id)
#
class KnowledgeSourceFile < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :knowledge_source
  has_one_attached :file

  validates :loader_id, presence: true
  validates :file_name, presence: true
  validate :acceptable_file

  ACCEPTABLE_TYPES = %w[
    application/pdf
    text/plain
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ].freeze
  MAX_FILE_SIZE = 50.megabytes

  def preview_url(expires_in: 1.hour)
    return nil unless file.attached?

    rails_blob_url(file, expires_in: expires_in, disposition: 'inline')
  end

  def download_url(expires_in: 1.hour)
    return nil unless file.attached?

    rails_blob_url(file, expires_in: expires_in, disposition: 'attachment')
  end

  private

  def acceptable_file
    return unless file.attached?

    validate_type
    validate_size
  end

  def validate_size
    errors.add(:file, 'size too large') if file.byte_size > MAX_FILE_SIZE
  end

  def validate_type
    errors.add(:file, 'type not supported') unless ACCEPTABLE_TYPES.include?(file.content_type)
  end
end
