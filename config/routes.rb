Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "d/:token" => "public_documents#show", as: :public_document

  root "dashboard#show"
  get "search" => "search#index"

  resources :orders do
    member { post :confirm; post :convert; post :cancel }
    collection { post :parse }
  end
  get "counter" => "counter#new", as: :counter
  post "counter" => "counter#create"
  get "counter/lookup" => "counter#lookup", as: :counter_lookup

  resources :invoices, only: %i[index show new create] do
    member { post :cancel; post :send_whatsapp; patch :eway }
    resources :credit_notes, only: %i[new create]
  end
  resources :credit_notes, only: %i[index show]
  resources :payments, only: %i[index show new create] do
    member { post :bounce; post :send_receipt }
  end
  resources :customers do
    member { get :statement; post :send_statement; get :visit }
    collection { get :import, action: :import_form; post :import }
  end
  resources :suppliers do
    resources :supplier_payments, only: %i[create]
  end
  resources :products do
    collection { get :import, action: :import_form; post :import; get :reorder; post :apply_reorder }
  end
  get "stock" => "stock#index", as: :stock
  get "stock/movements" => "stock#movements", as: :stock_movements
  resources :purchases, only: %i[index show new create]
  resources :stock_counts, only: %i[index show new create update] do
    member { post :post_count }
  end
  resources :replacements, only: %i[index show new create] do
    collection { get :warranty }
    member { post :write_off }
  end
  resources :brand_claims, only: %i[index show new create] do
    member { post :send_claim; post :settle; get :challan }
  end
  resources :dispatch_runs, only: %i[index show create update] do
    member { post :add; delete :remove; post :start; post :finish }
  end
  resources :deliveries, only: %i[update]
  resources :approvals, only: %i[index] do
    member { post :approve; post :reject }
  end

  namespace :whatsapp do
    resources :messages, only: %i[index show create]
    resources :broadcasts, only: %i[index new create show] do
      member { post :deliver }
    end
    get "webhook" => "webhooks#verify"
    post "webhook" => "webhooks#receive"
    post "simulate" => "webhooks#simulate"
  end

  get "reports" => "reports#index", as: :reports
  get "reports/sales" => "reports#sales", as: :sales_report
  get "reports/dues" => "reports#dues", as: :dues_report
  get "reports/collections" => "reports#collections", as: :collections_report
  get "reports/gstr1" => "reports#gstr1", as: :gstr1_report
  get "reports/gstr3b" => "reports#gstr3b", as: :gstr3b_report
  get "reports/hsn" => "reports#hsn", as: :hsn_report
  get "reports/tally" => "reports#tally", as: :tally_export
  get "reports/ca_pack" => "reports#ca_pack", as: :ca_pack
  get "reports/day_book" => "reports#day_book", as: :day_book

  resource :settings, only: %i[show update]
  resources :users, except: %i[show destroy]
  resources :markets, except: %i[show]
  resources :brands, except: %i[show]
  resources :audit_events, only: %i[index]

  # phone app for salesmen and delivery staff (installable, works offline)
  namespace :m do
    root "home#show"
    get "offline" => "home#offline"
    resources :customers, only: %i[index show]
    get "catalog" => "sync#catalog"
    post "sync" => "sync#push"
    resources :orders, only: %i[new create]
    resources :payments, only: %i[new create]
    resources :replacements, only: %i[new create]
    get "route" => "route#show", as: :route
    resources :drops, only: %i[show update], controller: "route"
  end
end
