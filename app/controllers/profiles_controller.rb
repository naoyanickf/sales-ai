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

  def email
    if update_email
      message = if @user.respond_to?(:pending_reconfirmation?) && @user.pending_reconfirmation?
                  "メールアドレスの変更はまだ完了していません。届いた確認メールをご確認ください。"
                else
                  "メールアドレスを更新しました。"
                end
      redirect_to edit_profile_path, notice: message
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def password
    if update_password
      bypass_sign_in(@user)
      redirect_to edit_profile_path, notice: "パスワードを更新しました。"
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

  def email_params
    params.fetch(:user, ActionController::Parameters.new).permit(:email)
  end

  def password_params
    params.fetch(:user, ActionController::Parameters.new).permit(:current_password, :password, :password_confirmation)
  end

  def update_name
    name = profile_params[:name].to_s.strip
    if name.blank?
      @user.errors.add(:name, "を入力してください")
      return false
    end

    @user.update(name: name)
  end

  def update_email
    email = email_params[:email].to_s.strip
    if email.blank?
      @user.errors.add(:email, "を入力してください")
      return false
    end

    @user.update(email: email)
  end

  def update_password
    current = password_params[:current_password].to_s
    new_password = password_params[:password].to_s
    confirm = password_params[:password_confirmation].to_s

    if current.blank? || !@user.valid_password?(current)
      @password_error = "現在のパスワードが正しくありません。"
      return false
    end

    if new_password.blank?
      @user.errors.add(:password, "を入力してください")
      return false
    end

    unless new_password == confirm
      @user.errors.add(:password_confirmation, "が一致しません")
      return false
    end

    @user.update(password: new_password, password_confirmation: confirm)
  end

  def redirect_if_name_present
    redirect_to edit_profile_path if current_user.name.present?
  end
end
