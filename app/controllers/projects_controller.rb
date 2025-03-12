class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  
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
    # For now, redirect to the Gantt chart view with this project selected
    redirect_to gantt_path(project_id: @project.id)
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
  
  def set_project
    @project = Project.find(params[:id])
    
    # Check if user has access to this project
    unless current_user.admin? || 
           (current_user.organization && @project.organization_id == current_user.organization_id) ||
           current_user.has_permission?(@project, 'view')
      redirect_to dashboard_path, alert: 'You do not have permission to access this project.'
    end
  end
  
  def project_params
    params.require(:project).permit(:name, :description, :start_date, :end_date, :status, :organization_id)
  end
end