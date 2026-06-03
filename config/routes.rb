Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Auth — signup, login-por-decrypt (SPEC §6.1–6.2, §7).
  get "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"
  get "login", to: "sessions#new", as: :login
  resource :session, only: [:create, :destroy]

  resources :vault_entries
  resources :projects, only: [:index, :show, :new, :create, :destroy] do
    member { post :import_env }
  end
  resources :access_tokens, only: [:index, :create, :destroy]

  # API JSON da skill /antired — autenticada por token (Bearer).
  namespace :api do
    namespace :v1 do
      get "projects", to: "projects#index"
      get "projects/:name/env", to: "projects#env", as: :project_env, constraints: { name: %r{[^/]+} }
    end
  end

  # Defines the root path route ("/")
  root "vault_entries#index"
end
