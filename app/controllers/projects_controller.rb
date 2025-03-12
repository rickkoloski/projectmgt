class ProjectsController < ApplicationController
  # Use a specific layout for project views
  layout 'project'
  
  before_action :authenticate_user!
  before_action :load_and_authorize_project, only: [:show, :edit, :update, :destroy]
  
  def index
    @projects = if current_user.admin?
      Project.all
    elsif current_user.organization
      current_user.organization.projects
    else
      # Show projects the user is involved in
      project_ids = []
      project_ids += current_user.created_tasks.pluck(:project_id)
      project_ids += current_user.assigned_tasks.pluck(:project_id)
      
      # Also include projects the user has permissions for
      permission_project_ids = current_user.permissions.where(resource_type: 'Project').pluck(:resource_id)
      project_ids += permission_project_ids
      
      Project.where(id: project_ids.uniq)
    end
  end
  
  def show
    # Log that we've reached the show action
    Rails.logger.info "ProjectsController#show called for project #{params[:id]}"
    
    # We need to explicitly check if project exists because set_project might have redirected
    if @project
      Rails.logger.info "Rendering show template for project #{@project.id}"
      # Make these variables available to the view
      @project_id = @project.id
      @project_name = @project.name
      
      # Load project tasks directly
      @tasks = @project.tasks
      
      # Format tasks for the Gantt chart
      @gantt_data = {
        projects: [@project].as_json(only: [:id, :name, :start_date, :end_date, :status]),
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
      
      # Check for special debug parameter
      if params[:debug] == "true"
        render :diagnose
      else
        # @project is already set by load_and_authorize_project
        render :show
      end
    else
      Rails.logger.info "Project not found or access denied"
    end
  end
  
  def new
    @project = Project.new
  end
  
  def create
    @project = Project.new(project_params)
    @project.organization_id = current_user.organization_id if current_user.organization_id
    
    if @project.save
      redirect_to project_path(@project), notice: 'Project was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @project.update(project_params)
      redirect_to project_path(@project), notice: 'Project was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @project.destroy
    redirect_to projects_path, notice: 'Project was successfully deleted.'
  end
  
  private
  
  def load_and_authorize_project
    begin
      @project = Project.find(params[:id])
      
      # IMPORTANT: Use the has_permission? method to ensure consistent permission checking
      if current_user.has_permission?(@project, 'view')
        # User has access - log it and continue
        Rails.logger.info "Access GRANTED to project #{@project.id} for user #{current_user.id}"
        return true
      else
        # User does not have access
        Rails.logger.info "Access DENIED to project #{@project.id} for user #{current_user.id}"
        redirect_to dashboard_path, alert: 'You do not have permission to access this project.'
        return false
      end
      
    rescue ActiveRecord::RecordNotFound
      # Project not found
      Rails.logger.info "Project with ID #{params[:id]} not found"
      redirect_to dashboard_path, alert: 'Project not found.'
      return false
    end
  end
  
  def project_params
    params.require(:project).permit(:name, :description, :start_date, :end_date, :status, :organization_id)
  end
end