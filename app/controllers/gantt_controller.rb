class GanttController < ApplicationController
  # Allow unauthenticated users to see the landing page
  skip_before_action :authenticate_user!, only: [:index, :landing]
  
  def index
    # Check if user is logged in
    if current_user
      # Redirect to dashboard if logged in
      redirect_to dashboard_path
    else
      # For unauthenticated users, show the landing page
      render :landing
    end
  end
  
  def dashboard
    # Ensure user is authenticated
    authenticate_user!
    
    # Check if a specific project is requested
    if params[:project_id].present?
      # Load a specific project if user has access
      @project = Project.find(params[:project_id])
      
      # Verify access
      unless current_user.admin? || 
             (current_user.organization && @project.organization_id == current_user.organization_id) ||
             current_user.has_permission?(@project, 'view')
        redirect_to dashboard_path, alert: 'You do not have permission to access this project.'
        return
      end
      
      @projects = [@project]
      @tasks = @project.tasks
    else
      # Load all projects and tasks for the current user
      @organization = current_user.organization
      
      if @organization
        @projects = @organization.projects
        @tasks = Task.joins(:project)
                     .where(projects: { organization_id: @organization.id })
                     .or(Task.where(creator_id: current_user.id))
                     .or(Task.where(assignee_id: current_user.id))
      else
        # User has no organization, just show their own tasks
        @projects = []
        @tasks = current_user.created_tasks.or(current_user.assigned_tasks)
      end
    end
    
    # Format tasks for the Gantt chart
    @gantt_data = {
      projects: @projects.as_json(only: [:id, :name, :start_date, :end_date, :status]),
      tasks: @tasks.as_json(
        only: [:id, :name, :description, :start_date, :due_date, :status, :priority, :percent_complete],
        include: {
          project: { only: [:id, :name] },
          creator: { only: [:id, :name] },
          assignee: { only: [:id, :name] },
          subtasks: { only: [:id, :name, :percent_complete] }
        }
      )
    }
  end
  
  def landing
    # Landing page explicitly for unauthenticated users
    redirect_to dashboard_path if current_user
  end
end