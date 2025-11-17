class ExpertKnowledgeFile < ApplicationRecord
  belongs_to :expert_knowledge

  enum :gemini_file_status, {
    pending: "pending",
    processing: "processing",
    ready: "ready",
    failed: "failed"
  }, suffix: true

  delegate :sales_expert, to: :expert_knowledge

  before_destroy :cache_gemini_store_for_cleanup
  after_destroy_commit :enqueue_gemini_cleanup

  def txt_filename
    base = expert_knowledge.file_name.presence || "expert_knowledge_#{expert_knowledge_id}"
    sanitized = base.gsub(/[^0-9A-Za-z.\-]/, "_")
    "#{sanitized.sub(/\.[^.]+\z/, '')}_transcript.txt"
  end

  def display_name
    "#{sales_expert.name} - #{expert_knowledge.file_name}"
  end

  def txt_io
    StringIO.new(txt_body.to_s)
  end

  private

  attr_reader :store_for_cleanup

  def cache_gemini_store_for_cleanup
    @store_for_cleanup = sales_expert&.gemini_store_id
  end

  def enqueue_gemini_cleanup
    return unless GeminiFileSearchClient.configured?
    return if store_for_cleanup.blank? || gemini_file_id.blank?

    Gemini::DeleteExpertKnowledgeDocumentJob.perform_later(
      store_name: store_for_cleanup,
      document_id: gemini_file_id
    )
  end
end
