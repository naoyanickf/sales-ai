# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_18_103000) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
    t.index ["blob_id"], name: "index_active_storage_variant_records_on_blob_id"
  end

  create_table "chat_prompt_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.datetime "created_at", null: false
    t.text "payload", size: :medium
    t.datetime "updated_at", null: false
    t.index ["chat_id", "created_at"], name: "index_chat_prompt_logs_on_chat_id_and_created_at"
    t.index ["chat_id"], name: "index_chat_prompt_logs_on_chat_id"
  end

  create_table "chats", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "last_prompt_payload", size: :medium
    t.bigint "product_id"
    t.bigint "sales_expert_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "uuid", null: false
    t.bigint "workspace_id", null: false
    t.index ["product_id"], name: "index_chats_on_product_id"
    t.index ["sales_expert_id"], name: "index_chats_on_sales_expert_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
    t.index ["uuid"], name: "index_chats_on_uuid", unique: true
    t.index ["workspace_id", "user_id", "created_at"], name: "index_chats_on_workspace_id_and_user_id_and_created_at"
    t.index ["workspace_id"], name: "index_chats_on_workspace_id"
  end

  create_table "expert_knowledge_files", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "expert_knowledge_id", null: false
    t.text "gemini_file_error"
    t.string "gemini_file_id"
    t.string "gemini_file_status", default: "pending", null: false
    t.string "gemini_file_uri"
    t.string "gemini_operation_name"
    t.datetime "gemini_uploaded_at"
    t.integer "segment_count", default: 0, null: false
    t.text "txt_body", size: :medium
    t.datetime "txt_generated_at"
    t.datetime "updated_at", null: false
    t.index ["expert_knowledge_id"], name: "index_expert_knowledge_files_on_expert_knowledge_id"
    t.index ["gemini_file_id"], name: "index_expert_knowledge_files_on_gemini_file_id", unique: true
  end

  create_table "expert_knowledges", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.string "file_name", null: false
    t.json "metadata"
    t.bigint "sales_expert_id", null: false
    t.datetime "transcription_completed_at"
    t.string "transcription_status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "upload_user_id", null: false
    t.index ["sales_expert_id"], name: "index_expert_knowledges_on_sales_expert_id"
    t.index ["upload_user_id"], name: "index_expert_knowledges_on_upload_user_id"
  end

  create_table "knowledge_chunks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "bedrock_data_source_id"
    t.text "chunk_text"
    t.datetime "created_at", null: false
    t.bigint "expert_knowledge_id", null: false
    t.json "metadata"
    t.json "transcription_segment_ids"
    t.datetime "updated_at", null: false
    t.index ["expert_knowledge_id"], name: "index_knowledge_chunks_on_expert_knowledge_id"
  end

  create_table "messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "response_number", default: 0, null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id", "created_at"], name: "index_messages_on_chat_id_and_created_at"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "product_documents", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "document_name", null: false
    t.string "document_type"
    t.string "gemini_document_id"
    t.string "gemini_operation_name"
    t.text "gemini_sync_error"
    t.string "gemini_sync_status", default: "pending", null: false
    t.datetime "gemini_synced_at"
    t.json "metadata"
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "upload_user_id", null: false
    t.index ["gemini_document_id"], name: "index_product_documents_on_gemini_document_id", unique: true
    t.index ["product_id"], name: "index_product_documents_on_product_id"
    t.index ["upload_user_id"], name: "index_product_documents_on_upload_user_id"
  end

  create_table "products", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.text "gemini_data_store_error"
    t.string "gemini_data_store_id"
    t.string "gemini_data_store_status", default: "pending", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.bigint "workspace_id", null: false
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.index ["gemini_data_store_id"], name: "index_products_on_gemini_data_store_id", unique: true
    t.index ["uuid"], name: "index_products_on_uuid", unique: true
    t.index ["workspace_id", "name"], name: "index_products_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_products_on_workspace_id"
  end

  create_table "sales_experts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "gemini_store_error"
    t.string "gemini_store_id"
    t.string "gemini_store_state", default: "pending", null: false
    t.datetime "gemini_store_synced_at"
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["gemini_store_id"], name: "index_sales_experts_on_gemini_store_id", unique: true
    t.index ["product_id"], name: "index_sales_experts_on_product_id"
  end

  create_table "solid_cable_messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", size: :long, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "transcription_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "expert_knowledge_id", null: false
    t.string "external_job_id"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["expert_knowledge_id"], name: "index_transcription_jobs_on_expert_knowledge_id"
    t.index ["external_job_id"], name: "index_transcription_jobs_on_external_job_id"
    t.index ["status"], name: "index_transcription_jobs_on_status"
  end

  create_table "transcription_segments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.float "confidence"
    t.datetime "created_at", null: false
    t.float "end_time"
    t.integer "sequence_number"
    t.string "speaker_label"
    t.string "speaker_name"
    t.float "start_time"
    t.text "text"
    t.bigint "transcription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["transcription_id", "sequence_number"], name: "idx_on_transcription_id_sequence_number_1e2105d1a7"
    t.index ["transcription_id"], name: "index_transcription_segments_on_transcription_id"
  end

  create_table "transcriptions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "duration_seconds"
    t.bigint "expert_knowledge_id", null: false
    t.text "full_text"
    t.string "language", default: "ja-JP", null: false
    t.integer "speaker_count"
    t.json "structured_data"
    t.datetime "updated_at", null: false
    t.index ["expert_knowledge_id"], name: "index_transcriptions_on_expert_knowledge_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspace_invitations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at"
    t.bigint "invited_user_id"
    t.bigint "inviter_id", null: false
    t.string "role", default: "participant", null: false
    t.string "status", default: "pending", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["invited_user_id"], name: "index_workspace_invitations_on_invited_user_id"
    t.index ["inviter_id"], name: "index_workspace_invitations_on_inviter_id"
    t.index ["token"], name: "index_workspace_invitations_on_token", unique: true
    t.index ["workspace_id", "email", "status"], name: "index_workspace_invites_on_workspace_email_status"
    t.index ["workspace_id"], name: "index_workspace_invitations_on_workspace_id"
  end

  create_table "workspace_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "joined_at", null: false
    t.string "role", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_workspace_users_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_workspace_users_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_workspace_users_on_workspace_id"
  end

  create_table "workspaces", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["uuid"], name: "index_workspaces_on_uuid", unique: true
  end

  add_foreign_key "chat_prompt_logs", "chats"
  add_foreign_key "chats", "products"
  add_foreign_key "chats", "sales_experts"
  add_foreign_key "chats", "users"
  add_foreign_key "chats", "workspaces"
  add_foreign_key "expert_knowledge_files", "expert_knowledges"
  add_foreign_key "expert_knowledges", "sales_experts"
  add_foreign_key "expert_knowledges", "users", column: "upload_user_id"
  add_foreign_key "knowledge_chunks", "expert_knowledges"
  add_foreign_key "messages", "chats"
  add_foreign_key "product_documents", "products"
  add_foreign_key "product_documents", "users", column: "upload_user_id"
  add_foreign_key "products", "workspaces"
  add_foreign_key "sales_experts", "products"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "transcription_jobs", "expert_knowledges"
  add_foreign_key "transcription_segments", "transcriptions"
  add_foreign_key "transcriptions", "expert_knowledges"
  add_foreign_key "workspace_invitations", "users", column: "invited_user_id"
  add_foreign_key "workspace_invitations", "users", column: "inviter_id"
  add_foreign_key "workspace_invitations", "workspaces"
  add_foreign_key "workspace_users", "users"
  add_foreign_key "workspace_users", "workspaces"
end
