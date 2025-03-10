class SessionsController < ApplicationController
  # Skip authentication for login pages
  skip_before_action :authenticate_user!, only: [:new, :create]
  
  def new
    # Login form
  end

  def create
    user = User.authenticate(params[:email], params[:password])
    
    if user
      # Set session
      session[:user_id] = user.id
      
      # Update last login timestamp
      user.update(last_login_at: Time.current)
      
      redirect_to root_path, notice: "Logged in successfully!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # Clear session
    session[:user_id] = nil
    
    # Clear thread-local current user
    CurrentUser.id = nil
    
    redirect_to login_path, notice: "Logged out successfully!"
  end
end
