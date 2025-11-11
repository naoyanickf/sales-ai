class User < ApplicationRecord
  has_many :workspace_users, dependent: :destroy
  has_many :workspaces, through: :workspace_users

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable
end
