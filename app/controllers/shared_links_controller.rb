class SharedLinksController < ApplicationController
  # Skip authentication for shared links
  skip_before_action :authenticate_user!
  before_action :authorize_shared_link!
  
  def show
    @resource = @shared_link.resource
    
    case @shared_link.resource_type
    when 'Task'
      render 'tasks/show'
    when 'Project'
      render 'projects/show'
    else
      redirect_to root_path, alert: "Invalid shared resource type."
    end
  end
  
  private
  
  def authorize_shared_link!
    token = params[:token]
    super(token)
  end
end
