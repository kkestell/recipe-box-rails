class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  before_action :set_user, only: %i[ edit update ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(create_user_params)
    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Thank you for signing up!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = User.find(params[:id])
  end

  def edit
  end

  def update
    if @user.update(update_user_params)
      redirect_to profile_path, notice: "Your profile was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def create_user_params
    params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
  end

  def update_user_params
    params.expect(user: [ :name, :email_address ])
  end
end
