class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_if_name_present, only: %i[new create]
  before_action :set_user

  def new; end

  def create
    if update_name
      redirect_to root_path, notice: "名前を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if update_name
      redirect_to root_path, notice: "名前を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if params[:confirm_name].to_s.strip != @user.name
      @deletion_error = "確認のために現在の名前を入力してください。"
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.workspace_users.where(role: :admin).joins(:workspace).where(workspaces: { deleted_at: nil }).exists?
      @deletion_error = "管理しているワークスペースがあるため、アカウントを削除できません。"
      render :edit, status: :unprocessable_entity
      return
    end

    @user.destroy!
    sign_out @user
    redirect_to root_path, notice: "アカウントを削除しました。"
  end

  private

  def set_user
    @user = current_user
  end

  def profile_params
    params.fetch(:user, ActionController::Parameters.new).permit(:name)
  end

  def update_name
    name = profile_params[:name].to_s.strip
    if name.blank?
      @user.errors.add(:name, "を入力してください")
      return false
    end

    @user.update(name: name)
  end

  def redirect_if_name_present
    redirect_to edit_profile_path if current_user.name.present?
  end
end
