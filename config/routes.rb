Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check
  get "ready" => "readiness#show", as: :readiness_check

  root "home#index"

  get "workspace", to: "workspace_selections#show", as: :workspace_selection
  patch "workspace", to: "workspace_selections#update", as: :workspace_select

  get "invitations/:token", to: "invitations#show", as: :invitation
  post "invitations/:token/continue", to: "invitations#continue", as: :invitation_continue
  get "invitations/:token/setup", to: "invitations#setup", as: :invitation_setup
  post "invitations/:token/setup", to: "invitations#complete_setup"

  namespace :staff do
    root to: "home#show"
    namespace :storage do
      resources :proof_uploads, only: :create
      resources :proof_downloads, only: :show
    end
    resources :invitations, only: %i[index create destroy] do
      member do
        post :resend
      end
    end
    resources :client_invitations, only: %i[new create]
  end

  namespace :client do
    root to: "home#show"
    resources :invitations, only: %i[index create destroy] do
      member do
        post :resend
      end
    end
  end
end
