Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  get "workspace", to: "workspace_selections#show", as: :workspace_selection
  patch "workspace", to: "workspace_selections#update", as: :workspace_select

  namespace :staff do
    root to: "home#show"
  end

  namespace :client do
    root to: "home#show"
  end
end
