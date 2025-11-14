module ChatContextLoader
  extend ActiveSupport::Concern

  private

  def load_chat_products
    current_workspace.products.order(:name)
  end

  def load_sales_experts_for(product_id)
    return SalesExpert.none unless product_id

    current_workspace
      .products
      .find_by(id: product_id)
      &.sales_experts
      &.where(is_active: true)
      &.order(:name) || SalesExpert.none
  end

  def load_workspace_sales_experts
    return SalesExpert.none unless current_workspace

    SalesExpert
      .joins(:product)
      .where(products: { workspace_id: current_workspace.id }, sales_experts: { is_active: true })
      .order(:name)
  end
end
