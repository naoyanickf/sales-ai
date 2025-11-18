class ChatPromptLog < ApplicationRecord
  belongs_to :chat

  scope :recent, -> { order(created_at: :desc) }

  def payload_pretty
    raw = payload.to_s
    return "" if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    raw
  end
end
