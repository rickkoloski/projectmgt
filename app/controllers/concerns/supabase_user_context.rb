# frozen_string_literal: true

module SupabaseUserContext
  extend ActiveSupport::Concern
  
  included do
    before_action :set_supabase_user_context
  end
  
  private
  
  # Set the current user ID in the PostgreSQL session for RLS
  def set_supabase_user_context
    if current_user
      # Set the current user ID for RLS policies
      CurrentUser.id = current_user.id
      ActiveRecord::Base.connection.execute("SELECT set_config('app.current_user_id', '#{current_user.id}', false)")
    else
      # Clear the user ID if no user is logged in
      CurrentUser.id = nil
      ActiveRecord::Base.connection.execute("SELECT set_config('app.current_user_id', '', false)")
    end
  end
  
  # Get the current user from the session or token
  def current_user
    @current_user ||= begin
      if session[:user_id]
        # Session-based authentication
        User.find_by(id: session[:user_id])
      elsif request.headers['Authorization']
        # Token-based authentication
        authenticate_with_token
      end
    end
  end
  
  # Check if a user is logged in
  def authenticate_user!
    unless current_user
      respond_to do |format|
        format.html { redirect_to login_path, alert: 'You need to sign in or sign up before continuing.' }
        format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
      end
    end
  end
  
  # Authenticate with JWT token from Supabase
  def authenticate_with_token
    token = request.headers['Authorization'].to_s.split(' ').last
    return nil if token.blank?
    
    begin
      decoded_token = JWT.decode(token, ENV['SUPABASE_JWT_SECRET'], true, { algorithm: 'HS256' })
      user_id = decoded_token.first['sub']
      User.find_by(id: user_id)
    rescue JWT::DecodeError
      nil
    end
  end
end