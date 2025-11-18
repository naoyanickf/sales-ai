module Gemini
  class SyncExpertKnowledgeFileJob < ApplicationJob
    queue_as :gemini

    OPERATION_POLL_INTERVAL = 5.seconds
    OPERATION_TIMEOUT = 10.minutes
    STORE_RETRY_WAIT = 1.minute
    STORE_RETRY_ATTEMPTS = 5

    class StoreNotReadyError < StandardError; end
    class MissingTranscriptError < StandardError; end

    def perform(expert_knowledge_file_id)
      return unless GeminiFileSearchClient.configured?

      @knowledge_file = ExpertKnowledgeFile.includes(expert_knowledge: :sales_expert).find_by(id: expert_knowledge_file_id)
      return unless knowledge_file

      ensure_txt_present!
      ensure_store_ready!

      mark_processing!

      previous_document_id = knowledge_file.gemini_file_id
      operation = upload_txt!
      operation_name = operation["name"].to_s
      knowledge_file.update_column(:gemini_operation_name, operation_name) if operation_name.present?
      result = wait_for_operation(operation_name)
      document_name = extract_document_name(result)

      knowledge_file.update!(
        gemini_file_status: :ready,
        gemini_file_error: nil,
        gemini_uploaded_at: Time.current,
        gemini_file_id: document_name.presence || knowledge_file.gemini_file_id,
        gemini_file_uri: document_name.presence || knowledge_file.gemini_file_uri
      )
      delete_existing_document(previous_document_id)
    rescue StoreNotReadyError => e
      retry_when_store_pending(e)
    rescue MissingTranscriptError => e
      mark_failed!(e.message)
      raise
    rescue GeminiFileSearchClient::Error, StandardError => e
      mark_failed!(e.message)
      raise
    ensure
      @knowledge_file = nil
    end

    private

    attr_reader :knowledge_file

    def expert_knowledge
      knowledge_file.expert_knowledge
    end

    def sales_expert
      expert_knowledge.sales_expert
    end

    def client
      @client ||= GeminiFileSearchClient.new
    end

    def ensure_txt_present!
      raise MissingTranscriptError, "txt が生成されていません" if knowledge_file.txt_body.blank?
    end

    def ensure_store_ready!
      raise StoreNotReadyError, "Gemini store が未作成です" unless sales_expert&.gemini_store_id.present?
      raise StoreNotReadyError, "Gemini store が準備中です" unless sales_expert.gemini_store_available?
    end

    def mark_processing!
      knowledge_file.update!(
        gemini_file_status: :processing,
        gemini_file_error: nil
      )
    end

    def upload_txt!
      Tempfile.create(["expert-knowledge-#{knowledge_file.id}", ".txt"]) do |tmp|
        tmp.binmode
        tmp.write(knowledge_file.txt_body.to_s)
        tmp.rewind
        client.upload_file_to_store(
          store_name: sales_expert.gemini_store_id,
          io: tmp,
          filename: knowledge_file.txt_filename,
          mime_type: "text/plain",
          display_name: knowledge_file.display_name,
          custom_metadata: custom_metadata,
          chunking_config: chunking_config,
          file_size: tmp.size
        )
      end
    end

    def custom_metadata
      [
        { key: "expert_knowledge_id", stringValue: expert_knowledge.id.to_s },
        { key: "sales_expert_id", stringValue: sales_expert.id.to_s },
        { key: "product_id", stringValue: sales_expert.product_id.to_s }
      ]
    end

    def chunking_config
      {
        "chunkSizeTokens" => 512,
        "maxOverlapTokens" => 32
      }
    end

    def wait_for_operation(operation_name)
      name = operation_name.to_s
      raise StandardError, "Gemini アップロードの operation 名が空です" if name.blank?

      operation_id = name.split("/").last
      deadline = Time.current + OPERATION_TIMEOUT

      loop do
        result = client.get_operation(sales_expert.gemini_store_id, operation_id)
        return result if operation_done?(result)

        raise StandardError, "Gemini operation timeout" if Time.current >= deadline
        sleep OPERATION_POLL_INTERVAL
      end
    end

    def operation_done?(result)
      done = result["done"]
      return false unless done

      error = result["error"]
      raise StandardError, error["message"] if error.present?

      true
    end

    def extract_document_name(result)
      response = result["response"] || {}
      response.dig("document", "name") || response["name"]
    end

    def mark_failed!(message)
      knowledge_file.update(
        gemini_file_status: :failed,
        gemini_file_error: message,
        gemini_uploaded_at: nil
      )
    end

    def delete_existing_document(previous_document_id)
      return if previous_document_id.blank?

      client.delete_document(
        store_name: sales_expert.gemini_store_id,
        document_id: previous_document_id,
        force: true
      )
    rescue GeminiFileSearchClient::Error => e
      Rails.logger.warn("[Gemini] Failed to delete existing document #{previous_document_id}: #{e.class} #{e.message}")
    end

    def retry_when_store_pending(error)
      begin
        sales_expert.provision_gemini_store! if sales_expert&.persisted?
      rescue StandardError => e
        Rails.logger.error("[Gemini] Store provisioning failed for SalesExpert##{sales_expert&.id}: #{e.class} #{e.message}")
      end
      if executions < STORE_RETRY_ATTEMPTS
        knowledge_file.update(
          gemini_file_status: :pending,
          gemini_file_error: error.message
        )
        retry_job wait: STORE_RETRY_WAIT
      else
        mark_failed!(error.message)
        raise
      end
    end
  end
end
