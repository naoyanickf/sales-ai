class Chat < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  belongs_to :product, optional: true
  belongs_to :sales_expert, optional: true

  has_many :messages, -> { order(:created_at, :id) }, dependent: :destroy
  has_many :prompt_logs, class_name: "ChatPromptLog", dependent: :destroy

  before_validation :assign_uuid, on: :create
  before_validation :assign_product_from_sales_expert
  before_validation :assign_workspace_from_product

  validates :uuid, presence: true, uniqueness: true
  validates :workspace, presence: true
  validates :user, presence: true
  validate :product_belongs_to_workspace
  validate :sales_expert_belongs_to_product

  FALLBACK_TITLE = "無題のチャット".freeze

  def system_prompt
    prompt = +"あなたは営業支援AIアシスタントです。"
    prompt << "ユーザーのワークスペース: #{workspace.name}。" if workspace&.name.present?
    prompt << "取り扱い製品: #{product.name}。" if product&.name.present?
    prompt << "先輩営業マン: #{sales_expert.name}。" if sales_expert&.name.present?
    prompt << "丁寧かつ実践的な営業アドバイスを日本語で返答してください。"
    prompt
  end

  def display_title
    return title if title.present?

    first_message = messages.first
    return first_message.content.truncate(30) if first_message&.content.present?

    FALLBACK_TITLE
  end

  def to_param
    uuid
  end

  def store_prompt_payload!(payload)
    return if payload.nil?

    snapshot = build_prompt_log_snapshot(payload)
    serialized =
      case snapshot
      when String then snapshot
      else
        JSON.pretty_generate(snapshot)
      end
    
    prompt_logs.create!(payload: serialized)
  rescue StandardError => e
    Rails.logger.warn("[Chat] Failed to store prompt payload for Chat##{id}: #{e.class} #{e.message}")
  end

  def build_prompt_log_snapshot(payload)
    history_entries = messages.order(:created_at, :id).each_with_index.map do |message, index|
      {
        order: index + 1,
        role: message.role,
        role_label: prompt_history_label_for(message),
        timestamp: message.created_at&.iso8601,
        display_timestamp: message.created_at ? I18n.l(message.created_at, format: :long) : nil,
        content: message.content.to_s
      }
    end

    {
      prompt: payload,
      history: history_entries
    }
  end

  def prompt_history_label_for(message)
    case message.role.to_s
    when "user"
      "User"
    when "assistant"
      "Sales AI"
    else
      message.role.to_s.titleize
    end
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid_v7
  end

  def assign_product_from_sales_expert
    return if sales_expert.nil?

    self.product ||= sales_expert.product
  end

  def assign_workspace_from_product
    return if product.nil?

    self.workspace ||= product.workspace
  end

  def product_belongs_to_workspace
    return if product.nil?
    return if product.workspace_id == workspace_id

    errors.add(:product, "は選択中のワークスペースに属していません。")
  end

  def sales_expert_belongs_to_product
    return if sales_expert.nil?
    return if product.present? && sales_expert.product_id == product_id

    errors.add(:sales_expert, "は選択した製品に紐づいていません。")
  end
end
