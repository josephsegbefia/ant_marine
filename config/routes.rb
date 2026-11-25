Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check
  get "ready" => "readiness#show", as: :readiness_check

  root "home#index"

  get "services", to: "public/services#index", as: :public_services
  get "services/:slug", to: "public/services#show", as: :public_service
  get "about", to: "public/pages#show", defaults: { page: "about" }, as: :about
  get "industries", to: "public/pages#show", defaults: { page: "industries" }, as: :industries
  get "how-we-work", to: "public/pages#show", defaults: { page: "how-we-work" }, as: :how_we_work
  get "contact", to: "public/pages#show", defaults: { page: "contact" }, as: :contact
  get "request-a-quote", to: "public/service_inquiries#new", as: :public_enquiry
  post "request-a-quote", to: "public/service_inquiries#create"
  get "request-a-quote/received", to: "public/service_inquiries#received", as: :public_enquiry_received
  get "insights", to: "public/articles#index", as: :public_insights
  get "insights/:slug", to: "public/articles#show", as: :public_insight
  get "projects", to: "public/case_studies#index", as: :public_projects
  get "projects/:slug", to: "public/case_studies#show", as: :public_project
  get "training", to: "public/training_offerings#index", as: :public_training
  get "training/:slug", to: "public/training_offerings#show", as: :public_training_offering
  get "resources", to: "public/resources#index", as: :public_resources
  get "resources/:slug", to: "public/resources#show", as: :public_resource
  get "sitemap", to: "public/sitemap#show", defaults: { format: :xml }, as: :sitemap
  get "robots", to: "public/robots#show", defaults: { format: :txt }, as: :robots

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
    resources :service_inquiries, path: "enquiries", only: %i[index show] do
      member do
        post :prepare_quotation
      end
    end
    resources :quotations, except: :destroy do
      member do
        post :submit_for_review
        post :return_for_correction
        post :approve
        post :issue
        post :withdraw
        post :create_revision
        get :pdf
        get "versions/:version_number", action: :version, as: :version, constraints: { version_number: /\d+/ }
      end
    end
    namespace :website do
      resources :services do
        member do
          post :submit_for_review
          post :withdraw
          post :approve
          post :publish
          post :unpublish
          post :archive
        end
      end
      resources :pages, only: %i[index show edit update] do
        member do
          post :submit_for_review
          post :withdraw
          post :approve
          post :publish
          post :unpublish
          post :archive
        end
      end
      %i[articles case_studies training_offerings public_resources].each do |resource_key|
        resources resource_key do
          member do
            post :submit_for_review
            post :withdraw
            post :approve
            post :publish
            post :unpublish
            post :archive
          end
        end
      end
    end
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
