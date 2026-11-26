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
    resources :clients, only: %i[index show new create edit update] do
      member do
        post :suspend_membership
        post :revoke_membership
        post :create_contact
        post :archive_contact
      end
      resources :portal_releases, only: %i[create], controller: "client_portal_releases"
    end
    resources :service_inquiries, path: "enquiries", only: %i[index show] do
      member do
        post :prepare_quotation
        post :transition
        post :assign
        get :onboard
        post :onboard, action: :create_onboarding
      end
      resources :notes, only: :create, controller: "service_inquiry_notes" do
        member { post :correct }
      end
      resources :clarifications, only: :create, controller: "service_inquiry_clarifications" do
        member do
          post :record_contact
          post :record_response
          post :withdraw
        end
      end
    end
    resources :notifications, only: :index do
      member do
        post :open
      end
      collection do
        post :mark_all_read
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
      resource :issuance, only: %i[show create], controller: "quotation_issuances" do
        post :deliver
        post :cancel
      end
    end
    resources :projects, only: %i[index show new create] do
      member do
        post :transition
      end
      resources :assignments, only: %i[create destroy], controller: "project_assignments"
      resources :tasks, only: %i[create update], controller: "project_tasks"
      resources :milestones, only: [], controller: "project_milestones" do
        member do
          post :complete
        end
      end
      resources :schedule_events, only: %i[create], controller: "project_schedule_events" do
        member do
          post :confirm
          post :cancel
        end
      end
      resources :updates, only: %i[create], controller: "project_updates"
      resources :documents, only: %i[index show new create], controller: "project_documents" do
        member do
          post :submit_for_review
        end
        resources :versions, only: %i[create], controller: "document_versions" do
          member do
            get :download
            post :review
            post :release
          end
        end
        resources :releases, only: [], controller: "document_releases" do
          member do
            post :revoke
          end
        end
      end
      resources :upload_requests, only: %i[create], controller: "project_upload_requests"
    end
    resources :tasks, only: %i[index], controller: "tasks"
    resources :schedule_events, only: %i[index], controller: "schedule_events"
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
    resources :requests, only: %i[index show], controller: "requests"
    resources :quotations, only: %i[index show] do
      member do
        get :pdf
        get :decide
        post :decide, action: :create_decision
      end
    end
    resources :projects, only: %i[index show] do
      resources :documents, only: %i[index show], controller: "project_documents" do
        member do
          get :download
        end
      end
      resources :upload_requests, only: %i[index show], controller: "upload_requests" do
        member do
          post :submit
        end
      end
    end
    resources :documents, only: %i[index], controller: "documents"
    resource :account, only: %i[show], controller: "accounts"
    resources :invitations, only: %i[index create destroy] do
      member do
        post :resend
      end
    end
  end
end
