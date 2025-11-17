module Gemini
  class DeleteExpertKnowledgeDocumentJob < ApplicationJob
    queue_as :gemini

    def perform(store_name:, document_id:)
      return unless GeminiFileSearchClient.configured?
      return if store_name.blank? || document_id.blank?

      client = GeminiFileSearchClient.new
      client.delete_document(store_name: store_name, document_id: document_id, force: true)
    rescue GeminiFileSearchClient::Error => e
      Rails.logger.warn("[Gemini] Failed to delete expert knowledge document #{document_id}: #{e.class} #{e.message}")
    end
  end
end
