class UploadToBedrockKnowledgeBaseJob < ApplicationJob
  queue_as :default

  def perform(expert_knowledge_id)
    expert = ExpertKnowledge.find_by(id: expert_knowledge_id)
    return unless expert
    # Placeholder: invoke BedrockKnowledgeUploader
  end
end

