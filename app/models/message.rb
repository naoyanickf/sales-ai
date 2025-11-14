class Message < ApplicationRecord
  include ActionView::RecordIdentifier

  enum :role, { system: 0, assistant: 10, user: 20 }

  belongs_to :chat

  scope :ordered, -> { order(:created_at, :id) }

  after_create_commit -> { broadcast_created }
  after_update_commit -> { broadcast_updated }

  validates :content, presence: true, if: :user?

  def self.for_openai(messages)
    chat = extract_chat(messages)
    return [] if chat.nil?

    payload = [{ role: "system", content: chat.system_prompt }]
    collection = ordered_collection(messages)
    collection.each do |message|
      payload << { role: message.role, content: message.content }
    end
    payload
  end

  def broadcast_created
    broadcast_append_later_to(
      stream_name,
      partial: "messages/message",
      locals: { message: self, scroll_to: true },
      target: stream_target
    )
  end

  def broadcast_updated
    broadcast_replace_later_to(
      stream_name,
      partial: "messages/message",
      locals: { message: self, scroll_to: false },
      target: message_dom_id
    )
  end

  private

  def stream_name
    "#{dom_id(chat)}_messages"
  end

  def stream_target
    "#{dom_id(chat)}_messages"
  end

  def message_dom_id
    "#{dom_id(self)}_messages"
  end

  def self.extract_chat(messages)
    if messages.respond_to?(:proxy_association)
      messages.proxy_association&.owner
    elsif messages.respond_to?(:first)
      messages.first&.chat
    end
  end

  def self.ordered_collection(messages)
    if messages.respond_to?(:ordered)
      messages.ordered
    else
      Array(messages).sort_by { |message| [message.created_at || Time.current, message.id || 0] }
    end
  end
end
