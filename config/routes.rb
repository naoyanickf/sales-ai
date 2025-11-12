Rails.application.routes.draw do
  devise_for :users
  get "dev/react"
  resource :profile, only: %i[new create edit update destroy] do
    patch :email
    patch :password
  end
  resources :products do
    resources :product_documents, only: %i[create destroy]
    resources :sales_experts, only: %i[create destroy] do
      resources :expert_knowledges, only: %i[create destroy]
    end
  end
  resources :workspaces, only: %i[new create show update destroy], param: :uuid do
    resources :invitations, only: :create, controller: :workspace_invitations
  end
  post "workspaces/switch", to: "workspace_switches#create", as: :switch_workspace
  get "invitations/:token/accept", to: "invitations#accept", as: :accept_invitation
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  authenticated :user do
    root "mypage#index", as: :authenticated_root
  end

  unauthenticated do
    # Defines the root path route ("/")
    root "home#index"
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
