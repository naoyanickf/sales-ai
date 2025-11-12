class TranscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_workspace_admin!
  before_action :set_transcription

  def refine
    TextRefineTranscriptionJob.perform_later(@transcription.id)
    redirect_back fallback_location: product_path(@transcription.expert_knowledge.sales_expert.product),
                  notice: '日本語校正をキューに登録しました。'
  end

  private

  def set_transcription
    @transcription = Transcription.find(params[:id])
    product = @transcription.expert_knowledge.sales_expert.product
    unless product.workspace_id == current_workspace&.id
      redirect_to authenticated_root_path, alert: '権限がありません。'
    end
  end
end

