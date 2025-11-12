module ProductShowContext
  extend ActiveSupport::Concern

  private

  def prepare_product_show_context(product)
    @product_documents = product.product_documents
                                .with_attached_file
                                .includes(:uploader)
                                .order(created_at: :desc)
    @sales_experts = product.sales_experts
                            .includes(:product)
                            .includes(expert_knowledges: [
                              :uploader,
                              { file_attachment: :blob }
                            ])
                            .order(created_at: :desc)
    @product_document ||= ProductDocument.new
    @sales_expert ||= SalesExpert.new
    @expert_knowledge ||= ExpertKnowledge.new
    @sales_expert_with_error = nil unless defined?(@sales_expert_with_error)
  end
end
