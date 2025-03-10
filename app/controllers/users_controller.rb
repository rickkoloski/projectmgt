class UsersController < ApplicationController
  # Skip authentication for signup
  skip_before_action :authenticate_user!, only: [:new, :create]
  before_action :set_user, only: [:show, :edit, :update]
  before_action :authorize_user!, only: [:edit, :update]
  
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    # Check if this is the first user (make them an admin and create organization)
    if User.count.zero?
      @user.role = 'admin'
      
      # Create a default organization
      org = Organization.new(
        name: "#{@user.name}'s Organization",
        owner_id: nil  # Will be updated after user is saved
      )
      
      if org.valid?
        ActiveRecord::Base.transaction do
          @user.save!
          org.owner_id = @user.id
          org.save!
          @user.update!(organization_id: org.id)
        end
        
        # Log in the user
        session[:user_id] = @user.id
        redirect_to root_path, notice: "Account created successfully!"
      else
        render :new, status: :unprocessable_entity
      end
    else
      if @user.save
        # Log in the user
        session[:user_id] = @user.id
        redirect_to root_path, notice: "Account created successfully!"
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    # Edit form
  end

  def update
    if @user.update(user_params)
      redirect_to @user, notice: "Profile updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    # User profile
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
  
  def authorize_user!
    unless @user == current_user || current_user.admin?
      redirect_to root_path, alert: "You are not authorized to perform this action."
    end
  end
  
  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
