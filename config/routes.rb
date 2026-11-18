require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  root "posts#index"

  # --- Authentication / account -------------------------------------------------
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resource :registration, only: %i[new create]
  resource :profile, only: %i[show edit update]

  # --- Blog ---------------------------------------------------------------------
  resources :posts, only: %i[index show], param: :slug do
    resources :comments, only: %i[create destroy]
  end
  get "categories/:category", to: "posts#index", as: :category
  get "tags/:tag", to: "posts#index", as: :tag

  # --- Newsletter (public) -------------------------------------------------------
  scope "newsletter", as: "newsletter" do
    resources :subscriptions, only: :create
    get "confirm/:token", to: "subscriptions#confirm", as: :confirmation
    get "unsubscribe/:token", to: "unsubscribes#show", as: :unsubscribe
    post "unsubscribe/:token", to: "unsubscribes#create"
  end

  # --- Admin ----------------------------------------------------------------------
  namespace :admin do
    root "dashboard#show"
    resources :posts, param: :slug do
      member do
        post :publish
        post :unpublish
      end
    end
    resources :categories, param: :slug, except: %i[show new]
    resources :comments, only: %i[index update destroy]
    resources :subscribers, only: %i[index update destroy]
    resources :campaigns do
      member do
        post :schedule
        post :unschedule
        post :cancel
        post :retry_failed
      end
    end
    resources :users, only: %i[index update]
  end

  # Sidekiq dashboard (queues, retries, dead set, cron). Only reachable by admins: the
  # constraint resolves the same signed session cookie used by the Authentication concern.
  constraints(AdminConstraint.new) do
    mount Sidekiq::Web => "/admin/sidekiq"
  end

  # --- Health -----------------------------------------------------------------------
  # /up: process is alive (load balancers). /health: PostgreSQL + Redis reachable.
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"
end
