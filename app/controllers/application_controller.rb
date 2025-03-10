class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  include SupabaseUserContext
  
  # Require authentication for all actions by default
  before_action :authenticate_user!
  
  helper_method :current_user
  
  protected
  
  # Authentication required
  def authenticate_user!
    unless current_user
      respond_to do |format|
        format.html { redirect_to login_path, alert: 'You need to sign in or sign up before continuing.' }
        format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
      end
      return false
    end
    true
  end
  
  # Helper method to check if user has permission for a resource
  def authorize_resource!(resource, permission_level)
    return true if current_user&.admin?
    
    unless current_user&.has_permission?(resource, permission_level)
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'You are not authorized to perform this action.' }
        format.json { render json: { error: 'Forbidden' }, status: :forbidden }
      end
      return false
    end
    
    true
  end
  
  # Helper method to set up shared link access
  def authorize_shared_link!(token, action = :view)
    # Use the without_rls method to bypass RLS when fetching shared link
    shared_link = SharedLink.find_by_token_without_rls(token)
    
    unless shared_link&.valid_for_use? && shared_link&.allows_action?(action)
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Invalid or expired link.' }
        format.json { render json: { error: 'Invalid or expired link' }, status: :forbidden }
      end
      return false
    end
    
    # Record use of the shared link
    shared_link.record_use!
    
    # Store the shared_link in the request for later use
    @shared_link = shared_link
    true
  end
end
