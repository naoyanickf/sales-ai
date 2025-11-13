module Gemini
  class SyncProductDocumentJob < ApplicationJob
    queue_as :gemini

    STORE_RETRY_WAIT = 30.seconds
    STORE_RETRY_ATTEMPTS = 10
    OPERATION_POLL_INTERVAL = 5.seconds
    OPERATION_TIMEOUT = 10.minutes

    class StoreNotReadyError < StandardError; end
    class OperationError < StandardError; end

    def perform(product_document_id)
      return unless GeminiFileSearchClient.configured?

      @document = ProductDocument.with_attached_file.find_by(id: product_document_id)
      return unless document

      ensure_file_attached!
      ensure_store_ready!

      mark_processing!

      store_id = document.product.gemini_data_store_id
      client = GeminiFileSearchClient.new
      operation = upload_document(client, store_id)
      operation_name = operation["name"]
      document.update_column(:gemini_operation_name, operation_name) if operation_name.present?

      result = wait_for_operation(client, store_id, operation_name)
      gemini_document_name = extract_document_name(result)

      document.update!(
        gemini_sync_status: :synced,
        gemini_document_id: gemini_document_name.presence || document.gemini_document_id,
        gemini_synced_at: Time.current,
        gemini_sync_error: nil
      )
    rescue StoreNotReadyError => e
      handle_store_not_ready(e)
    rescue GeminiFileSearchClient::Error, OperationError => e
      mark_failed!(e.message)
      raise
    rescue StandardError => e
      mark_failed!(e.message)
      raise
    ensure
      @document = nil
    end

    private

    attr_reader :document

    def ensure_file_attached!
      return if document.file.attached?

      raise OperationError, "ProductDocument ##{document.id} has no file to sync"
    end

    def ensure_store_ready!
      product = document.product
      return if product&.gemini_store_available?

      raise StoreNotReadyError, "Gemini data store is not ready (status: #{product&.gemini_data_store_status || 'unknown'})"
    end

    def mark_processing!
      document.update!(
        gemini_sync_status: :processing,
        gemini_sync_error: nil
      )
    end

    def upload_document(client, store_id)
      document.file.open do |io|
        client.upload_file_to_store(
          store_name: store_id,
          io: io,
          filename: document.file.filename.to_s,
          mime_type: document.file.content_type || "application/octet-stream",
          display_name: document.document_name.presence || document.file.filename.to_s,
          custom_metadata: custom_metadata,
          chunking_config: chunking_config,
          file_size: document.file.blob.byte_size
        )
      end
    end

    def custom_metadata
      [
        { key: "product_document_id", stringValue: document.id.to_s },
        { key: "product_id", stringValue: document.product_id.to_s },
        { key: "workspace_id", stringValue: document.workspace.id.to_s }
      ]
    end

    def chunking_config
      {
        "chunkSizeTokens" => 512,
        "maxOverlapTokens" => 32
      }
    end

    def wait_for_operation(client, store_id, operation_name)
      operation_id = extract_operation_id(operation_name)
      deadline = Time.current + OPERATION_TIMEOUT

      loop do
        result = client.get_operation(store_id, operation_id)
        return result if operation_complete?(result)

        raise OperationError, "Gemini operation timed out" if Time.current >= deadline
        sleep OPERATION_POLL_INTERVAL
      end
    end

    def operation_complete?(result)
      done = result["done"]
      return false unless done

      error = result["error"]
      raise OperationError, error["message"] if error.present?

      true
    end

    def extract_operation_id(operation_name)
      name = operation_name.to_s
      raise OperationError, "Gemini upload did not return an operation name" if name.blank?

      name.split("/").last
    end

    def extract_document_name(result)
      response = result["response"] || {}
      response["document"]&.dig("name") || response["name"]
    end

    def handle_store_not_ready(error)
      return unless document

      if executions < STORE_RETRY_ATTEMPTS
        document.update_columns(
          gemini_sync_status: ProductDocument.gemini_sync_statuses[:queued],
          gemini_sync_error: error.message
        )
        retry_job wait: STORE_RETRY_WAIT
      else
        mark_failed!(error.message)
      end
    end

    def mark_failed!(message)
      return unless document&.persisted?

      document.update_columns(
        gemini_sync_status: ProductDocument.gemini_sync_statuses[:failed],
        gemini_sync_error: message,
        gemini_synced_at: nil
      )
    end
  end
end
