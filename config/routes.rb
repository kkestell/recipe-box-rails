Rails.application.routes.draw do
  get "help", to: "pages#help"
  # Defines the root path route ("/")
  root "pages#home"

  # Routes for user sign-up and profile editing
  get "sign_up", to: "users#new"
  get "profile", to: "users#edit"

  resources :users do
    resources :recipes, controller: "users/recipes", only: [ :index ] do
      collection do
        # Defines GET /users/:user_id/recipes/cookbook (to show the form)
        get :cookbook
        # Defines POST /users/:user_id/recipes/cookbook (to generate the PDF)
        post :cookbook, action: :create_cookbook
      end
    end
  end

  # Routes for session management (login/logout)
  # This one line creates all the necessary routes for logging in and out.
  # GET    /session/new  -> sessions#new
  # POST   /session      -> sessions#create
  # DELETE /session      -> sessions#destroy
  resource :session, only: [:new, :create, :destroy]

  # Routes for password reset
  resources :passwords, only: [:new, :create, :edit, :update], param: :token

  # Recipe routes
  resources :recipes do
    get "pdf", on: :member
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
