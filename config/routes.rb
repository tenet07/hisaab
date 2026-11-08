Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest.json" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker.js" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: %i[new create destroy]
  root "dashboard#show"

  resources :products, except: :destroy do
    member { post :adjust }
  end
  resources :customers, except: :destroy do
    member { get :visit; get :statement }
    resources :payments, only: %i[new create]
  end
  resources :invoices, only: %i[index new create show] do
    member { post :cancel }
  end
  resources :markets, only: %i[index new create]
  resources :deliveries, only: %i[index show] do
    collection { get :run; get :summary }
    member { patch :assign; post :load; post :complete; post :fail; post :reschedule; get :photo }
  end
  resources :replacements, only: %i[index new create]
  resources :claims, only: %i[index show create] do
    resources :claim_lines, only: [] do
      member { post :settle }
    end
  end
  resources :suppliers, except: :destroy do
    resources :supplier_payments, only: %i[new create], path: "payments"
  end
  resources :purchase_bills, only: %i[index new create show], path: "purchases"
  resources :claim_credits, only: :create
  resources :imports, only: %i[index create] do
    collection { post :commit; get "template/:kind", action: :template, as: :template }
  end
  resources :users, except: %i[show destroy], path: "staff"
  resource :pin, only: %i[edit update]
  resource :setup, only: %i[new create]
  resource :settings, only: %i[edit update], controller: "shop_settings"
  resources :backups, only: %i[index show], constraints: { id: /[^\/]+/ }, format: false
  get "tally" => "tally#index", as: :tally
  get "tally/export" => "tally#export", as: :tally_export
end
